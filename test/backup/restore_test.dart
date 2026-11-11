import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:fitlog/core/db/connection.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/restore_files.dart';
import 'package:fitlog/core/security/key_material.dart';
import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/backup/data/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const _timeout = Timeout(Duration(minutes: 5));

/// Restoring a backup without ever being left with nothing (DECISIONS 242).
///
/// It used to delete the database and the photos first and only then write
/// the backup's, without having looked at it: a full disk, a crash, or a
/// backup from a later version left no data, or data without its key.
void main() {
  late Directory home;
  late AppPaths paths;
  late RestoreFiles files;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('fitlog_restore');
    paths = AppPaths(home);
    files = RestoreFiles(paths);
  });

  tearDown(() async {
    if (await home.exists()) await home.delete(recursive: true);
  });

  /// An encrypted database at [file] under [dek], with one routine named
  /// [name] to tell it apart.
  Future<void> database(File file, Uint8List dek, String name) async {
    final db = AppDatabase(
      openEncryptedExecutor(file: file, keyHex: toHex(dek)),
    );
    await db.settingsDao.ensureInitialized();
    await db.customStatement(
      'INSERT INTO routines (id, name, sort_order, created_at, updated_at) '
      "VALUES ('r-1', '$name', 0, 1, 1)",
    );
    await db.close();
  }

  /// The name of the routine in the database at [file].
  String nameIn(File file, Uint8List dek) {
    final db = sqlite3.open(file.path);
    try {
      applyKeyAndVerify(db, toHex(dek));
      return db.select('SELECT name FROM routines').first['name'] as String;
    } finally {
      db.close();
    }
  }

  Future<RestoredBackup> backupOf(Uint8List dek, String name) async {
    final source = File('${home.path}/bron.db');
    await database(source, dek, name);
    final bytes = await source.readAsBytes();
    await source.delete();
    return RestoredBackup(
      databaseBytes: bytes,
      dek: dek,
      photos: {
        'foto-1.jpg': Uint8List.fromList([1, 2, 3]),
      },
    );
  }

  /// The app's own data: an old database under [dek] and one photo.
  Future<void> ownData(Uint8List dek) async {
    await database(paths.databaseFile, dek, 'Oud');
    await paths.ensurePhotosDirectory();
    await paths.photoFile('oud.jpg').writeAsBytes([9]);
  }

  group('before anything is touched, the backup is checked', () {
    test('one from a later version is refused', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final backup = await backupOf(generateDek(), 'Nieuw');
      final raised = File('${home.path}/later.db')
        ..writeAsBytesSync(backup.databaseBytes);
      final db = sqlite3.open(raised.path);
      applyKeyAndVerify(db, toHex(backup.dek));
      db.execute('PRAGMA user_version = 99');
      db.close();
      final later = RestoredBackup(
        databaseBytes: raised.readAsBytesSync(),
        dek: backup.dek,
        photos: backup.photos,
      );

      await expectLater(
        BackupService.stageRestore(backup: later, paths: paths),
        throwsA(
          isA<BackupUnreadableException>().having(
            (e) => e.message,
            'message',
            contains('nieuwere versie'),
          ),
        ),
      );
      expect(await files.pending, isFalse);
      expect(nameIn(paths.databaseFile, oldKey), 'Oud');
    }, timeout: _timeout);

    test('one whose key does not open its database is refused', () async {
      final backup = await backupOf(generateDek(), 'Nieuw');

      await expectLater(
        BackupService.stageRestore(
          backup: RestoredBackup(
            databaseBytes: backup.databaseBytes,
            dek: generateDek(),
            photos: const {},
          ),
          paths: paths,
        ),
        throwsA(isA<BackupUnreadableException>()),
      );
      expect(await files.pending, isFalse);
    }, timeout: _timeout);

    test('a damaged one is refused', () async {
      final backup = await backupOf(generateDek(), 'Nieuw');
      final damaged = Uint8List.fromList(backup.databaseBytes)
        ..fillRange(5000, 9000, 0);

      await expectLater(
        BackupService.stageRestore(
          backup: RestoredBackup(
            databaseBytes: damaged,
            dek: backup.dek,
            photos: const {},
          ),
          paths: paths,
        ),
        throwsA(isA<BackupUnreadableException>()),
      );
      expect(await files.pending, isFalse);
    }, timeout: _timeout);
  });

  group('putting it in place', () {
    test('keeps the old files beside it until the new key opens the new '
        'database', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final backup = await backupOf(generateDek(), 'Nieuw');

      await BackupService.applyRestore(
        await BackupService.stageRestore(backup: backup, paths: paths),
      );

      expect(nameIn(paths.databaseFile, backup.dek), 'Nieuw');
      expect(nameIn(files.previousDatabase, oldKey), 'Oud');
      expect(paths.photoFile('foto-1.jpg').existsSync(), isTrue);
      expect(File('${files.previousPhotos.path}/oud.jpg').existsSync(), isTrue);

      await files.settle(toHex(backup.dek));

      expect(await files.pending, isFalse);
      expect(nameIn(paths.databaseFile, backup.dek), 'Nieuw');
    }, timeout: _timeout);

    test('stopped before the keys changed: undone at the next start', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final backup = await backupOf(generateDek(), 'Nieuw');
      await BackupService.applyRestore(
        await BackupService.stageRestore(backup: backup, paths: paths),
      );

      // The old key is still the one there is.
      await files.settle(toHex(oldKey));

      expect(await files.pending, isFalse);
      expect(nameIn(paths.databaseFile, oldKey), 'Oud');
      expect(paths.photoFile('oud.jpg').existsSync(), isTrue);
      expect(paths.photoFile('foto-1.jpg').existsSync(), isFalse);
    }, timeout: _timeout);

    test('stopped after the keys changed, before the files moved: finished '
        'at the next start', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final backup = await backupOf(generateDek(), 'Nieuw');
      await BackupService.stageRestore(backup: backup, paths: paths);

      await files.settle(toHex(backup.dek));

      expect(await files.pending, isFalse);
      expect(nameIn(paths.databaseFile, backup.dek), 'Nieuw');
      expect(paths.photoFile('foto-1.jpg').existsSync(), isTrue);
    }, timeout: _timeout);

    test('stopped halfway through the moving: the key decides', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final backup = await backupOf(generateDek(), 'Nieuw');
      await BackupService.stageRestore(backup: backup, paths: paths);
      // The app's database moved aside, the backup's not yet in its place.
      await paths.databaseFile.rename(files.previousDatabase.path);

      await files.settle(toHex(backup.dek));

      expect(nameIn(paths.databaseFile, backup.dek), 'Nieuw');
      expect(await files.pending, isFalse);
    }, timeout: _timeout);

    test('a key that opens none of them touches nothing', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final backup = await backupOf(generateDek(), 'Nieuw');
      await BackupService.applyRestore(
        await BackupService.stageRestore(backup: backup, paths: paths),
      );

      await files.settle(toHex(generateDek()));

      expect(nameIn(paths.databaseFile, backup.dek), 'Nieuw');
      expect(nameIn(files.previousDatabase, oldKey), 'Oud');
    }, timeout: _timeout);

    test('a journal moves with its own database', () async {
      final oldKey = generateDek();
      await ownData(oldKey);
      final journal = File('${paths.databaseFile.path}-journal')
        ..writeAsBytesSync([1]);
      final backup = await backupOf(generateDek(), 'Nieuw');

      await BackupService.applyRestore(
        await BackupService.stageRestore(backup: backup, paths: paths),
      );

      expect(journal.existsSync(), isFalse);
      expect(
        File('${files.previousDatabase.path}-journal').existsSync(),
        isTrue,
      );
    }, timeout: _timeout);
  });

  group('reading the file', () {
    late String phrase;

    setUp(() => phrase = generateRecoveryPhrase());

    /// An archive with [entries], sealed as FitLog does: format 1, or 2 with
    /// the given Argon2 settings.
    Future<File> sealed(
      Map<String, List<int>> entries, {
      int format = 2,
      int memoryKib = kArgonMemoryKib,
      int iterations = kArgonIterations,
      int parallelism = kArgonParallelism,
    }) async {
      final archive = Archive();
      for (final MapEntry(:key, :value) in entries.entries) {
        archive.addFile(ArchiveFile.bytes(key, value));
      }
      final zipped = ZipEncoder().encodeBytes(archive);
      final salt = randomBytes(16);
      final nonce = randomBytes(12);
      final kek = await deriveKek(
        secret: phrase,
        salt: salt,
        memoryKib: memoryKib,
        iterations: iterations,
        parallelism: parallelism,
      );
      final box = await AesGcm.with256bits().encrypt(
        zipped,
        secretKey: SecretKey(kek),
        nonce: nonce,
      );
      final builder = BytesBuilder()
        ..add([0x46, 0x49, 0x54, 0x4C])
        ..addByte(format);
      if (format >= 2) {
        builder
          ..add((ByteData(4)..setUint32(0, memoryKib)).buffer.asUint8List())
          ..addByte(iterations)
          ..addByte(parallelism);
      }
      builder
        ..addByte(16)
        ..addByte(12)
        ..add(salt)
        ..add(nonce)
        ..add(box.mac.bytes)
        ..add(box.cipherText);
      return File('${home.path}/test.fitlog')
        ..writeAsBytesSync(builder.takeBytes());
    }

    final key = utf8.encode('ab' * 32);

    test(
      'a photo whose name leads out of the photo folder is refused',
      () async {
        final file = await sealed({
          'fitlog.db': [1],
          'key.hex': key,
          'photos/../fitlog.db': [2],
        });

        await expectLater(
          BackupService.readBackup(file: file, recoveryPhrase: phrase),
          throwsA(isA<BackupUnreadableException>()),
        );
      },
      timeout: _timeout,
    );

    test('a key that is no key is refused', () async {
      final file = await sealed({
        'fitlog.db': [1],
        'key.hex': utf8.encode('abc'),
      });

      await expectLater(
        BackupService.readBackup(file: file, recoveryPhrase: phrase),
        throwsA(isA<BackupUnreadableException>()),
      );
    }, timeout: _timeout);

    test('a backup in the first format still opens', () async {
      final file = await sealed({
        'fitlog.db': [1],
        'key.hex': key,
        'photos/a.jpg': [3],
      }, format: 1);

      final read = await BackupService.readBackup(
        file: file,
        recoveryPhrase: phrase,
      );
      expect(read.photos.keys, ['a.jpg']);
    }, timeout: _timeout);

    test('one sealed with other Argon2 settings opens with those', () async {
      final file = await sealed(
        {
          'fitlog.db': [1],
          'key.hex': key,
        },
        memoryKib: 16 * 1024,
        iterations: 2,
        parallelism: 1,
      );

      final read = await BackupService.readBackup(
        file: file,
        recoveryPhrase: phrase,
      );
      expect(toHex(read.dek), 'ab' * 32);
    }, timeout: _timeout);

    test('one that asks for absurd settings is refused at once', () async {
      final file = await sealed({
        'fitlog.db': [1],
      }, iterations: 1);
      final bytes = file.readAsBytesSync();
      bytes[9] = 200;
      file.writeAsBytesSync(bytes);

      await expectLater(
        BackupService.readBackup(file: file, recoveryPhrase: phrase),
        throwsA(isA<BackupUnreadableException>()),
      );
    }, timeout: _timeout);

    test(
      'one made before format 3 is staged as well (DECISIONS 304)',
      () async {
        final dek = generateDek();
        final source = File('${home.path}/bron.db');
        await database(source, dek, 'Twee');
        final file = await sealed({
          'fitlog.db': source.readAsBytesSync(),
          'key.hex': utf8.encode(toHex(dek)),
          'photos/a.jpg': [3],
        });

        final staged = await BackupService.stageFromFile(
          file: file,
          recoveryPhrase: phrase,
          paths: paths,
        );

        expect(staged.dek, dek);
        expect(nameIn(staged.files.stagedDatabase, dek), 'Twee');
        expect(
          File('${staged.files.stagedPhotos.path}/a.jpg').readAsBytesSync(),
          [3],
        );
      },
      timeout: _timeout,
    );

    test('a cut-off file is refused, not a crash', () async {
      final file = await sealed({
        'fitlog.db': [1],
      });
      file.writeAsBytesSync(file.readAsBytesSync().sublist(0, 20));

      await expectLater(
        BackupService.readBackup(file: file, recoveryPhrase: phrase),
        throwsA(isA<BackupUnreadableException>()),
      );
    }, timeout: _timeout);
  });

  test('photo names: a bare name only', () {
    expect(isSafePhotoName('3f2a.jpg'), isTrue);
    for (final name in ['', '.', '..', '../x', 'a/b.jpg', r'a\b.jpg', '/x']) {
      expect(isSafePhotoName(name), isFalse, reason: name);
    }
  });

  test('a plain database file is never what a restore keeps', () async {
    // Only to show the key decides: a file without a key does not open.
    final plain = File('${home.path}/plain.db');
    final db = AppDatabase(NativeDatabase(plain));
    await db.settingsDao.ensureInitialized();
    await db.close();
    expect(keyOpensDatabase(plain, toHex(generateDek())), isFalse);
  });

  group('making one (DECISIONS 258)', () {
    late AppDatabase db;
    late Uint8List dek;
    late String phrase;

    setUp(() async {
      dek = generateDek();
      phrase = generateRecoveryPhrase();
      db = AppDatabase(
        openEncryptedExecutor(file: paths.databaseFile, keyHex: toHex(dek)),
      );
      await db.settingsDao.ensureInitialized();
    });

    tearDown(() => db.close());

    test(
      'its copy of the database is encrypted, and carries its moment',
      () async {
        final service = BackupService(db: db, paths: paths);

        final file = await service.createBackup(
          recoveryPhrase: phrase,
          dek: dek,
        );

        final stamped = (await db.settingsDao.getSettings()).lastBackupAt;
        expect(stamped, isNotNull);
        final staged = await BackupService.stageFromFile(
          file: file,
          recoveryPhrase: phrase,
          paths: AppPaths(Directory('${home.path}/elders')..createSync()),
        );
        final restored = staged.files.stagedDatabase;
        expect(
          String.fromCharCodes(restored.readAsBytesSync().take(15)),
          isNot('SQLite format 3'),
          reason: 'VACUUM INTO keeps the key',
        );
        final copy = sqlite3.open(restored.path);
        applyKeyAndVerify(copy, toHex(dek));
        expect(
          copy
              .select('SELECT last_backup_at FROM app_settings')
              .first
              .values
              .first,
          stamped,
        );
        copy.close();
      },
      timeout: _timeout,
    );

    test('two at once both come out whole', () async {
      final service = BackupService(db: db, paths: paths);

      final files = await Future.wait([
        service.createBackup(recoveryPhrase: phrase, dek: dek),
        service.createBackup(recoveryPhrase: phrase, dek: dek),
      ]);

      for (final (i, file) in files.indexed) {
        final staged = await BackupService.stageFromFile(
          file: file,
          recoveryPhrase: phrase,
          paths: AppPaths(Directory('${home.path}/elders-$i')..createSync()),
        );
        expect(staged.files.stagedDatabase.lengthSync(), greaterThan(0));
      }
      expect(
        (await paths.exportDirectory()).listSync().where(
          (f) => f.path.endsWith('.db'),
        ),
        isEmpty,
        reason: 'no snapshot left behind',
      );
    }, timeout: _timeout);
  });

  test('what was shared more than an hour ago goes from the export folder '
      '(DECISIONS 258)', () async {
    final dir = await paths.exportDirectory();
    final old = File('${dir.path}/fitlog-workouts.csv')..writeAsStringSync('x');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    final fresh = File('${dir.path}/fitlog-20261111.fitlog')
      ..writeAsStringSync('y');

    await BackupService.pruneExports(dir);

    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });

  test(
    'the version of a database, read without opening it for the app',
    () async {
      final dek = generateDek();
      await database(paths.databaseFile, dek, 'Oud');

      expect(
        databaseVersion(paths.databaseFile, toHex(dek)),
        AppDatabase.currentSchemaVersion,
      );
      expect(databaseVersion(paths.databaseFile, toHex(generateDek())), isNull);
    },
    timeout: _timeout,
  );
}
