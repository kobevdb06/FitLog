import 'dart:convert';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/widgets/week_navigator.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fitlog/features/health/presentation/heart_rate_week_screen.dart';
import 'package:fitlog/features/morning/domain/morning_facts.dart';
import 'package:fitlog/features/morning/presentation/report_week_screen.dart';
import 'package:fitlog/features/progress/presentation/sleep_week_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Nights and reports a week at a time: the week you are in first, the ones
/// before it with an arrow, and none from the future.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  // Zaterdag 3 oktober 2026; die week loopt van maandag 28/9 tot zondag 4/10.
  final now = DateTime(2026, 10, 3, 9);

  group('de week', () {
    test('begint op maandag', () {
      expect(weekStartOf(now), DateTime(2026, 9, 28));
      expect(weekStartOf(DateTime(2026, 9, 28, 23)), DateTime(2026, 9, 28));
      expect(weekStartOf(DateTime(2026, 10, 4, 23)), DateTime(2026, 9, 28));
      expect(weekStartOf(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    });

    test('heet naar haar eerste en laatste dag', () {
      expect(weekLabel(DateTime(2026, 9, 28)), '28/9 – 4/10');
    });

    test('ook de week dat de klok verspringt', () {
      // Op 25 oktober 2026 gaat de klok terug; de week erna begint om
      // middernacht, niet om 23 uur.
      expect(weekEndOf(DateTime(2026, 10, 19)), DateTime(2026, 10, 26));
    });
  });

  group('de schermen', () {
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

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(1100, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapWithContainer(container, screen));
      await tester.pumpAndSettle();
    }

    Future<void> night(DateTime woke, {int hours = 8}) =>
        db.recoveryDao.setSleep(
          fellAsleepAt: woke.subtract(Duration(hours: hours)),
          wokeAt: woke,
        );

    testWidgets('de nachten van deze week, en met het pijltje die ervoor', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await night(DateTime(2026, 10, 3, 7));
        await night(DateTime(2026, 10, 2, 7), hours: 6);
        await night(DateTime(2026, 9, 25, 7), hours: 7);
      });
      await pump(tester, SleepWeekScreen(now: now));

      expect(find.text('28/9 – 4/10'), findsOneWidget);
      expect(find.text('Deze week'), findsOneWidget);
      expect(find.textContaining('zaterdag 3 oktober'), findsOneWidget);
      expect(find.textContaining('vrijdag 2 oktober'), findsOneWidget);
      expect(find.textContaining('25 september'), findsNothing);
      // Geen weken uit de toekomst.
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.byTooltip('Vorige week'));
      await tester.pumpAndSettle();

      expect(find.text('21/9 – 27/9'), findsOneWidget);
      expect(find.textContaining('25 september'), findsOneWidget);
      expect(find.textContaining('zaterdag 3 oktober'), findsNothing);

      await tester.tap(find.byTooltip('Vorige week'));
      await tester.pumpAndSettle();
      expect(find.text('Geen nachten in deze week.'), findsOneWidget);
    });

    testWidgets('met de fasen als balk, met wat elke kleur is', (tester) async {
      await tester.runAsync(
        () => db.recoveryDao.setSleep(
          fellAsleepAt: DateTime(2026, 10, 2, 23),
          wokeAt: DateTime(2026, 10, 3, 7),
          lightMinutes: 240,
          remMinutes: 100,
          deepMinutes: 80,
        ),
      );
      await pump(tester, SleepWeekScreen(now: now));

      expect(find.textContaining('Licht 4 u'), findsOneWidget);
      expect(find.textContaining('REM 1 u 40'), findsOneWidget);
      expect(find.textContaining('Diep 1 u 20'), findsOneWidget);
      // De fasen staan niet ook nog eens als tekstregel.
      expect(find.text('licht 4 u · REM 1 u 40 · diep 1 u 20'), findsNothing);
    });

    testWidgets('de rapporten van deze week', (tester) async {
      await tester.runAsync(() async {
        for (final (day, score) in [(3, 81), (1, 64), (26, 70)]) {
          final at = DateTime(2026, day == 26 ? 9 : 10, day, 7);
          await db.reportsDao.saveReport(
            day: at,
            createdAt: at,
            facts: jsonEncode(
              MorningFacts(
                day: DateTime(at.year, at.month, at.day),
                score: score,
              ).toJson(),
            ),
            coachText: 'Rapport van $day',
          );
        }
      });
      await pump(tester, ReportWeekScreen(now: now));

      expect(find.text('Rapport van 3'), findsOneWidget);
      expect(find.text('Rapport van 1'), findsOneWidget);
      expect(find.text('Rapport van 26'), findsNothing);
      expect(find.text('81'), findsOneWidget);

      await tester.tap(find.byTooltip('Vorige week'));
      await tester.pumpAndSettle();
      expect(find.text('Rapport van 26'), findsOneWidget);
    });

    testWidgets('de trainingen van deze week, met hun hartslag', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final (id, start, average) in [
          ('w1', DateTime(2026, 10, 2, 18), 120),
          ('w2', DateTime(2026, 10, 1, 18), null),
          // De week ervoor.
          ('w3', DateTime(2026, 9, 25, 18), 110),
        ]) {
          await db
              .into(db.workoutsTable)
              .insert(
                WorkoutsTableCompanion.insert(
                  id: id,
                  name: 'Sessie $id',
                  startedAt: start.millisecondsSinceEpoch,
                  endedAt: Value(
                    start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
                  ),
                  avgHeartRate: Value(average),
                  maxHeartRate: Value(average == null ? null : average + 30),
                ),
              );
        }
      });
      await pump(tester, HeartRateWeekScreen(now: now));

      expect(find.text('Sessie w1'), findsOneWidget);
      expect(find.text('Sessie w2'), findsOneWidget);
      expect(find.textContaining('gem. 120 · max. 150 bpm'), findsOneWidget);
      expect(find.textContaining('geen hartslag gemeten'), findsOneWidget);
      expect(find.text('Sessie w3'), findsNothing);
      // Het gemiddelde telt alleen wat gemeten werd.
      expect(find.text('120 bpm'), findsOneWidget);

      await tester.tap(find.byTooltip('Vorige week'));
      await tester.pumpAndSettle();
      expect(find.text('Sessie w3'), findsOneWidget);
    });
  });
}
