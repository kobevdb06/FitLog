import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cryptography/cryptography.dart';

import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/security/key_material.dart';
import '../../../core/util/paths.dart';

/// Thrown when a `.fitlog` file cannot be read with the supplied phrase.
class BackupUnreadableException implements Exception {
  const BackupUnreadableException(this.message);

  final String message;

  @override
  String toString() => 'BackupUnreadableException: $message';
}

/// Creates and restores the encrypted `.fitlog` archive, and writes the
/// human-readable CSV export.
///
/// The archive holds the SQLCipher database file, the photos and the data
/// encryption key, all inside one blob that is encrypted with AES-GCM under a
/// key derived from the recovery phrase. That means a backup can be restored
/// on a new device with nothing but the twelve words.
class BackupService {
  const BackupService({required this.db, required this.paths});

  final AppDatabase db;
  final AppPaths paths;

  /// Magic bytes so a wrong file is rejected before the user waits for
  /// Argon2id to finish.
  static const List<int> _magic = [0x46, 0x49, 0x54, 0x4C]; // "FITL"
  static const int _formatVersion = 1;

  // --- Backup ---------------------------------------------------------------

  /// Writes an encrypted backup and returns the file.
  Future<File> createBackup({
    required String recoveryPhrase,
    required Uint8List dek,
  }) async {
    final exportDir = await paths.exportDirectory();
    final snapshot = File('${exportDir.path}/snapshot.db');
    if (await snapshot.exists()) await snapshot.delete();

    // Stamped before the snapshot rather than after the file is written, so
    // the archive carries its own moment: restore it and the reminder is
    // immediately right. Put back if anything below fails, because a backup
    // that did not happen must not silence the reminder.
    final previousStamp = (await db.settingsDao.getSettings()).lastBackupAt;
    await db.settingsDao.updateSettings(
      AppSettingsTableCompanion(
        lastBackupAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    try {
      return await _writeBackup(
        exportDir: exportDir,
        snapshot: snapshot,
        recoveryPhrase: recoveryPhrase,
        dek: dek,
      );
    } on Object {
      await db.settingsDao.updateSettings(
        AppSettingsTableCompanion(lastBackupAt: Value(previousStamp)),
      );
      rethrow;
    }
  }

  Future<File> _writeBackup({
    required Directory exportDir,
    required File snapshot,
    required String recoveryPhrase,
    required Uint8List dek,
  }) async {

    // VACUUM INTO writes a consistent copy that keeps the same encryption key,
    // which is safer than copying a file that may have a live WAL.
    await db.customStatement('VACUUM INTO ?', [snapshot.path]);

    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'format': _formatVersion,
            'app': 'FitLog',
            'created_at': DateTime.now().toIso8601String(),
          }),
        ),
      )
      ..addFile(ArchiveFile.string('key.hex', toHex(dek)))
      ..addFile(
        ArchiveFile.bytes('fitlog.db', await snapshot.readAsBytes()),
      );

    final photosDir = paths.photosDirectory;
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list()) {
        if (entity is! File) continue;
        archive.addFile(
          ArchiveFile.bytes(
            'photos/${entity.uri.pathSegments.last}',
            await entity.readAsBytes(),
          ),
        );
      }
    }

    final zipped = ZipEncoder().encodeBytes(archive);
    await snapshot.delete();

    final salt = randomBytes(16);
    final nonce = randomBytes(12);
    final kek = await deriveKek(secret: recoveryPhrase, salt: salt);
    final box = await AesGcm.with256bits().encrypt(
      zipped,
      secretKey: SecretKey(kek),
      nonce: nonce,
    );

    final stamp = DateTime.now();
    final file = File(
      '${exportDir.path}/fitlog-'
      '${stamp.year}${_two(stamp.month)}${_two(stamp.day)}-'
      '${_two(stamp.hour)}${_two(stamp.minute)}.fitlog',
    );

    // header: magic | version | saltLen | nonceLen | salt | nonce | mac | ct
    final builder = BytesBuilder()
      ..add(_magic)
      ..addByte(_formatVersion)
      ..addByte(salt.length)
      ..addByte(nonce.length)
      ..add(salt)
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);

    await file.writeAsBytes(builder.takeBytes(), flush: true);
    return file;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  // --- Restore --------------------------------------------------------------

  /// Decrypts a backup and returns its contents without touching the app's
  /// own files yet, so the caller can confirm before overwriting anything.
  static Future<RestoredBackup> readBackup({
    required File file,
    required String recoveryPhrase,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 8 ||
        bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] ||
        bytes[3] != _magic[3]) {
      throw const BackupUnreadableException(
        'Dit is geen FitLog-back-upbestand.',
      );
    }
    if (bytes[4] != _formatVersion) {
      throw BackupUnreadableException(
        'Deze back-up is gemaakt met een nieuwere versie van FitLog '
        '(formaat ${bytes[4]}).',
      );
    }

    final saltLength = bytes[5];
    final nonceLength = bytes[6];
    var offset = 7;
    final salt = Uint8List.sublistView(bytes, offset, offset + saltLength);
    offset += saltLength;
    final nonce = Uint8List.sublistView(bytes, offset, offset + nonceLength);
    offset += nonceLength;
    final mac = Uint8List.sublistView(bytes, offset, offset + 16);
    offset += 16;
    final cipherText = Uint8List.sublistView(bytes, offset);

    final kek = await deriveKek(secret: recoveryPhrase, salt: salt);
    List<int> zipped;
    try {
      zipped = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(kek),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupUnreadableException(
        'De herstelzin hoort niet bij dit back-upbestand.',
      );
    }

    final archive = ZipDecoder().decodeBytes(zipped);

    Uint8List? database;
    String? keyHex;
    final photos = <String, Uint8List>{};

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final content = entry.readBytes();
      if (content == null) continue;

      if (entry.name == 'fitlog.db') {
        database = Uint8List.fromList(content);
      } else if (entry.name == 'key.hex') {
        keyHex = utf8.decode(content).trim();
      } else if (entry.name.startsWith('photos/')) {
        photos[entry.name.substring('photos/'.length)] = Uint8List.fromList(
          content,
        );
      }
    }

    if (database == null || keyHex == null) {
      throw const BackupUnreadableException(
        'De back-up is onvolledig: de database of de sleutel ontbreekt.',
      );
    }

    return RestoredBackup(
      databaseBytes: database,
      dek: fromHex(keyHex),
      photos: photos,
    );
  }

  /// Overwrites the local database and photos with the backup's contents.
  ///
  /// The caller must have closed the database first.
  static Future<void> applyRestore({
    required RestoredBackup backup,
    required AppPaths paths,
  }) async {
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${paths.databaseFile.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await paths.databaseFile.writeAsBytes(backup.databaseBytes, flush: true);

    final photosDir = paths.photosDirectory;
    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }
    await paths.ensurePhotosDirectory();
    for (final entry in backup.photos.entries) {
      await paths.photoFile(entry.key).writeAsBytes(entry.value, flush: true);
    }
  }

  // --- CSV ------------------------------------------------------------------

  /// A readable export of every finished workout and every set.
  Future<File> exportCsv({required Formatters formatters}) async {
    final rows = await db
        .customSelect(
          'SELECT w.started_at AS started_at, w.name AS workout, '
          'w.duration_seconds AS duration, e.name AS exercise, '
          'ws.sort_order AS set_index, ws.set_type AS set_type, '
          'ws.weight_kg AS weight_kg, ws.reps AS reps, '
          'ws.duration_seconds AS set_duration, ws.distance_m AS distance_m, '
          'ws.rpe AS rpe, ws.is_completed AS is_completed '
          'FROM workout_sets ws '
          'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'JOIN exercises e ON e.id = we.exercise_id '
          'WHERE w.ended_at IS NOT NULL '
          'ORDER BY w.started_at DESC, we.sort_order ASC, ws.sort_order ASC',
        )
        .get();

    final buffer = StringBuffer()
      ..writeln(
        'datum,workout,duur_seconden,oefening,set,type,gewicht_kg,reps,'
        'duur_seconden_set,afstand_m,rpe,afgevinkt',
      );

    for (final row in rows) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('started_at'),
      );
      buffer.writeln(
        [
          startedAt.toIso8601String(),
          _csv(row.read<String>('workout')),
          row.read<int>('duration'),
          _csv(row.read<String>('exercise')),
          row.read<int>('set_index') + 1,
          SetType.fromWire(row.read<String>('set_type')).wire,
          row.read<double?>('weight_kg') ?? '',
          row.read<int?>('reps') ?? '',
          row.read<int?>('set_duration') ?? '',
          row.read<double?>('distance_m') ?? '',
          row.read<double?>('rpe') ?? '',
          row.read<bool>('is_completed') ? 'ja' : 'nee',
        ].join(','),
      );
    }

    final dir = await paths.exportDirectory();
    final stamp = DateTime.now();
    final file = File(
      '${dir.path}/fitlog-workouts-'
      '${stamp.year}${_two(stamp.month)}${_two(stamp.day)}.csv',
    );
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  static String _csv(String value) {
    if (!value.contains(',') && !value.contains('"')) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}

/// The decrypted contents of a `.fitlog` archive.
class RestoredBackup {
  const RestoredBackup({
    required this.databaseBytes,
    required this.dek,
    required this.photos,
  });

  final Uint8List databaseBytes;
  final Uint8List dek;

  /// File name to bytes.
  final Map<String, Uint8List> photos;
}
