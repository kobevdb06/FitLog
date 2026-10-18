import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/deload.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/deload/presentation/deload_banner.dart';
import 'package:fitlog/features/deload/presentation/deload_settings_screen.dart';
import 'package:fitlog/features/deload/presentation/deload_start_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A deload from the user's side: the settings, the sheet that starts one,
/// the banner while it runs and the proposal on Start - on a 360dp phone
/// with large text.
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

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 1600),
            textScaler: TextScaler.linear(1.4),
          ),
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<AppSettingsRow> settings(WidgetTester tester) async =>
      (await tester.runAsync(db.settingsDao.getSettings))!;

  group('de instellingen', () {
    testWidgets('alles staat erin, en past op een smalle gsm', (tester) async {
      await pump(tester, const DeloadSettingsScreen());

      for (final text in [
        'Minder werksets',
        'Lichter gewicht',
        'Minder herhalingen',
        'Dropsets en sets tot falen weglaten',
        'Recordpogingen toestaan',
        'Standaardduur',
        'Standaard starten',
        'Deload voorstellen',
        'Na zoveel weken zonder pauze',
        'Of als zoveel oefeningen stilstaan',
        'Later vraagt opnieuw na',
      ]) {
        await tester.scrollUntilVisible(find.text(text), 100);
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('een langere standaardduur wordt bewaard', (tester) async {
      await pump(tester, const DeloadSettingsScreen());

      await tester.scrollUntilVisible(find.text('7 dagen'), 100);
      await tester.tap(find.byTooltip('Standaardduur: meer'));
      await tester.pumpAndSettle();

      expect((await settings(tester)).deloadDays, 8);
      expect(find.text('8 dagen'), findsOneWidget);
    });

    testWidgets('voorstellen weer aanzetten haalt ook Later weg', (
      tester,
    ) async {
      await tester.runAsync(
        () => db.settingsDao.updateSettings(
          AppSettingsTableCompanion(
            deloadSuggest: const Value(false),
            deloadSnoozedUntil: Value(
              DateTime.now()
                  .add(const Duration(days: 2))
                  .millisecondsSinceEpoch,
            ),
          ),
        ),
      );
      await pump(tester, const DeloadSettingsScreen());

      final tile = find.widgetWithText(SwitchListTile, 'Deload voorstellen');
      await tester.scrollUntilVisible(tile, 100);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      final now = await settings(tester);
      expect(now.deloadSuggest, isTrue);
      expect(now.deloadSnoozedUntil, isNull);
    });
  });

  group('het startblad', () {
    testWidgets('kiest begin en duur, en plant de deload', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDeloadStartSheet(context, source: 'user'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vandaag ·'), findsOneWidget);
      expect(find.text('7 dagen'), findsOneWidget);
      await tester.tap(find.byTooltip('Een dag korter'));
      await tester.pump();
      await tester.tap(find.byTooltip('Een dag korter'));
      await tester.pumpAndSettle();
      expect(find.text('5 dagen'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('Morgen ·'));
      await tester.pumpAndSettle();
      final start = find.text('Deload starten').last;
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();

      final deload = (await tester.runAsync(
        () => db.deloadDao.currentAt(DateTime.now()),
      ))!;
      final today = DateTime.now();
      expect(deload.from, DateTime(today.year, today.month, today.day + 1));
      expect(deload.days, 5);
      expect(deload.source, 'user');
      expect(deload.plan.setsPercent, 50);
      expect(find.textContaining('Deload gepland vanaf'), findsOneWidget);
    });

    test('maandag niet twee keer, als morgen maandag is', () {
      final sunday = DateTime(2026, 10, 18);
      final choices = deloadStartChoices(sunday);
      expect(choices.map((c) => c.$1), ['Vandaag', 'Morgen']);

      final saturday = DateTime(2026, 10, 17);
      expect(deloadStartChoices(saturday).last.$2, DateTime(2026, 10, 19));
    });

    test('wat een deload doet, in één regel', () {
      expect(
        deloadPlanSummary(const DeloadPlan()),
        'Werksets −50% · gewicht −10% · herhalingen gelijk · zonder dropsets',
      );
    });
  });

  group('de balk', () {
    testWidgets('welke dag, tot wanneer, en stoppen', (tester) async {
      await tester.runAsync(
        () => db.deloadDao.start(
          from: DateTime.now(),
          days: 6,
          plan: const DeloadPlan(),
          source: 'user',
        ),
      );
      await pump(tester, const Scaffold(body: DeloadBanner()));

      expect(find.textContaining('Dag 1 van 6'), findsOneWidget);
      await tester.tap(find.text('Stoppen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stoppen').last);
      await tester.pumpAndSettle();

      expect(
        await tester.runAsync(() => db.deloadDao.onAt(DateTime.now())),
        isNull,
      );
      expect(find.textContaining('Dag 1'), findsNothing);
    });
  });

  group('het voorstel', () {
    /// A finished ordinary session on each of the last [weeks] weeks.
    Future<void> trainedFor(int weeks) async {
      final now = DateTime.now();
      for (var w = 0; w < weeks; w++) {
        final at = now.subtract(Duration(days: 7 * w));
        await db
            .into(db.workoutsTable)
            .insert(
              WorkoutsTableCompanion.insert(
                id: 'w$w',
                name: 'Push',
                startedAt: at.millisecondsSinceEpoch,
                endedAt: Value(at.millisecondsSinceEpoch + 3600000),
              ),
            );
      }
    }

    Future<void> pumpCard(WidgetTester tester) => pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(child: DeloadSuggestionCard()),
      ),
    );

    testWidgets('na zes weken zonder pauze, met drie knoppen op één lijn', (
      tester,
    ) async {
      await tester.runAsync(() => trainedFor(7));
      await pumpCard(tester);

      expect(find.text('Tijd voor een deloadweek?'), findsOneWidget);
      expect(find.text('Je traint al 7 weken zonder pauze.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final heights = {
        tester.getSize(find.widgetWithText(FilledButton, 'Starten')).height,
        tester.getSize(find.widgetWithText(OutlinedButton, 'Later')).height,
        tester.getSize(find.byTooltip('Melding dempen')).height,
      };
      final tops = {
        tester.getCenter(find.widgetWithText(FilledButton, 'Starten')).dy,
        tester.getCenter(find.widgetWithText(OutlinedButton, 'Later')).dy,
        tester.getCenter(find.byTooltip('Melding dempen')).dy,
      };
      expect(heights, hasLength(1));
      expect(tops, hasLength(1));
    });

    testWidgets('nog geen zes weken: geen voorstel', (tester) async {
      await tester.runAsync(() => trainedFor(3));
      await pumpCard(tester);

      expect(find.text('Tijd voor een deloadweek?'), findsNothing);
    });

    testWidgets('later legt het weg voor de dagen uit de instellingen', (
      tester,
    ) async {
      await tester.runAsync(() => trainedFor(7));
      await pumpCard(tester);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      final now = await settings(tester);
      final today = DateTime.now();
      expect(
        DateTime.fromMillisecondsSinceEpoch(now.deloadSnoozedUntil!),
        DateTime(today.year, today.month, today.day + 3),
      );
      expect(find.text('Tijd voor een deloadweek?'), findsNothing);
    });

    testWidgets('dempen zet het uit, en zegt waar het weer aan gaat', (
      tester,
    ) async {
      await tester.runAsync(() => trainedFor(7));
      await pumpCard(tester);

      await tester.tap(find.byTooltip('Melding dempen'));
      await tester.pumpAndSettle();

      expect((await settings(tester)).deloadSuggest, isFalse);
      expect(find.text('Tijd voor een deloadweek?'), findsNothing);
      expect(
        find.textContaining('Instellingen → Training → Deload'),
        findsOneWidget,
      );
    });
  });

  test('de reden, in woorden', () {
    const both = DeloadReason(weeks: 7, stalled: ['Bench Press', 'Back Squat']);
    expect(
      deloadReasonText(both, weeksLimit: 6, stalledLimit: 2),
      'Je traint al 7 weken zonder pauze, en 2 oefeningen staan stil: '
      'Bench Press en Back Squat.',
    );
    expect(
      deloadReasonText(both, weeksLimit: 8, stalledLimit: 2),
      '2 oefeningen staan stil: Bench Press en Back Squat.',
    );
    expect(
      deloadReasonText(
        const DeloadReason(weeks: 2, stalled: ['Deadlift']),
        weeksLimit: 6,
        stalledLimit: 1,
      ),
      '1 oefening staat stil: Deadlift.',
    );
  });
}
