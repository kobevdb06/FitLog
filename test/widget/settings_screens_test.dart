import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/settings/presentation/display_settings_screen.dart';
import 'package:fitlog/features/settings/presentation/notification_settings_screen.dart';
import 'package:fitlog/features/settings/presentation/recovery_settings_screen.dart';
import 'package:fitlog/features/settings/presentation/settings_screen.dart';
import 'package:fitlog/features/settings/presentation/training_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Instellingen, in order: a hub grouped by what you are doing, and a screen
/// per subject behind it.
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

  /// The widest single line the text actually occupies.
  double widthOf(WidgetTester tester, String text) =>
      tester.getSize(find.text(text)).width;

  Future<void> pump(
    WidgetTester tester, {
    Widget screen = const TrainingSettingsScreen(),
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
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<AppSettingsRow> settings(WidgetTester tester) async =>
      (await tester.runAsync(db.settingsDao.getSettings))!;

  const screens = <String, Widget>{
    'Instellingen': SettingsScreen(),
    'Training': TrainingSettingsScreen(),
    'Meldingen': NotificationSettingsScreen(),
    'Herstel': RecoverySettingsScreen(),
    'Weergave en eenheden': DisplaySettingsScreen(),
  };

  group('het overzicht', () {
    testWidgets('gegroepeerd: trainen, herstel, de app', (tester) async {
      await pump(tester, screen: const SettingsScreen());

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('TRAINEN'), lessThan(top('Training')));
      expect(top('Training'), lessThan(top('HERSTEL')));
      expect(top('HERSTEL'), lessThan(top('APP')));
      expect(top('APP'), lessThan(top('Meldingen')));
      expect(top('Meldingen'), lessThan(top('Weergave en eenheden')));
      // The grab bag is gone.
      expect(find.text('Workout-voorkeuren'), findsNothing);
    });

    testWidgets('elk onderdeel zegt wat erin zit', (tester) async {
      await pump(tester, screen: const SettingsScreen());

      expect(
        find.text('Rusttimer, records, ochtendrapport en weekoverzicht'),
        findsOneWidget,
      );
      expect(
        find.text('Thema, kg of lb, cm of inch, km of mi'),
        findsOneWidget,
      );
      expect(find.text('Slaapfasen en alcohol bijhouden'), findsOneWidget);
    });
  });

  group('training', () {
    const longest = 'Warming-up sets bij een nieuwe oefening';

    testWidgets('the longest title gets a usable width', (tester) async {
      await pump(tester);

      // A single character is around 10 logical pixels wide. Anything near
      // that is the bug: the text is being wrapped one letter per line.
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

    testWidgets('opwarmen en RPE staan niet meer onder de rusttimer', (
      tester,
    ) async {
      await pump(tester);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('TIJDENS EEN TRAINING'), lessThan(top(longest)));
      expect(top('TIJDENS EEN TRAINING'), lessThan(top('RPE bijhouden')));
      expect(top('RUSTTIMER'), lessThan(top('Standaard rusttijd')));
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

      expect((await settings(tester)).defaultWarmupSets, 3);
    });

    testWidgets('de hint per oefening staat aan, en gaat uit', (tester) async {
      await pump(tester);

      final hint = find.widgetWithText(SwitchListTile, 'Hint per oefening');
      expect(tester.widget<SwitchListTile>(hint).value, isTrue);

      await tester.tap(hint);
      await tester.pumpAndSettle();

      expect((await settings(tester)).progressionHints, isFalse);
    });
  });

  group('meldingen', () {
    testWidgets('alles wat piept of meldt, op een plek', (tester) async {
      await pump(tester, screen: const NotificationSettingsScreen());

      for (final title in [
        'Geluid bij einde rust',
        'Klik bij het afvinken van een set',
        'Melding bij een nieuw record',
        'Elke ochtend een rapport',
        'Melding op zondagavond',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('de melding van het weekoverzicht staat aan, en gaat uit', (
      tester,
    ) async {
      await pump(tester, screen: const NotificationSettingsScreen());

      final week = find.widgetWithText(
        SwitchListTile,
        'Melding op zondagavond',
      );
      await tester.ensureVisible(week);
      expect(tester.widget<SwitchListTile>(week).value, isTrue);

      await tester.tap(week);
      await tester.pumpAndSettle();

      expect((await settings(tester)).weekReviewNotify, isFalse);
    });
  });

  group('herstel', () {
    testWidgets('alcohol bijhouden gaat aan', (tester) async {
      await pump(tester, screen: const RecoverySettingsScreen());

      await tester.tap(find.text('Alcohol bijhouden'));
      await tester.pumpAndSettle();

      expect((await settings(tester)).trackAlcohol, isTrue);
    });
  });

  group('weergave en eenheden', () {
    testWidgets('thema en eenheden kies je met een tik', (tester) async {
      await pump(tester, screen: const DisplaySettingsScreen());

      await tester.tap(find.text('Licht'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('lb'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('mi'));
      await tester.pumpAndSettle();

      final now = await settings(tester);
      expect(now.themeMode, 'light');
      expect(now.unitWeight, 'lb');
      expect(now.unitDistance, 'mi');
    });
  });

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name: niets loopt over, op een smal toestel met grote '
        'letters', (tester) async {
      await pump(
        tester,
        screen: screen,
        textScale: 1.6,
        size: const Size(320, 2600),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'a RenderFlex overflow is reported as an exception in tests',
      );
    });

    testWidgets('$name: elke keuzerij past op het scherm', (tester) async {
      // A phone with its display size turned up, and the largest text the
      // app allows: the warm-up row ran off the right edge there.
      await pump(
        tester,
        screen: screen,
        size: const Size(360, 2600),
        textScale: 1.4,
      );

      for (final row in tester.widgetList(
        find.byWidgetPredicate((w) => w is SegmentedButton),
      )) {
        final rect = tester.getRect(find.byWidget(row));
        expect(rect.left, greaterThanOrEqualTo(15.5));
        expect(rect.right, lessThanOrEqualTo(360 - 15.5));
      }
    });
  }
}
