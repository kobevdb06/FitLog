import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/settings/presentation/workout_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// "Warming-up sets bij een nieuwe oefening" came out as a column of single
/// letters down the screen: a ListTile gives its trailing widget the width it
/// asks for, and six segments left the title almost none.
///
/// These check the titles are laid out as lines of text rather than columns of
/// characters, on a narrow phone and at a large system font.
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

  /// The widest single line the text actually occupies.
  double widthOf(WidgetTester tester, String text) =>
      tester.getSize(find.text(text)).width;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(360, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithContainer(
        container,
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const WorkoutPreferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const longest = 'Warming-up sets bij een nieuwe oefening';

  testWidgets('the longest title gets a usable width', (tester) async {
    await pump(tester);

    // A single character is around 10 logical pixels wide. Anything near that
    // is the bug: the text is being wrapped one letter per line.
    expect(
      widthOf(tester, longest),
      greaterThan(200),
      reason: 'the title was squeezed to a column of characters',
    );
  });

  testWidgets('and keeps one at a large system font', (tester) async {
    await pump(tester, textScale: 1.6);

    expect(widthOf(tester, longest), greaterThan(200));
  });

  testWidgets('and on a narrow phone', (tester) async {
    await pump(tester, size: const Size(320, 2400));

    expect(widthOf(tester, longest), greaterThan(180));
  });

  testWidgets('nothing overflows', (tester) async {
    await pump(tester, textScale: 1.6, size: const Size(320, 2600));

    expect(
      tester.takeException(),
      isNull,
      reason: 'a RenderFlex overflow is reported as an exception in tests',
    );
  });

  testWidgets('elke keuzerij past op het scherm, zonder te schuiven', (
    tester,
  ) async {
    // A phone with its display size turned up, and the largest text the app
    // allows: the warm-up row ran off the right edge there, its 5 cut off.
    await pump(tester, size: const Size(360, 2600), textScale: 1.4);

    final rows = find.byType(SegmentedButton<int>);
    expect(rows, findsWidgets);
    for (final row in tester.widgetList(rows)) {
      final rect = tester.getRect(find.byWidget(row));
      expect(rect.left, greaterThanOrEqualTo(15.5));
      expect(rect.right, lessThanOrEqualTo(360 - 15.5));
    }
    final five = tester.getRect(find.text('5'));
    expect(five.right, lessThanOrEqualTo(360 - 15.5));
  });

  testWidgets('de rusttijd in minuten en seconden', (tester) async {
    await tester.runAsync(
      () => db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(defaultRestSeconds: Value(150)),
      ),
    );
    await pump(tester);

    expect(find.text('2 min 30 s'), findsOneWidget);
    expect(find.text('150 seconden'), findsNothing);
  });

  testWidgets('the choices are all still there and pick', (tester) async {
    await pump(tester);

    for (final label in ['0', '1', '2', '3', '4', '5']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('3').first);
    await tester.pumpAndSettle();

    expect((await db.settingsDao.getSettings()).defaultWarmupSets, 3);
  });

  testWidgets('de hint per oefening staat aan, en gaat uit', (tester) async {
    await pump(tester);

    final hint = find.widgetWithText(SwitchListTile, 'Hint per oefening');
    expect(tester.widget<SwitchListTile>(hint).value, isTrue);

    await tester.tap(hint);
    await tester.pumpAndSettle();

    expect((await db.settingsDao.getSettings()).progressionHints, isFalse);
  });

  testWidgets('de melding van het weekoverzicht staat aan, en gaat uit', (
    tester,
  ) async {
    await pump(tester);

    final week = find.widgetWithText(SwitchListTile, 'Melding op zondagavond');
    await tester.ensureVisible(week);
    expect(tester.widget<SwitchListTile>(week).value, isTrue);

    await tester.tap(week);
    await tester.pumpAndSettle();

    expect((await db.settingsDao.getSettings()).weekReviewNotify, isFalse);
  });
}
