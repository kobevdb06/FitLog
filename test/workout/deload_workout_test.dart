import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/deload.dart';
import 'package:fitlog/core/calc/muscle_sets.dart';
import 'package:fitlog/core/calc/plateau.dart';
import 'package:fitlog/core/calc/progress_period.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A session started during a deload: lighter as the deload says, marked as
/// one, and looked past afterwards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late WorkoutController controller;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    controller = container.read(workoutControllerProvider);
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> routine({double? weight = 80, int? reps = 8}) =>
      db.routinesDao.createRoutine(
        RoutineDraft(
          name: 'Push A',
          exercises: [
            RoutineExerciseDraft(
              exerciseId: 'ex-bench',
              sets: [
                const RoutineSetDraft(
                  setType: SetType.warmup,
                  targetWeightKg: 40,
                  targetReps: 10,
                ),
                for (var i = 0; i < 4; i++)
                  RoutineSetDraft(targetWeightKg: weight, targetReps: reps),
                const RoutineSetDraft(
                  setType: SetType.drop,
                  targetWeightKg: 60,
                  targetReps: 12,
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> deloadNow({DeloadPlan plan = const DeloadPlan()}) => db.deloadDao
      .start(from: DateTime.now(), days: 7, plan: plan, source: 'user');

  Future<WorkoutDetail> detail(String id) async =>
      (await db.workoutsDao.getWorkoutDetail(id))!;

  test('zonder deload is een routine gewoon een routine', () async {
    final id = await controller.startFromRoutine(await routine());
    final workout = await detail(id);

    expect(workout.workout.isDeload, isFalse);
    expect(workout.exercises.single.sets, hasLength(6));
  });

  test(
    'tijdens een deload: de helft van de sets, lichter, zonder dropset',
    () async {
      await deloadNow();
      final id = await controller.startFromRoutine(await routine());
      final workout = await detail(id);
      final sets = workout.exercises.single.sets;

      expect(workout.workout.isDeload, isTrue);
      expect(sets.map((s) => SetType.fromWire(s.setType)), [
        SetType.warmup,
        SetType.normal,
        SetType.normal,
      ]);
      expect(sets.first.weightKg, 40, reason: 'the warm-up stays as it is');
      expect(sets[1].weightKg, 72.5);
      expect(sets[1].reps, 8);
    },
  );

  test('zonder doelen in de routine: de vorige gewone keer, lichter', () async {
    final routineId = await routine(weight: null, reps: null);
    final before = await controller.startFromRoutine(routineId);
    for (final set in (await detail(before)).exercises.single.sets) {
      if (SetType.fromWire(set.setType) == SetType.normal) {
        await controller.completeSet(setId: set.id, weightKg: 100, reps: 5);
      }
    }
    await controller.finish(before, discardPending: true);

    await deloadNow();
    final id = await controller.startFromRoutine(routineId);
    final working = [
      for (final s in (await detail(id)).exercises.single.sets)
        if (SetType.fromWire(s.setType) == SetType.normal) s,
    ];

    expect(working, hasLength(2));
    expect(working.first.weightKg, 90);
    expect(working.first.reps, 5);
  });

  test('daarna kijkt VORIGE over de deload heen', () async {
    final routineId = await routine();
    final normal = await controller.startFromRoutine(routineId);
    for (final set in (await detail(normal)).exercises.single.sets) {
      await controller.completeSet(setId: set.id);
    }
    await controller.finish(normal, discardPending: true);

    await deloadNow();
    final light = await controller.startFromRoutine(routineId);
    for (final set in (await detail(light)).exercises.single.sets) {
      await controller.completeSet(setId: set.id);
    }
    await controller.finish(light, discardPending: true);

    final previous = await db.workoutsDao.previousSetsFor('ex-bench');
    expect(previous.map((s) => s.weightKg), contains(80));
    expect(previous.map((s) => s.weightKg), isNot(contains(72.5)));
  });

  test(
    'een recordpoging en een lege workout worden alleen gemarkeerd',
    () async {
      await deloadNow();
      final id = await controller.startEmpty(name: 'Los');

      expect((await detail(id)).workout.isDeload, isTrue);
    },
  );

  group('sets per spiergroep', () {
    final now = DateTime(2026, 10, 18, 12);

    ProgressSet set(DateTime at, {bool deload = false}) => ProgressSet(
      workoutId: '$at',
      startedAt: at,
      exerciseId: 'ex-bench',
      primaryMuscle: 'borst',
      category: ExerciseCategory.barbell,
      weightKg: 80,
      reps: 8,
      isDeload: deload,
    );

    test('een deloadweek maakt een spier niet achterop', () {
      final sets = [
        // The four weeks before: ten sets a week.
        for (var w = 5; w <= 8; w++)
          for (var i = 0; i < 10; i++)
            set(now.subtract(Duration(days: w * 7 - 1))),
        // This period: three ordinary weeks of ten, and a deload week of
        // three.
        for (var w = 1; w <= 3; w++)
          for (var i = 0; i < 10; i++)
            set(now.subtract(Duration(days: w * 7 - 1))),
        for (var i = 0; i < 3; i++)
          set(now.subtract(const Duration(days: 2)), deload: true),
      ];

      final borst = muscleSetsPerWeek(
        sets,
        period: ProgressPeriod.fourWeeks,
        now: now,
      ).single;

      // The three ordinary weeks over three weeks, not the deload's three
      // sets spread over four.
      expect(borst.perWeek, closeTo(borst.usualPerWeek, 1));
      expect(borst.perWeek, greaterThan(9));
      expect(borst.lagging, isFalse);
    });
  });
}
