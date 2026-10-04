import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/health/data/health_importer.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/health/domain/health_overview.dart';
import 'package:fitlog/features/health/presentation/health_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Gezondheid: every night, reading and heart rate in one place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final now = DateTime(2026, 10, 1, 9);

  SleepEntryRow night(int daysAgo, {int hours = 8, String? source}) {
    final woke = DateTime(now.year, now.month, now.day - daysAgo, 7);
    return SleepEntryRow(
      id: '$daysAgo',
      fellAsleepAt: woke
          .subtract(Duration(hours: hours))
          .millisecondsSinceEpoch,
      wokeAt: woke.millisecondsSinceEpoch,
      source: source,
    );
  }

  group('de nachten', () {
    test('de laatste, het gemiddelde, en alles van de maand', () {
      final overview = sleepOverview(
        [night(1, hours: 6), night(0, hours: 8), night(40)],
        const [],
        now: now,
      );

      expect(overview.nights, hasLength(2));
      expect(overview.last!.length, const Duration(hours: 8));
      expect(overview.last!.score, 100);
      expect(overview.average, const Duration(hours: 7));
    });

    test('zonder nachten: niets', () {
      final overview = sleepOverview(const [], const [], now: now);

      expect(overview.last, isNull);
      expect(overview.average, isNull);
    });
  });

  group('HRV en rusthartslag', () {
    test('de laatste, het gewone en de lijn, oudste eerst', () {
      final days = [
        for (var d = 5; d >= 0; d--)
          VitalsDay(
            day: DateTime(now.year, now.month, now.day - d),
            hrvMs: 40.0 + d,
            restingHr: d.isEven ? 55 : null,
          ),
      ];

      final hrv = readingOverview(days, (d) => d.hrvMs, now: now);
      final resting = readingOverview(days, (d) => d.restingHr, now: now);

      expect(hrv.latest, 40);
      expect(hrv.usual, 42.5);
      expect(hrv.series.first.value, 45);
      expect(resting.series, hasLength(3));
    });

    test('wat ouder is dan een maand, valt weg', () {
      final overview = readingOverview(
        [VitalsDay(day: DateTime(2026, 8, 1), hrvMs: 50)],
        (d) => d.hrvMs,
        now: now,
      );

      expect(overview.latest, isNull);
    });
  });

  group('het scherm', () {
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

    Future<void> pumpScreen(WidgetTester tester, {double width = 1100}) async {
      tester.view.physicalSize = Size(width, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithContainer(container, HealthOverviewScreen(now: DateTime.now())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('met een horloge staat alles erop', (tester) async {
      final today = DateTime.now();
      DateTime day(int ago, int hour) =>
          DateTime(today.year, today.month, today.day - ago, hour);
      await tester.runAsync(() async {
        await db.settingsDao.updateSettings(
          const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
        );
        await HealthImporter(db).apply(
          HealthSnapshot(
            nights: [
              ImportedNight(
                fellAsleepAt: day(1, 23),
                wokeAt: day(0, 6),
                source: 'com.example.watch',
              ),
            ],
            hrv: [
              for (var d = 0; d < 3; d++)
                ImportedReading(at: day(d, 3), value: 48),
            ],
            restingHr: [ImportedReading(at: day(0, 8), value: 54)],
            cardio: [
              ImportedCardio(
                id: 'r1',
                start: day(2, 18),
                end: day(2, 18).add(const Duration(minutes: 42)),
                kind: CardioKind.running,
                source: 'com.strava',
              ),
            ],
          ),
        );
        await db
            .into(db.workoutsTable)
            .insert(
              WorkoutsTableCompanion.insert(
                id: 'w1',
                name: 'Push',
                // Vandaag vroeg: altijd in deze week, ook op een maandag.
                startedAt: day(0, 4).millisecondsSinceEpoch,
                endedAt: Value(day(0, 5).millisecondsSinceEpoch),
                avgHeartRate: const Value(115),
                maxHeartRate: const Value(150),
              ),
            );
      });
      await pumpScreen(tester);

      expect(find.text('7 u'), findsWidgets);
      expect(find.text('48 ms'), findsWidgets);
      expect(find.text('54 bpm'), findsWidgets);
      expect(find.textContaining('gem. 115 · max. 150 bpm'), findsOneWidget);
      expect(find.text('42 min'), findsOneWidget);
      expect(find.textContaining('Verbind Health Connect'), findsNothing);
      // De nacht van het horloge had geen fasen, en dat staat er.
      expect(find.textContaining('geen fasen door'), findsOneWidget);
      expect(find.text('Alle trainingen'), findsOneWidget);

      // En op een smalle gsm past het ook.
      await pumpScreen(tester, width: 360);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('gem. 115 · max. 150 bpm'), findsOneWidget);
    });

    testWidgets('de fasen van afgelopen nacht, met wat elke kleur is', (
      tester,
    ) async {
      final today = DateTime.now();
      await tester.runAsync(
        () => db.recoveryDao.setSleep(
          fellAsleepAt: DateTime(today.year, today.month, today.day - 1, 23),
          wokeAt: DateTime(today.year, today.month, today.day, 7),
          lightMinutes: 240,
          remMinutes: 100,
          deepMinutes: 80,
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Fasen van die nacht'), findsOneWidget);
      expect(find.textContaining('Licht 4 u'), findsOneWidget);
      expect(find.textContaining('REM 1 u 40'), findsOneWidget);
      expect(find.textContaining('Diep 1 u 20'), findsOneWidget);
    });

    testWidgets('zonder horloge: wat je zelf invult, en hoe je meer krijgt', (
      tester,
    ) async {
      await tester.runAsync(
        () => db.recoveryDao.setSleep(
          fellAsleepAt: DateTime.now().subtract(const Duration(hours: 9)),
          wokeAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      await pumpScreen(tester);

      expect(find.textContaining('Verbind Health Connect'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      // Wat alleen een horloge meet, staat er dan niet leeg bij.
      expect(find.text('HRV'), findsNothing);
      expect(find.text('Hartslag tijdens trainingen'), findsNothing);
    });
  });
}
