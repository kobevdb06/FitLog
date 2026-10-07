import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/backup/data/auto_backup.dart';
import 'package:fitlog/features/backup/data/backup_folder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A folder in memory: what was written, and whether writing works.
class _Folder implements BackupFolder {
  final files = <String, DateTime>{};
  bool reachable = true;
  final deleted = <String>[];

  @override
  Future<PickedFolder?> pick() async =>
      const PickedFolder(uri: 'content://tree/backups', name: 'Backups');

  @override
  Future<String?> nameOf(String uri) async => reachable ? 'Backups' : null;

  @override
  Future<void> write(String uri, String fileName, String sourcePath) async {
    if (!reachable) throw StateError('De map is weg.');
    expect(File(sourcePath).existsSync(), isTrue);
    files[fileName] = DateTime.now();
  }

  @override
  Future<List<FolderFile>> list(String uri) async => [
    for (final MapEntry(key: name, value: at) in files.entries)
      FolderFile(name: name, modifiedAt: at),
  ];

  @override
  Future<void> delete(String uri, String fileName) async {
    files.remove(fileName);
    deleted.add(fileName);
  }

  @override
  Future<void> release(String uri) async {}
}

void main() {
  late AppDatabase db;
  late _Folder folder;
  late Directory temp;
  late DateTime now;
  var made = 0;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    folder = _Folder();
    temp = await Directory.systemTemp.createTemp('fitlog-auto-');
    now = DateTime(2026, 10, 7, 18);
    made = 0;
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// What BackupService does: a file, and the moment stamped.
  Future<File> createBackup() async {
    made++;
    await db.settingsDao.updateSettings(
      AppSettingsTableCompanion(
        lastBackupAt: Value(now.millisecondsSinceEpoch),
      ),
    );
    return File('${temp.path}/backup-$made.fitlog')..writeAsStringSync('x');
  }

  AutoBackup auto() => AutoBackup(
    db: db,
    folder: folder,
    createBackup: createBackup,
    clock: () => now,
  );

  Future<void> pickFolder() => db.settingsDao.updateSettings(
    const AppSettingsTableCompanion(
      autoBackupFolder: Value('content://tree/backups'),
    ),
  );

  Future<void> lastBackup(DateTime at) => db.settingsDao.updateSettings(
    AppSettingsTableCompanion(lastBackupAt: Value(at.millisecondsSinceEpoch)),
  );

  group('wanneer', () {
    test('een week na de laatste back-up, of als er nog geen was', () {
      expect(autoBackupDue(lastBackupAt: null, now: now), isTrue);
      expect(
        autoBackupDue(
          lastBackupAt: now
              .subtract(const Duration(days: 6, hours: 23))
              .millisecondsSinceEpoch,
          now: now,
        ),
        isFalse,
      );
      expect(
        autoBackupDue(
          lastBackupAt: now
              .subtract(const Duration(days: 7))
              .millisecondsSinceEpoch,
          now: now,
        ),
        isTrue,
      );
    });

    test('de naam zegt de dag, en sorteert zo', () {
      expect(autoBackupName(now), 'FitLog-auto-2026-10-07.fitlog');
    });
  });

  test('zonder map staat het uit', () async {
    expect(await auto().runIfDue(), AutoBackupOutcome.off);
    expect(made, 0);
  });

  test('met een map en een oude back-up: een nieuwe in de map', () async {
    await pickFolder();
    await lastBackup(now.subtract(const Duration(days: 8)));

    expect(await auto().runIfDue(), AutoBackupOutcome.made);

    expect(folder.files.keys, ['FitLog-auto-2026-10-07.fitlog']);
    // The copy in the app's own folder is gone again.
    expect(temp.listSync(), isEmpty);
  });

  test('een recente back-up, ook een die je zelf maakte, is genoeg', () async {
    await pickFolder();
    await lastBackup(now.subtract(const Duration(days: 2)));

    expect(await auto().runIfDue(), AutoBackupOutcome.notDue);
    expect(made, 0);
  });

  test('alleen de laatste drie automatische blijven', () async {
    await pickFolder();
    folder.files
      ..['FitLog-auto-2026-09-16.fitlog'] = DateTime(2026, 9, 16)
      ..['FitLog-auto-2026-09-23.fitlog'] = DateTime(2026, 9, 23)
      ..['FitLog-auto-2026-09-30.fitlog'] = DateTime(2026, 9, 30)
      // Yours, made by hand: never touched.
      ..['fitlog-20260901-1200.fitlog'] = DateTime(2026, 9, 1);

    expect(await auto().runIfDue(), AutoBackupOutcome.made);

    expect(folder.deleted, ['FitLog-auto-2026-09-16.fitlog']);
    expect(folder.files.keys.toSet(), {
      'FitLog-auto-2026-09-23.fitlog',
      'FitLog-auto-2026-09-30.fitlog',
      'FitLog-auto-2026-10-07.fitlog',
      'fitlog-20260901-1200.fitlog',
    });
  });

  test('een map die weg is: mislukt, en de herinnering blijft', () async {
    await pickFolder();
    final before = now.subtract(const Duration(days: 30));
    await lastBackup(before);
    folder.reachable = false;

    expect(await auto().runIfDue(), AutoBackupOutcome.failed);

    final settings = await db.settingsDao.getSettings();
    expect(settings.lastBackupAt, before.millisecondsSinceEpoch);
    expect(temp.listSync(), isEmpty);
  });

  test('meteen een eerste, als je net een map koos', () async {
    await pickFolder();
    await lastBackup(now.subtract(const Duration(hours: 1)));

    expect(await auto().runNow(), AutoBackupOutcome.made);
    expect(folder.files, hasLength(1));
  });
}
