import 'dart:io';

import 'package:fitlog/core/db/connection.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Restoring a backup has to close the database before it can replace the
/// file, and on a device that close never returned: the screen sat on
/// "Database sluiten" forever.
///
/// The connection runs in a background isolate, and the app keeps watch
/// streams open on it for as long as it is running. These tests close a
/// database in exactly those two states.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fitlog_close');
    file = File('${dir.path}/fitlog.db');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  AppDatabase open() => AppDatabase(
    openEncryptedExecutor(file: file, keyHex: '00' * 32),
  );

  test('an idle database closes', () async {
    final db = open();
    await db.settingsDao.ensureInitialized();

    await db.close().timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('close bleef hangen op een stille database'),
    );
  });

  test('a database with an open watch stream closes', () async {
    final db = open();
    await db.settingsDao.ensureInitialized();

    // The app holds several of these for its whole lifetime: the settings, the
    // routines, the recovery estimate.
    final subscription = db.settingsDao.watchSettings().listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await db.close().timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('close bleef hangen met een open stream'),
    );
    await subscription.cancel();
  });

  test('a database with several open streams closes', () async {
    final db = open();
    await db.settingsDao.ensureInitialized();

    final subscriptions = [
      db.settingsDao.watchSettings().listen((_) {}),
      db.routinesDao.watchRoutines().listen((_) {}),
      db.routinesDao.watchFolders().listen((_) {}),
      db.recordsDao.watchPhotos().listen((_) {}),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await db.close().timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail('close bleef hangen met meerdere streams'),
    );
    for (final s in subscriptions) {
      await s.cancel();
    }
  });

  test('the file can be replaced once it is closed', () async {
    final db = open();
    await db.settingsDao.ensureInitialized();
    await db.close();

    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await file.writeAsBytes([1, 2, 3], flush: true);
    expect(await file.length(), 3);
  });
}
