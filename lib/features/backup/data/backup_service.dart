import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/db/connection.dart';
import '../../../core/db/database.dart';
import '../../../core/db/restore_files.dart';
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

  /// 2 carries the Argon2 settings it was sealed with, so they can be raised
  /// one day without leaving every older backup unreadable (DECISIONS 242).
  /// 1 is read with the settings there have always been.
  static const int _formatVersion = 2;

  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

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
      ..addFile(ArchiveFile.bytes('fitlog.db', await snapshot.readAsBytes()));

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

    final salt = randomBytes(_saltLength);
    final nonce = randomBytes(_nonceLength);
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

    // header: magic | version | memory (4 bytes) | iterations | parallelism |
    // saltLen | nonceLen | salt | nonce | mac | ct
    final memory = ByteData(4)..setUint32(0, kArgonMemoryKib);
    final builder = BytesBuilder()
      ..add(_magic)
      ..addByte(_formatVersion)
      ..add(memory.buffer.asUint8List())
      ..addByte(kArgonIterations)
      ..addByte(kArgonParallelism)
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
    const broken = BackupUnreadableException(
      'Dit back-upbestand is beschadigd of onvolledig.',
    );
    if (bytes.length < 8 ||
        bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] ||
        bytes[3] != _magic[3]) {
      throw const BackupUnreadableException(
        'Dit is geen FitLog-back-upbestand.',
      );
    }
    final version = bytes[4];
    if (version > _formatVersion) {
      throw BackupUnreadableException(
        'Deze back-up is gemaakt met een nieuwere versie van FitLog '
        '(formaat $version). Werk FitLog eerst bij.',
      );
    }
    if (version < 1) throw broken;

    var offset = 5;
    var memoryKib = kArgonMemoryKib;
    var iterations = kArgonIterations;
    var parallelism = kArgonParallelism;
    if (version >= 2) {
      if (bytes.length < offset + 6) throw broken;
      memoryKib = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      iterations = bytes[offset + 4];
      parallelism = bytes[offset + 5];
      offset += 6;
      // A file that asks for a gigabyte or a thousand rounds is not one this
      // app wrote: it would only make the phone wait, or run out of memory.
      if (memoryKib < 8 * 1024 ||
          memoryKib > 1024 * 1024 ||
          iterations < 1 ||
          iterations > 16 ||
          parallelism < 1 ||
          parallelism > 16) {
        throw broken;
      }
    }

    if (bytes.length < offset + 2) throw broken;
    final saltLength = bytes[offset];
    final nonceLength = bytes[offset + 1];
    offset += 2;
    if (saltLength != _saltLength ||
        nonceLength != _nonceLength ||
        bytes.length < offset + saltLength + nonceLength + _macLength) {
      throw broken;
    }
    final salt = Uint8List.sublistView(bytes, offset, offset + saltLength);
    offset += saltLength;
    final nonce = Uint8List.sublistView(bytes, offset, offset + nonceLength);
    offset += nonceLength;
    final mac = Uint8List.sublistView(bytes, offset, offset + _macLength);
    offset += _macLength;
    final cipherText = Uint8List.sublistView(bytes, offset);

    final kek = await deriveKek(
      secret: recoveryPhrase,
      salt: salt,
      memoryKib: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
    );
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
        keyHex = utf8.decode(content, allowMalformed: true).trim();
      } else if (entry.name.startsWith('photos/')) {
        final name = entry.name.substring('photos/'.length);
        // A bare file name and nothing else: "photos/../x" or an absolute
        // path would be written outside the photo folder.
        if (!isSafePhotoName(name)) {
          throw const BackupUnreadableException(
            'De back-up bevat een foto met een ongeldige naam.',
          );
        }
        photos[name] = Uint8List.fromList(content);
      }
    }

    if (database == null || keyHex == null) {
      throw const BackupUnreadableException(
        'De back-up is onvolledig: de database of de sleutel ontbreekt.',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) {
      throw const BackupUnreadableException(
        'De sleutel in de back-up is ongeldig.',
      );
    }

    return RestoredBackup(
      databaseBytes: database,
      dek: fromHex(keyHex),
      photos: photos,
    );
  }

  /// Writes the backup next to the app's own files and checks it, before
  /// anything of the app's is touched: that the key in it opens the
  /// database, that the database is whole, and that it is not from a later
  /// version (DECISIONS 242). Restoring used to delete the database and the
  /// photos first, and only then write the backup - a full disk, a crash or
  /// a backup this version cannot read left nothing.
  static Future<StagedRestore> stageRestore({
    required RestoredBackup backup,
    required AppPaths paths,
  }) async {
    final files = RestoreFiles(paths);
    await files.discardStaged();
    try {
      await files.stagedDatabase.writeAsBytes(
        backup.databaseBytes,
        flush: true,
      );
      checkRestoredDatabase(files.stagedDatabase, toHex(backup.dek));
      await files.stagedPhotos.create(recursive: true);
      for (final entry in backup.photos.entries) {
        await File('${files.stagedPhotos.path}/${entry.key}')
            .writeAsBytes(entry.value, flush: true);
      }
    } on Object {
      await files.discardStaged();
      rethrow;
    }
    return StagedRestore(dek: backup.dek, files: files);
  }

  /// Opens the database of a backup with its own key, read only, and says
  /// what is wrong with it, if anything.
  static void checkRestoredDatabase(File file, String keyHex) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      try {
        applyKeyAndVerify(db, keyHex);
      } on WrongDatabaseKeyException {
        throw const BackupUnreadableException(
          'De sleutel in de back-up opent de database erin niet.',
        );
      } on SqliteException {
        throw const BackupUnreadableException(
          'De database in de back-up is beschadigd.',
        );
      }
      final Object? integrity;
      final Object? version;
      try {
        integrity = db.select('PRAGMA integrity_check').first.values.first;
        version = db.select('PRAGMA user_version').first.values.first;
      } on SqliteException {
        // Damaged badly enough that the check itself cannot run.
        throw const BackupUnreadableException(
          'De database in de back-up is beschadigd.',
        );
      }
      if (integrity != 'ok') {
        throw const BackupUnreadableException(
          'De database in de back-up is beschadigd.',
        );
      }
      if (version is int && version > AppDatabase.currentSchemaVersion) {
        throw const BackupUnreadableException(
          'Deze back-up komt uit een nieuwere versie van FitLog. Werk FitLog '
          'eerst bij.',
        );
      }
    } finally {
      db.close();
    }
  }

  /// Puts a checked backup in place of the app's own files. Only renames:
  /// the old files are kept beside it until the new database opened, and
  /// [RestoreFiles.settle] finishes - or undoes - a restore that stopped
  /// halfway. The keys of the backup must be in place first.
  ///
  /// The caller must have closed the database first.
  static Future<void> applyRestore(StagedRestore staged) => staged.files.swap();

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
          'ws.rpe AS rpe, ws.is_completed AS is_completed, ws.is_skipped AS is_skipped '
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
        'duur_seconden_set,afstand_m,rpe,afgevinkt,geskipt',
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
          row.read<bool>('is_skipped') ? 'ja' : 'nee',
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

/// Whether [name] is a file name that stays in the photo folder.
bool isSafePhotoName(String name) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name) &&
    !name.contains('..');

/// A backup written next to the app's files and checked, waiting to be put
/// in their place.
class StagedRestore {
  const StagedRestore({required this.dek, required this.files});

  final Uint8List dek;
  final RestoreFiles files;

  /// Not restored after all: what was written next to the app goes.
  Future<void> discard() => files.discardStaged();
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
