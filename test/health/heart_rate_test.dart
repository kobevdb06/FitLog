import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/health/data/health_import.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:fitlog/features/history/presentation/workout_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The heart rate a watch measured during a session: worked out from its
/// samples, put on the session, and there for the screen and the coach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final start = DateTime(2026, 9, 30, 21, 30);
  final end = DateTime(2026, 9, 30, 22, 30);

  ImportedReading bpm(int minutes, double value) => ImportedReading(
    at: start.add(Duration(minutes: minutes)),
    value: value,
  );

  group('uit de metingen', () {
    test('het gemiddelde en het hoogste binnen de training', () {
      final summary = summarizeHeartRate(
        [bpm(0, 100), bpm(20, 150), bpm(40, 110), bpm(60, 100)],
        from: start,
        to: end,
      )!;

      expect(summary.average, 115);
      expect(summary.highest, 150);
      expect(summary.samples, 4);
    });

    test('wat ervoor of erna gemeten werd, telt niet', () {
      // Een horloge geeft hele records door, die voorbij de laatste set
      // kunnen lopen.
      final summary = summarizeHeartRate(
        [bpm(-10, 180), bpm(10, 120), bpm(90, 60)],
        from: start,
        to: end,
      )!;

      expect(summary.average, 120);
      expect(summary.highest, 120);
    });

    test('zonder metingen: niets', () {
      expect(summarizeHeartRate(const [], from: start, to: end), isNull);
    });
  });

  group('bij de training', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w1',
              name: 'Push',
              startedAt: start.millisecondsSinceEpoch,
              endedAt: Value(end.millisecondsSinceEpoch),
              durationSeconds: const Value(3600),
            ),
          );
    });
    tearDown(() => db.close());

    Future<WorkoutRow> workout() => (db.select(
      db.workoutsTable,
    )..where((t) => t.id.equals('w1'))).getSingle();

    test('een import zet de hartslag op de training', () async {
      final watch = _Watch([bpm(5, 110), bpm(30, 150), bpm(55, 85)]);

      final summary = await HealthImport(
        db,
        watch,
      ).fetch(from: DateTime(2026, 9, 29), to: DateTime(2026, 10, 1));

      expect(summary.heartRates, 1);
      expect((await workout()).avgHeartRate, 115);
      expect((await workout()).maxHeartRate, 150);
      // Precies de minuten van de training, niet de hele maand.
      expect(watch.asked.single, (from: start, to: end));
    });

    test('een training buiten het stuk wordt niet gevraagd', () async {
      final watch = _Watch([bpm(5, 110)]);

      await HealthImport(
        db,
        watch,
      ).fetch(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 3));

      expect(watch.asked, isEmpty);
      expect((await workout()).avgHeartRate, isNull);
    });

    test('vergeten wist de hartslag, en niet de training', () async {
      await db.healthDao.setWorkoutHeartRate('w1', average: 115, highest: 150);

      await db.healthDao.forgetImported();

      final row = await workout();
      expect(row.avgHeartRate, isNull);
      expect(row.name, 'Push');
    });

    test('de coach ziet ze bij je laatste sessies', () async {
      await db.healthDao.setWorkoutHeartRate('w1', average: 115, highest: 150);

      final lookup = await CoachTools(db).run('recent_workouts', const {});
      final session =
          ((jsonDecode(lookup.json) as Map)['workouts'] as List).single as Map;

      expect(session['heart_rate'], {'average': 115, 'highest': 150});
    });

    testWidgets('en ze staan bij de training', (tester) async {
      await tester.runAsync(
        () =>
            db.healthDao.setWorkoutHeartRate('w1', average: 115, highest: 150),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        wrapWithContainer(
          container,
          const WorkoutDetailScreen(workoutId: 'w1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('115 bpm'), findsOneWidget);
      expect(find.text('150 bpm'), findsOneWidget);
      expect(find.textContaining('horloge'), findsOneWidget);
    });

    testWidgets('en zonder horloge staat er niets over', (tester) async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        wrapWithContainer(
          container,
          const WorkoutDetailScreen(workoutId: 'w1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Gem. hartslag'), findsNothing);
    });
  });
}

class _Watch implements HealthSource {
  _Watch(this.samples);

  final List<ImportedReading> samples;
  final List<({DateTime from, DateTime to})> asked = [];

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async {
    asked.add((from: from, to: to));
    return samples;
  }

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
