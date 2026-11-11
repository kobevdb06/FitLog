import 'dart:io';

import 'package:fitlog/core/db/connection.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_material.dart';
import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/backup/data/backup_service.dart';
import 'package:fitlog/core/photos/photo_library.dart';
import 'package:fitlog/core/photos/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_store_test.dart' show writeSourceImage;

/// Argon2id runs twice here (once to seal, once to open), so this needs room.
const _timeout = Timeout(Duration(minutes: 5));

void main() {
  late Directory source;
  late Directory target;
  late Directory cache;

  setUp(() async {
    source = await Directory.systemTemp.createTemp('fitlog_backup_src');
    target = await Directory.systemTemp.createTemp('fitlog_backup_dst');
    cache = await Directory.systemTemp.createTemp('fitlog_backup_cache');
  });

  tearDown(() async {
    for (final dir in [source, target, cache]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  test('photos travel with the encrypted backup and come back', () async {
    final phrase = generateRecoveryPhrase();
    final dek = generateDek();

    // --- The device that makes the backup ---------------------------------
    final sourcePaths = AppPaths(source);
    final db = AppDatabase(
      openEncryptedExecutor(file: sourcePaths.databaseFile, keyHex: toHex(dek)),
    );
    await db.settingsDao.ensureInitialized();

    final library = PhotoLibrary(db: db, store: PhotoStore(sourcePaths));
    for (final pose in PhotoPose.values) {
      await library.importPhoto(
        source: writeSourceImage(cache, '${pose.wire}.jpg'),
        pose: pose,
        takenAt: DateTime(2026, 5, 1),
      );
    }
    final originals = await db.recordsDao.photos();
    expect(originals, hasLength(3));

    final archive = await BackupService(
      db: db,
      paths: sourcePaths,
    ).createBackup(recoveryPhrase: phrase, dek: dek);
    expect(await archive.exists(), isTrue);
    await db.close();

    // --- A different device, nothing but the file and the twelve words ----
    final targetPaths = AppPaths(target);
    final staged = await BackupService.stageFromFile(
      file: archive,
      recoveryPhrase: phrase,
      paths: targetPaths,
    );
    expect(staged.files.stagedPhotos.listSync(), hasLength(3));
    expect(staged.dek, equals(dek));
    await BackupService.applyRestore(staged);

    final restoredDb = AppDatabase(
      openEncryptedExecutor(
        file: targetPaths.databaseFile,
        keyHex: toHex(staged.dek),
      ),
    );
    final rows = await restoredDb.recordsDao.photos();
    expect(rows, hasLength(3));

    // Every row still resolves to a real file on the new device.
    final targetStore = PhotoStore(targetPaths);
    for (final row in rows) {
      expect(
        await targetStore.exists(row.fileName),
        isTrue,
        reason: row.fileName,
      );
      expect(await targetStore.fileFor(row.fileName).length(), greaterThan(0));
    }

    // And the reconciliation finds nothing to fix.
    final cleanup = await PhotoLibrary(
      db: restoredDb,
      store: targetStore,
    ).cleanup();
    expect(cleanup.isClean, isTrue);

    await restoredDb.close();
  }, timeout: _timeout);

  test('sealed photos come back, and open with the key of the backup '
      '(DECISIONS 257)', () async {
    final phrase = generateRecoveryPhrase();
    final dek = generateDek();
    final sourcePaths = AppPaths(source);
    final db = AppDatabase(
      openEncryptedExecutor(file: sourcePaths.databaseFile, keyHex: toHex(dek)),
    );
    await db.settingsDao.ensureInitialized();
    await PhotoLibrary(
      db: db,
      store: PhotoStore(sourcePaths, key: dek),
    ).importPhoto(
      source: writeSourceImage(cache, 'voor.jpg'),
      pose: PhotoPose.front,
      takenAt: DateTime(2026, 5, 1),
    );
    final archive = await BackupService(
      db: db,
      paths: sourcePaths,
    ).createBackup(recoveryPhrase: phrase, dek: dek);
    await db.close();

    final targetPaths = AppPaths(target);
    final staged = await BackupService.stageFromFile(
      file: archive,
      recoveryPhrase: phrase,
      paths: targetPaths,
    );
    await BackupService.applyRestore(staged);

    final store = PhotoStore(targetPaths, key: staged.dek);
    final names = await store.storedFileNames();
    final opened = (await store.readBytes(names.single))!;
    expect(opened[0], 0xFF);
    expect(opened[1], 0xD8);
  }, timeout: _timeout);

  test('a wrong phrase cannot open the archive', () async {
    final dek = generateDek();
    final paths = AppPaths(source);
    final db = AppDatabase(
      openEncryptedExecutor(file: paths.databaseFile, keyHex: toHex(dek)),
    );
    await db.settingsDao.ensureInitialized();

    final archive = await BackupService(
      db: db,
      paths: paths,
    ).createBackup(recoveryPhrase: generateRecoveryPhrase(), dek: dek);
    await db.close();

    await expectLater(
      BackupService.stageFromFile(
        file: archive,
        recoveryPhrase: generateRecoveryPhrase(),
        paths: AppPaths(target),
      ),
      throwsA(isA<BackupUnreadableException>()),
    );
  }, timeout: _timeout);
}
