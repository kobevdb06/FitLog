import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/db/connection.dart';
import '../../../core/db/database.dart';
import '../../../core/db/restore_files.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/security/key_material.dart';
import '../../../core/util/paths.dart';
import 'backup_stream.dart';

export 'backup_stream.dart' show BackupUnreadableException, isSafePhotoName;

/// Creates and restores the encrypted `.fitlog` archive, and writes the
/// human-readable CSV export.
///
/// The archive holds the SQLCipher database file, the photos and the data
/// encryption key, encrypted with AES-GCM under a key derived from the
/// recovery phrase. That means a backup can be restored on a new device
/// with nothing but the twelve words.
class BackupService {
  const BackupService({required this.db, required this.paths});

  final AppDatabase db;
  final AppPaths paths;

  /// The newest format this version reads, and the one it writes: 3, in
  /// pieces (backup_stream.dart, DECISIONS 304). 2 carries the Argon2
  /// settings it was sealed with (DECISIONS 242); 1 is read with the
  /// settings there have always been. Both are one zip, sealed in one go.
  static const int _formatVersion = kStreamFormat;

  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  // --- Backup ---------------------------------------------------------------

  /// Backups run one after another: two at once shared one snapshot
  /// file, and each could take the other's (DECISIONS 258).
  static Future<void> _running = Future.value();

  /// How long a file shared from the export folder is kept there: long
  /// enough for the app it went to to read it, not for a copy of
  /// everything to lie around (DECISIONS 258).
  static const Duration exportsKept = Duration(hours: 1);

  /// Writes an encrypted backup and returns the file.
  ///
  /// [chunkSize] is the size of its pieces; only a test asks for others.
  Future<File> createBackup({
    required String recoveryPhrase,
    required Uint8List dek,
    @visibleForTesting int chunkSize = kBackupChunkSize,
  }) {
    final made = _running.then(
      (_) => _createBackup(
        recoveryPhrase: recoveryPhrase,
        dek: dek,
        chunkSize: chunkSize,
      ),
    );
    _running = made.then<void>((_) {}, onError: (Object _) {});
    return made;
  }

  Future<File> _createBackup({
    required String recoveryPhrase,
    required Uint8List dek,
    required int chunkSize,
  }) async {
    final exportDir = await paths.exportDirectory();
    await pruneExports(exportDir);
    final at = DateTime.now();
    final snapshot = File(
      '${exportDir.path}/snapshot-${at.microsecondsSinceEpoch}.db',
    );
    try {
      final file = await _writeBackup(
        exportDir: exportDir,
        snapshot: snapshot,
        recoveryPhrase: recoveryPhrase,
        dek: dek,
        at: at,
        chunkSize: chunkSize,
      );
      // Only now, with the file written: stamped before, an app Android
      // killed halfway kept saying there was a backup, and the reminder
      // stayed quiet for a week.
      await db.settingsDao.updateSettings(
        AppSettingsTableCompanion(
          lastBackupAt: Value(at.millisecondsSinceEpoch),
        ),
      );
      return file;
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
    }
  }

  /// Files shared from [dir] more than [exportsKept] ago, gone: a CSV of
  /// every workout or a backup left behind after it was handed on.
  static Future<void> pruneExports(Directory dir, {DateTime? now}) async {
    if (!await dir.exists()) return;
    final before = (now ?? DateTime.now()).subtract(exportsKept);
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      try {
        if ((await entity.lastModified()).isBefore(before)) {
          await entity.delete();
        }
      } on FileSystemException {
        // In use, or gone already: the next time.
      }
    }
  }

  Future<File> _writeBackup({
    required Directory exportDir,
    required File snapshot,
    required String recoveryPhrase,
    required Uint8List dek,
    required DateTime at,
    required int chunkSize,
  }) async {
    // VACUUM INTO writes a consistent copy that keeps the same encryption key,
    // which is safer than copying a file that may have a live WAL.
    await db.customStatement('VACUUM INTO ?', [snapshot.path]);
    // The moment of this backup goes in its own copy: restored, the
    // reminder is right at once.
    _stamp(snapshot, dek, at);

    final photosDir = paths.photosDirectory;
    final photos = [
      if (await photosDir.exists())
        await for (final entity in photosDir.list())
          if (entity is File) entity.path,
    ];
    final file = File(
      '${exportDir.path}/fitlog-'
      '${at.year}${_two(at.month)}${_two(at.day)}-'
      '${_two(at.hour)}${_two(at.minute)}.fitlog',
    );
    // Under its own name only once it is whole.
    final part = File('${file.path}.part');
    await _sealInPieces(
      out: part.path,
      recoveryPhrase: recoveryPhrase,
      keyHex: toHex(dek),
      manifest: jsonEncode({
        'format': _formatVersion,
        'app': 'FitLog',
        'created_at': at.toIso8601String(),
      }),
      database: snapshot.path,
      photos: photos,
      chunkSize: chunkSize,
    );
    return part.rename(file.path);
  }

  /// Sealing on its own isolate, a piece at a time: with many photos it
  /// took long enough to freeze the screen, and the whole archive no longer
  /// fits in memory at once. Only plain values cross to the isolate.
  static Future<void> _sealInPieces({
    required String out,
    required String recoveryPhrase,
    required String keyHex,
    required String manifest,
    required String database,
    required List<String> photos,
    required int chunkSize,
  }) => Isolate.run(
    () => writeStreamBackup(
      out: File(out),
      recoveryPhrase: recoveryPhrase,
      keyHex: keyHex,
      manifest: manifest,
      database: File(database),
      photos: [for (final path in photos) File(path)],
      chunkSize: chunkSize,
    ),
  );

  /// The moment of the backup, written into its copy of the database.
  ///
  /// The copy is encrypted with [dek] whenever the database is, which in the
  /// app it always is; a plain one - a test's - is stamped as it is.
  static void _stamp(File snapshot, Uint8List dek, DateTime at) {
    final head = snapshot.openSync()..setPositionSync(0);
    final plain = String.fromCharCodes(head.readSync(15)) == 'SQLite format 3';
    head.closeSync();
    final copy = sqlite3.open(snapshot.path);
    try {
      if (!plain) applyKeyAndVerify(copy, toHex(dek));
      copy.execute('UPDATE app_settings SET last_backup_at = ?', [
        at.millisecondsSinceEpoch,
      ]);
    } finally {
      copy.close();
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  // --- Restore --------------------------------------------------------------

  /// Opens the backup in [file] and writes it next to the app's own files,
  /// checked - its key, whether it is whole, its version - without touching
  /// those files yet, so the caller can confirm first (DECISIONS 242).
  ///
  /// Format 3 goes a piece at a time, on its own isolate, straight into the
  /// staged files (DECISIONS 304). Formats 1 and 2 were made in one piece,
  /// and are read in one piece.
  static Future<StagedRestore> stageFromFile({
    required File file,
    required String recoveryPhrase,
    required AppPaths paths,
  }) async {
    if (await _formatOf(file) < kStreamFormat) {
      final backup = await readBackup(
        file: file,
        recoveryPhrase: recoveryPhrase,
      );
      return stageRestore(backup: backup, paths: paths);
    }
    final files = RestoreFiles(paths);
    await files.discardStaged();
    try {
      final keyHex = await _openInPieces(
        file: file.path,
        recoveryPhrase: recoveryPhrase,
        database: files.stagedDatabase.path,
        photos: files.stagedPhotos.path,
      );
      return StagedRestore(dek: fromHex(keyHex), files: files);
    } on Object {
      await files.discardStaged();
      rethrow;
    }
  }

  /// Opened, written and checked on its own isolate. Only plain values
  /// cross to it.
  static Future<String> _openInPieces({
    required String file,
    required String recoveryPhrase,
    required String database,
    required String photos,
  }) => Isolate.run(() async {
    await Directory(photos).create(recursive: true);
    final keyHex = await readStreamBackup(
      file: File(file),
      recoveryPhrase: recoveryPhrase,
      database: File(database),
      photos: Directory(photos),
    );
    checkRestoredDatabase(File(database), keyHex);
    return keyHex;
  });

  /// The format of [file], from its first bytes; one that is not a FitLog
  /// backup, or that a later version made, is turned away here.
  static Future<int> _formatOf(File file) async {
    final raf = await file.open();
    final List<int> head;
    try {
      head = await raf.read(5);
    } finally {
      await raf.close();
    }
    if (head.length < 5 ||
        head[0] != kBackupMagic[0] ||
        head[1] != kBackupMagic[1] ||
        head[2] != kBackupMagic[2] ||
        head[3] != kBackupMagic[3]) {
      throw const BackupUnreadableException(
        'Dit is geen FitLog-back-upbestand.',
      );
    }
    final version = head[4];
    if (version > _formatVersion) {
      throw BackupUnreadableException(
        'Deze back-up is gemaakt met een nieuwere versie van FitLog '
        '(formaat $version). Werk FitLog eerst bij.',
      );
    }
    if (version < 1) {
      throw const BackupUnreadableException(
        'Dit back-upbestand is beschadigd of onvolledig.',
      );
    }
    return version;
  }

  /// Decrypts a backup of format 1 or 2 - one zip, sealed in one go - and
  /// returns its contents. Format 3 is opened with [stageFromFile].
  static Future<RestoredBackup> readBackup({
    required File file,
    required String recoveryPhrase,
  }) async {
    final version = await _formatOf(file);
    if (version >= kStreamFormat) {
      throw ArgumentError.value(file.path, 'file', 'format $version');
    }
    final bytes = await file.readAsBytes();
    const broken = BackupUnreadableException(
      'Dit back-upbestand is beschadigd of onvolledig.',
    );
    if (bytes.length < 8) throw broken;

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

  /// Writes a backup read in one piece next to the app's own files and
  /// checks it, before anything of the app's is touched: that the key in it opens the
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
    await pruneExports(await paths.exportDirectory());
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
