import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/settings/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The Profiel tab.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const ProfileScreen()),
    );
    await tester.pumpAndSettle();
  }

  /// The value above [label] in the totals.
  String tile(WidgetTester tester, String label) {
    final column = find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    );
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: column.first, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .toList();
    return texts.first!;
  }

  testWidgets('je gewicht: de laatste meting, en een tik voor een nieuwe', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.recordsDao.addMeasurement(
        type: MeasurementType.weight,
        value: 82.5,
        measuredAt: DateTime.now(),
      ),
    );
    await pump(tester);

    expect(find.text('Lichaamsgewicht'), findsOneWidget);
    expect(find.textContaining('82,5 kg · vandaag'), findsOneWidget);

    await tester.tap(find.text('Lichaamsgewicht'));
    await tester.pumpAndSettle();
    expect(find.text('Meting toevoegen'), findsOneWidget);
  });

  testWidgets('waar je traint schrijf je hier, en het blijft bewaard', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Nog niet beschreven'), findsOneWidget);

    await tester.ensureVisible(find.text('Waar je traint'));
    await tester.tap(find.text('Waar je traint'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Basic-Fit Gent, geen smith machine',
    );
    await tester.tap(find.text('Opslaan'));
    await tester.pumpAndSettle();

    expect(
      (await tester.runAsync(db.settingsDao.getSettings))!.coachGym,
      'Basic-Fit Gent, geen smith machine',
    );
    expect(find.text('Basic-Fit Gent, geen smith machine'), findsOneWidget);
  });

  testWidgets("onderaan: je records, metingen en foto's, geen tweede weg "
      'naar de instellingen', (tester) async {
    await pump(tester);

    for (final title in [
      'Persoonlijke records',
      'Lichaamsmetingen',
      "Voortgangsfoto's",
    ]) {
      await tester.ensureVisible(find.text(title));
      expect(find.text(title), findsOneWidget, reason: title);
    }
    // The gear at the top is the way in; a list tile saying the same was
    // the only thing under "Meer".
    expect(find.byTooltip('Instellingen'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Instellingen'), findsNothing);
  });

  testWidgets('zonder trainingen geen "0 s" in de zaal', (tester) async {
    await pump(tester);

    expect(tile(tester, 'Tijd in de zaal'), '-');
    expect(find.text('0 s'), findsNothing);
  });
}
