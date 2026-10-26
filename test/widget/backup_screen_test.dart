import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/backup/data/backup_folder.dart';
import 'package:fitlog/features/backup/presentation/backup_providers.dart';
import 'package:fitlog/features/settings/presentation/backup_screen.dart';
import 'package:fitlog/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A folder in memory, for the weekly backup.
class _Folder implements BackupFolder {
  final written = <String>[];
  final released = <String>[];
  bool reachable = true;

  @override
  Future<PickedFolder?> pick() async =>
      const PickedFolder(uri: 'content://tree/backups', name: 'Backups');

  @override
  Future<String?> nameOf(String uri) async => reachable ? 'Backups' : null;

  @override
  Future<void> write(String uri, String fileName, String sourcePath) async =>
      written.add(fileName);

  @override
  Future<List<FolderFile>> list(String uri) async => const [];

  @override
  Future<void> delete(String uri, String fileName) async {}

  @override
  Future<void> release(String uri) async => released.add(uri);
}

/// Back-up en export, with what cannot be undone at the very bottom.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late _Folder folder;
  late Directory temp;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    folder = _Folder();
    temp = await Directory.systemTemp.createTemp('fitlog-backup-screen-');
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        backupFolderProvider.overrideWithValue(folder),
        // A backup without keys or photos: the folder is what is tested.
        backupMakerProvider.overrideWithValue(() async {
          await db.settingsDao.updateSettings(
            AppSettingsTableCompanion(
              lastBackupAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
          return File('${temp.path}/backup.fitlog')..writeAsStringSync('x');
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<AppSettingsRow> settings(WidgetTester tester) async =>
      (await tester.runAsync(db.settingsDao.getSettings))!;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithContainer(container, screen));
    await tester.pumpAndSettle();
  }

  testWidgets('terwijl het bezig is, blijft elke regel zichzelf', (
    tester,
  ) async {
    // Busy, a progress bar came in above the rows of the list, and the rows
    // - matched by place, not by name - moved down one: the row you had
    // tapped lit up one higher. Tapping the CSV export lit the backup.
    final waiting = Completer<File>();
    container.dispose();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        backupFolderProvider.overrideWithValue(folder),
        backupMakerProvider.overrideWithValue(() => waiting.future),
      ],
    );
    await pump(tester, const BackupScreen());
    Element row(String title) => tester.element(
      find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
    );
    final before = [
      row('Versleutelde back-up maken'),
      row('CSV-export van workouts'),
    ];

    await tester.tap(find.text('Versleutelde back-up maken'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect([
      row('Versleutelde back-up maken'),
      row('CSV-export van workouts'),
    ], before);

    // Android's share sheet comes next, which a test does not have: the
    // screen goes before it would.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wissen staat niet meer tussen de gewone keuzes', (tester) async {
    await pump(tester, const SettingsScreen());

    expect(find.text('Alle gegevens wissen'), findsNothing);
  });

  testWidgets('maar onderaan de back-up, in de gevarenzone', (tester) async {
    await pump(tester, const BackupScreen());

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Back-up terugzetten'), lessThan(top('GEVARENZONE')));
    expect(top('GEVARENZONE'), lessThan(top('Alle gegevens wissen')));
  });

  testWidgets('en het vraagt het eerst, zonder iets te doen', (tester) async {
    await pump(tester, const BackupScreen());

    await tester.ensureVisible(find.text('Alle gegevens wissen'));
    await tester.tap(find.text('Alle gegevens wissen'));
    await tester.pumpAndSettle();
    expect(find.text('Alle gegevens wissen?'), findsOneWidget);

    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    expect(find.text('Alle gegevens wissen?'), findsNothing);
    expect(await tester.runAsync(db.settingsDao.getSettings), isNotNull);
  });

  /// Lets the screen's work finish: real time for the database and the
  /// files, frames for the screen, until the progress bar is gone.
  Future<void> settleWork(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty && i > 2) {
        break;
      }
    }
  }

  group('elke week', () {
    testWidgets('aanzetten vraagt een map, en zet er meteen een in', (
      tester,
    ) async {
      await pump(tester, const BackupScreen());
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Automatische back-up',
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await settleWork(tester);

      expect(
        (await settings(tester)).autoBackupFolder,
        'content://tree/backups',
      );
      expect(folder.written.single, startsWith('FitLog-auto-'));
      expect(
        find.textContaining(
          'De eerste automatische back-up staat in "Backups"',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Elke week naar "Backups"'), findsOneWidget);
    });

    testWidgets('een map die weg is, zegt dat', (tester) async {
      await tester.runAsync(
        () => db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(
            autoBackupFolder: Value('content://tree/backups'),
          ),
        ),
      );
      folder.reachable = false;
      await pump(tester, const BackupScreen());

      expect(
        find.textContaining('De map is niet meer bereikbaar'),
        findsOneWidget,
      );
    });

    testWidgets('uitzetten geeft de map terug', (tester) async {
      await tester.runAsync(
        () => db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(
            autoBackupFolder: Value('content://tree/backups'),
          ),
        ),
      );
      await pump(tester, const BackupScreen());

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Automatische back-up'),
      );
      await settleWork(tester);

      expect((await settings(tester)).autoBackupFolder, isNull);
      expect(folder.released, ['content://tree/backups']);
    });
  });
}
