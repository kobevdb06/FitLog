import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/backup/data/backup_service.dart';
import 'package:fitlog/features/backup/domain/backup_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Everything this app knows sits in one file on one phone, and it used to say
/// nothing about that. The reminder needs a moment to count from, so making a
/// backup now records one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final now = DateTime(2026, 6, 1, 12);

  group('when to say something', () {
    test('an empty install is left alone', () {
      expect(
        backupReminderFor(lastBackupAt: null, workoutCount: 0, now: now),
        BackupReminder.none,
      );
    });

    test('history without a backup is worth saying', () {
      expect(
        backupReminderFor(lastBackupAt: null, workoutCount: 1, now: now),
        BackupReminder.never,
      );
    });

    test('a recent backup is nothing to mention', () {
      expect(
        backupReminderFor(
          lastBackupAt: now.subtract(const Duration(days: 3)),
          workoutCount: 40,
          now: now,
        ),
        BackupReminder.none,
      );
    });

    test('an old one is', () {
      expect(
        backupReminderFor(
          lastBackupAt: now.subtract(kBackupReminderAge * 2),
          workoutCount: 40,
          now: now,
        ),
        BackupReminder.stale,
      );
    });

    test('the boundary itself still counts as recent', () {
      expect(
        backupReminderFor(
          lastBackupAt: now.subtract(kBackupReminderAge),
          workoutCount: 40,
          now: now,
        ),
        BackupReminder.none,
      );
    });
  });

  group('making one records the moment', () {
    late Directory root;
    late AppDatabase db;
    late BackupService service;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('fitlog_backup_stamp');
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      service = BackupService(db: db, paths: AppPaths(root));
    });

    tearDown(() async {
      await db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('there is no moment before the first backup', () async {
      expect((await db.settingsDao.getSettings()).lastBackupAt, isNull);
    });

    test('a finished backup leaves one behind', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await service.createBackup(
        recoveryPhrase: 'abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon abandon about',
        dek: Uint8List(32),
      );

      final stamp = (await db.settingsDao.getSettings()).lastBackupAt;
      expect(stamp, isNotNull);
      expect(stamp, greaterThanOrEqualTo(before));
    });

    test('a failed backup does not silence the reminder', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(lastBackupAt: Value(1000)),
      );

      // A directory where the snapshot file has to go: VACUUM INTO cannot
      // write there, so the backup fails partway.
      await Directory('${root.path}/export/snapshot.db').create(
        recursive: true,
      );
      await expectLater(
        service.createBackup(
          recoveryPhrase: 'abandon abandon abandon abandon abandon abandon '
              'abandon abandon abandon abandon abandon about',
          dek: Uint8List(32),
        ),
        throwsA(anything),
      );

      expect((await db.settingsDao.getSettings()).lastBackupAt, 1000);
    });
  });
}
