import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/health/data/health_import.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/health/presentation/health_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A resting heart rate for a watch that does not hand one over: the lowest
/// half hour of the heart rate while asleep.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final asleep = DateTime(2026, 10, 2, 23);
  final woke = DateTime(2026, 10, 3, 7);

  /// A sample every ten minutes, at [bpm] for minute [m].
  List<ImportedReading> night(double Function(int minute) bpm) => [
    for (var m = 0; m <= 480; m += 10)
      ImportedReading(
        at: asleep.add(Duration(minutes: m)),
        value: bpm(m),
      ),
  ];

  group('uit de hartslag van de nacht', () {
    test('het laagste halfuur', () {
      // 60 de hele nacht, behalve een halfuur rond drie uur op 50.
      final resting = restingHeartRateFromNight(
        night((m) => m >= 240 && m < 270 ? 50 : 60),
        from: asleep,
        to: woke,
      );

      expect(resting, 50);
    });

    test('één lage meting is het horloge, niet het hart', () {
      final resting = restingHeartRateFromNight(
        night((m) => m == 200 ? 38 : 56),
        from: asleep,
        to: woke,
      );

      expect(resting, greaterThan(50));
    });

    test('wat na het opstaan gemeten werd, telt niet', () {
      final samples = [
        ...night((m) => 58),
        for (var m = 0; m < 60; m += 10)
          ImportedReading(at: woke.add(Duration(minutes: 30 + m)), value: 40),
      ];

      expect(restingHeartRateFromNight(samples, from: asleep, to: woke), 58);
    });

    test('te weinig metingen: niets', () {
      expect(
        restingHeartRateFromNight(
          [
            ImportedReading(at: asleep, value: 55),
            ImportedReading(
              at: asleep.add(const Duration(hours: 3)),
              value: 52,
            ),
          ],
          from: asleep,
          to: woke,
        ),
        isNull,
      );
    });
  });

  group('in de database', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
    });
    tearDown(() => db.close());

    Future<DailyVitalsRow> day() => db.select(db.dailyVitalsTable).getSingle();

    test('komt erin als het horloge er geen gaf', () async {
      expect(await db.healthDao.setDerivedRestingHr(woke, 52), isTrue);

      final row = await day();
      expect(row.restingHr, 52);
      expect(row.restingHrDerived, isTrue);
    });

    test('maar die van het horloge gaat voor', () async {
      await db.healthDao.importVitals(day: woke, restingHr: 55);

      expect(await db.healthDao.setDerivedRestingHr(woke, 50), isFalse);
      expect((await day()).restingHr, 55);
    });

    test('en vervangt een berekende', () async {
      await db.healthDao.setDerivedRestingHr(woke, 50);
      await db.healthDao.importVitals(day: woke, restingHr: 54);

      final row = await day();
      expect(row.restingHr, 54);
      expect(row.restingHrDerived, isFalse);
    });

    test('een import rekent ze uit voor elke nacht', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      await db.recoveryDao.setSleep(fellAsleepAt: asleep, wokeAt: woke);

      final summary = await HealthImport(
        db,
        _Watch(night((m) => m >= 300 && m < 330 ? 49 : 57)),
      ).fetch(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 3, 9));

      expect(summary.restingWorkedOut, 1);
      expect((await day()).restingHr, 49);
    });

    test('de coach ziet dat FitLog ze berekende', () async {
      await db.healthDao.setDerivedRestingHr(DateTime.now(), 51);

      final lookup = await CoachTools(db).run('heart_readings', const {});
      final reading =
          ((jsonDecode(lookup.json) as Map)['days'] as List).single as Map;

      expect(reading['resting_hr'], 51);
      expect(reading['resting_hr_from_sleep'], isTrue);
    });
  });

  group('op Gezondheid', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('zonder HRV geen lege kaart, wel waarom', (tester) async {
      final today = DateTime.now();
      await tester.runAsync(() async {
        for (var d = 0; d < 3; d++) {
          await db.healthDao.setDerivedRestingHr(
            DateTime(today.year, today.month, today.day - d),
            50.0 + d,
          );
        }
      });
      tester.view.physicalSize = const Size(1100, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithContainer(container, HealthOverviewScreen(now: today)),
      );
      await tester.pumpAndSettle();

      expect(find.text('HRV'), findsNothing);
      expect(
        find.textContaining('HRV geeft je horloge niet door'),
        findsOneWidget,
      );
      expect(find.text('50 bpm'), findsOneWidget);
      expect(find.textContaining('Berekend uit je hartslag'), findsOneWidget);
    });
  });
}

class _Watch implements HealthSource {
  _Watch(this.heart);

  final List<ImportedReading> heart;

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async => heart;

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async => const HealthSnapshot();

  @override
  Future<List<ImportedReading>> oxygenSaturation({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<int?> steps({required DateTime from, required DateTime to}) async =>
      null;

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
