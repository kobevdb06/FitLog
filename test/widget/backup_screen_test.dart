import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/settings/presentation/backup_screen.dart';
import 'package:fitlog/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Back-up en export, with what cannot be undone at the very bottom.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithContainer(container, screen));
    await tester.pumpAndSettle();
  }

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
}
