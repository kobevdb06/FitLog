import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/health/data/health_import.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/health/presentation/health_overview_screen.dart';
import 'package:fitlog/features/health/presentation/steps_week_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Blood oxygen during the night, and steps per day.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final asleep = DateTime(2026, 10, 2, 23);
  final woke = DateTime(2026, 10, 3, 7);

  group('zuurstof uit de nacht', () {
    ImportedReading at(int minutes, double value) => ImportedReading(
      at: asleep.add(Duration(minutes: minutes)),
      value: value,
    );

    test('het gemiddelde en het laagste, alleen van die nacht', () {
      final oxygen = oxygenFromNight(
        [at(60, 96), at(120, 94), at(180, 97), at(600, 80)],
        from: asleep,
        to: woke,
      )!;

      expect(oxygen.average, 95.7);
      expect(oxygen.lowest, 94);
    });

    test('één meting is geen nacht', () {
      expect(
        oxygenFromNight([at(60, 96), at(90, 95)], from: asleep, to: woke),
        isNull,
      );
    });
  });

  group('ophalen', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
    });
    tearDown(() => db.close());

    test('stappen per dag, ook die van vandaag tot nu', () async {
      final watch = _Watch(
        daySteps: {DateTime(2026, 10, 2): 8432, DateTime(2026, 10, 3): 1200},
      );

      final summary = await HealthImport(
        db,
        watch,
      ).fetch(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 3, 9));

      final rows = await db.select(db.dailyVitalsTable).get();
      expect(summary.stepDays, 2);
      expect(rows.map((r) => r.steps), [8432, 1200]);
      // Vandaag tot nu, niet tot middernacht.
      expect(watch.asked.last, (
        from: DateTime(2026, 10, 3),
        to: DateTime(2026, 10, 3, 9),
      ));
    });

    test('zuurstof bij de ochtend van de nacht', () async {
      await db.recoveryDao.setSleep(fellAsleepAt: asleep, wokeAt: woke);

      final summary = await HealthImport(
        db,
        _Watch(
          oxygen: [
            for (var m = 30; m < 480; m += 60)
              ImportedReading(
                at: asleep.add(Duration(minutes: m)),
                value: m == 270 ? 90 : 96,
              ),
          ],
        ),
      ).fetch(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 3, 9));

      final row = (await db.select(db.dailyVitalsTable).get()).firstWhere(
        (r) => r.spo2Avg != null,
      );
      expect(summary.oxygenNights, 1);
      expect(
        DateTime.fromMillisecondsSinceEpoch(row.day),
        DateTime(2026, 10, 3),
      );
      expect(row.spo2Min, 90);
    });

    test('en een latere HRV-import wist je stappen niet', () async {
      await db.healthDao.setSteps(DateTime(2026, 10, 3), 5000);

      await db.healthDao.importVitals(day: DateTime(2026, 10, 3), hrvMs: 44);
      await db.healthDao.setDerivedRestingHr(DateTime(2026, 10, 3), 52);

      final row = await db.select(db.dailyVitalsTable).getSingle();
      expect(row.steps, 5000);
      expect(row.hrvMs, 44);
      expect(row.restingHr, 52);
    });

    test('de coach ziet ze', () async {
      await db.healthDao.setSteps(DateTime(2026, 10, 3), 8432);
      await db.healthDao.setNightOxygen(
        DateTime(2026, 10, 3),
        average: 95.5,
        lowest: 91,
      );

      final lookup = await CoachTools(db).run('steps', const {});
      final day =
          ((jsonDecode(lookup.json) as Map)['days'] as List).single as Map;

      expect(day['steps'], 8432);
      expect(day['night_spo2'], {'average': 95.5, 'lowest': 91.0});
      expect(lookup.summary, 'je stappen en zuurstof per dag');
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
      tester.view.physicalSize = const Size(1100, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapWithContainer(container, screen));
      await tester.pumpAndSettle();
    }

    testWidgets('stappen per dag van de week, met de pijltjes', (tester) async {
      await tester.runAsync(() async {
        await db.healthDao.setSteps(DateTime(2026, 9, 28), 6000);
        await db.healthDao.setSteps(DateTime(2026, 10, 2), 10000);
        await db.healthDao.setSteps(DateTime(2026, 9, 25), 4321);
      });
      // Zaterdag 3 oktober: de week van 28/9 tot 4/10.
      await pump(tester, StepsWeekScreen(now: DateTime(2026, 10, 3, 9)));

      expect(find.text('28/9 – 4/10'), findsOneWidget);
      expect(find.text('16.000'), findsOneWidget);
      expect(find.text('8000'), findsNothing);
      expect(find.text('8.000'), findsOneWidget);
      expect(find.text('10.000'), findsWidgets);
      expect(find.textContaining('maandag 28 september'), findsOneWidget);
      // Zondag komt pas: geen rij voor een dag die er nog niet was.
      expect(find.textContaining('zondag 4 oktober'), findsNothing);

      await tester.tap(find.byTooltip('Vorige week'));
      await tester.pumpAndSettle();
      expect(find.text('4.321'), findsWidgets);
    });

    testWidgets('op Gezondheid: stappen van vandaag en zuurstof bij de nacht', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.runAsync(() async {
        await db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
        );
        await db.recoveryDao.setSleep(
          fellAsleepAt: today.subtract(const Duration(hours: 1)),
          wokeAt: today.add(const Duration(hours: 7)),
        );
        await db.healthDao.setNightOxygen(today, average: 95.5, lowest: 91);
        await db.healthDao.setSteps(today, 4321);
      });
      await pump(tester, HealthOverviewScreen(now: now));

      expect(find.text('4.321'), findsWidgets);
      expect(
        find.text('Zuurstof die nacht: gemiddeld 95.5% · laagste 91%'),
        findsOneWidget,
      );
    });
  });
}

class _Watch implements HealthSource {
  _Watch({this.daySteps = const {}, this.oxygen = const []});

  final Map<DateTime, int> daySteps;
  final List<ImportedReading> oxygen;
  final List<({DateTime from, DateTime to})> asked = [];

  @override
  Future<int?> steps({required DateTime from, required DateTime to}) async {
    asked.add((from: from, to: to));
    return daySteps[DateTime(from.year, from.month, from.day)];
  }

  @override
  Future<List<ImportedReading>> oxygenSaturation({
    required DateTime from,
    required DateTime to,
  }) async => oxygen;

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async => const HealthSnapshot();

  @override
  Future<List<String>> missingAccess() async => const [];

  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.available;

  @override
  Future<void> openInstall() async {}

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> revokeAccess() async {}

  @override
  Future<bool> requestWriteAccess() async => true;

  @override
  Future<bool> requestBackgroundAccess() async => true;

  @override
  Future<String?> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async => null;

  @override
  Future<void> deleteWorkout(String id) async {}
}
