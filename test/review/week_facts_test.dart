import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/review/data/week_facts_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// One week, as the weekly review reads it from the logbook.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  // Maandag 28 september tot en met zondag 4 oktober 2026.
  final monday = DateTime(2026, 9, 28);
  DateTime day(int offset, [int hour = 18]) =>
      DateTime(monday.year, monday.month, monday.day + offset, hour);
  final sundayEvening = day(6, 20);

  var counter = 0;

  /// One finished session: [sets] working sets of [exercise] at [kg] × [reps].
  Future<void> session(
    DateTime at, {
    String exercise = 'ex-bench',
    String? routine,
    int sets = 3,
    double kg = 80,
    int reps = 8,
  }) async {
    final id = 'w${counter++}';
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: id,
            routineId: Value(routine),
            name: 'Training',
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(at.millisecondsSinceEpoch + 3600000),
            totalVolumeKg: Value(sets * kg * reps),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$id',
            workoutId: id,
            exerciseId: exercise,
            sortOrder: 0,
          ),
        );
    for (var i = 0; i < sets; i++) {
      await db
          .into(db.workoutSetsTable)
          .insert(
            WorkoutSetsTableCompanion.insert(
              id: 'ws-$id-$i',
              workoutExerciseId: 'we-$id',
              sortOrder: i,
              weightKg: Value(kg),
              reps: Value(reps),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  Future<void> routine(String id, String name, int days) => db
      .into(db.routinesTable)
      .insert(
        RoutinesTableCompanion.insert(
          id: id,
          name: name,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          scheduledDays: Value(days),
        ),
      );

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name, muscle) in [
      ('ex-bench', 'Bench Press', 'borst'),
      ('ex-row', 'Barbell Row', 'rug'),
      ('ex-squat', 'Back Squat', 'quadriceps'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: muscle,
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() => db.close());

  group('wat gepland stond', () {
    setUp(() async {
      // Push op maandag en vrijdag, Benen op woensdag, Pull op donderdag.
      await routine('r-push', 'Push', 1 | 16);
      await routine('r-legs', 'Benen', 4);
      await routine('r-pull', 'Pull', 8);
      await session(day(0), routine: 'r-push');
      await session(day(2), routine: 'r-legs', exercise: 'ex-squat');
      // Zaterdag: buiten de planning.
      await session(day(5), exercise: 'ex-row');
    });

    test('gedaan tegenover gepland, en wat er bleef liggen', () async {
      final week = await buildWeekFacts(db, monday, now: sundayEvening);

      expect(week.workouts, 3);
      expect(week.planned, 4);
      expect(week.plannedDone, 2);
      expect(week.extra, 1);
      final missed = {for (final m in week.missed) m.name: m};
      // Push wel op maandag, niet op vrijdag: alleen het aantal is zeker.
      expect(missed['Push']!.times, 1);
      expect(missed['Push']!.weekdays, isEmpty);
      // Pull helemaal niet: dan is de dag bekend.
      expect(missed['Pull']!.weekdays, [DateTime.thursday]);
      expect(missed.containsKey('Benen'), isFalse);
    });

    test('midden in de week is wat nog komt niet gemist', () async {
      final week = await buildWeekFacts(db, monday, now: day(2, 12));

      // Woensdagmiddag: donderdag en vrijdag komen nog.
      expect(week.missed, isEmpty);
    });
  });

  test('sets per spiergroep tegenover de vier weken ervoor', () async {
    for (var w = 1; w <= 4; w++) {
      await session(day(-7 * w), sets: 12);
      await session(day(-7 * w + 2), exercise: 'ex-row', sets: 10);
    }
    await session(day(1), sets: 13);
    await session(day(3), exercise: 'ex-row', sets: 5);

    final week = await buildWeekFacts(db, monday, now: sundayEvening);

    final byMuscle = {for (final m in week.muscles) m.muscle: m};
    expect(byMuscle['borst']!.sets, 13);
    expect(byMuscle['borst']!.usual, 12);
    expect(byMuscle['borst']!.lagging, isFalse);
    expect(byMuscle['rug']!.sets, 5);
    expect(byMuscle['rug']!.usual, 10);
    expect(byMuscle['rug']!.lagging, isTrue);
    // De meeste sets eerst.
    expect(week.muscles.first.muscle, 'borst');
    expect(week.sets, 18);
  });

  test('per oefening het record dat het meest zegt', () async {
    await session(day(1));
    for (final (type, value) in [('max_weight', 80.0), ('est_1rm', 101.3)]) {
      await db
          .into(db.personalRecordsTable)
          .insert(
            PersonalRecordsTableCompanion.insert(
              id: 'pr-$type',
              exerciseId: 'ex-bench',
              recordType: type,
              value: value,
              achievedAt: day(1).millisecondsSinceEpoch,
            ),
          );
    }

    final week = await buildWeekFacts(db, monday, now: sundayEvening);

    expect(week.records.single.exercise, 'Bench Press');
    expect(week.records.single.type, 'est_1rm');
  });

  test('wat stilstond en deze week weer vooruitging', () async {
    // Zes weken 85 kg, deze week 90.
    for (var w = 8; w >= 1; w--) {
      await session(day(-7 * w), kg: w > 6 ? 75.0 + (8 - w) * 5 : 85);
    }
    await session(day(1), kg: 90);

    final week = await buildWeekFacts(db, monday, now: sundayEvening);

    expect(week.movingAgain, ['Bench Press']);
    expect(week.stalled, isEmpty);
  });

  test('je nachten en je stappen, tegenover wat gewoon is', () async {
    for (var d = -28; d < 7; d++) {
      final woke = day(d, 7);
      await db.recoveryDao.setSleep(
        fellAsleepAt: woke.subtract(Duration(minutes: d < 0 ? 450 : 360)),
        wokeAt: woke,
      );
    }
    await db.healthDao.setSteps(day(0), 8000);
    await db.healthDao.setSteps(day(1), 10000);

    final week = await buildWeekFacts(db, monday, now: sundayEvening);

    expect(week.sleepMinutes, 360);
    expect(week.usualSleepMinutes, 450);
    expect(week.sleepScore, isNotNull);
    expect(week.steps, 9000);
  });
}
