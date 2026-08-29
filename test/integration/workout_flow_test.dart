import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/progress/presentation/progress_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// End to end over the real database and the real providers: build a routine,
/// log a session against it, finish it, and check that the history, the
/// totals and the personal records all line up.
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

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final exercise in const [
      ('ex-squat', 'Barbell Squat', 'quadriceps'),
      ('ex-bench', 'Barbell Bench Press', 'borst'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: exercise.$1,
              name: exercise.$2,
              primaryMuscle: exercise.$3,
              category: 'barbell',
              createdAt: now,
            ),
          );
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('routine to workout to history and records', () async {
    // --- 1. Build a routine ------------------------------------------------
    final routineId = await container
        .read(routineActionsProvider)
        .create(
          const RoutineDraft(
            name: 'Push A',
            exercises: [
              RoutineExerciseDraft(
                exerciseId: 'ex-squat',
                restSeconds: 120,
                sets: [
                  RoutineSetDraft(targetReps: 5, targetWeightKg: 100),
                  RoutineSetDraft(targetReps: 5, targetWeightKg: 100),
                ],
              ),
              RoutineExerciseDraft(
                exerciseId: 'ex-bench',
                sets: [
                  RoutineSetDraft(
                    setType: SetType.warmup,
                    targetReps: 8,
                    targetWeightKg: 40,
                  ),
                  RoutineSetDraft(targetReps: 8, targetWeightKg: 80),
                ],
              ),
            ],
          ),
        );

    final routine = await db.routinesDao.getRoutineDetail(routineId);
    expect(routine!.exercises, hasLength(2));
    expect(routine.totalSets, 4);

    // --- 2. Start the session from it --------------------------------------
    final workoutId = await container
        .read(workoutControllerProvider)
        .startFromRoutine(routineId);

    var active = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(active!.isActive, isTrue);
    expect(active.exercises, hasLength(2));
    expect(active.totalSets, 4);
    // The planned targets are carried over as starting values.
    expect(active.exercises.first.sets.first.weightKg, 100);
    expect(active.exercises.first.sets.first.reps, 5);
    expect(active.exercises.first.workoutExercise.restSeconds, 120);
    // ... but nothing is ticked yet.
    expect(active.completedSets, 0);

    // Only one session at a time.
    expect(
      () => db.workoutsDao.startWorkout(defaultRestSeconds: 90),
      throwsStateError,
    );

    // --- 3. Log it ----------------------------------------------------------
    final controller = container.read(workoutControllerProvider);

    final squatSets = active.exercises[0].sets;
    final benchSets = active.exercises[1].sets;

    final firstSquat = await controller.completeSet(setId: squatSets[0].id);
    expect(firstSquat!.records, hasLength(4));
    expect(firstSquat.restSeconds, 120);
    expect(firstSquat.exerciseName, 'Barbell Squat');

    // A heavier second set beats weight, 1RM and volume, but not reps.
    final secondSquat = await controller.completeSet(
      setId: squatSets[1].id,
      weightKg: 110,
      reps: 5,
    );
    expect(
      secondSquat!.records.map((r) => r.type).toSet(),
      {PrType.maxWeight, PrType.est1rm, PrType.maxSetVolume},
    );

    // A warm-up set never produces a record and never starts a rest.
    final warmup = await controller.completeSet(setId: benchSets[0].id);
    expect(warmup!.records, isEmpty);
    expect(warmup.restSeconds, 0);

    final benchWorking = await controller.completeSet(setId: benchSets[1].id);
    expect(benchWorking!.records, hasLength(4));
    // No explicit rest was set for this exercise, so it uses the default.
    expect(benchWorking.restSeconds, 90);

    // --- 4. Finish ----------------------------------------------------------
    await controller.finish(workoutId, discardPending: false, notes: 'Goed');

    final finished = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(finished!.isActive, isFalse);
    expect(finished.workout.notes, 'Goed');
    expect(await db.workoutsDao.getActiveWorkoutRow(), isNull);

    // Volume counts 100x5 + 110x5 + 80x8, and skips the 40x8 warm-up.
    expect(finished.workout.totalVolumeKg, 500 + 550 + 640);
    expect(finished.workout.totalSets, 4);

    // The routine remembers when it was last performed.
    final performed = await db.routinesDao.getRoutine(routineId);
    expect(performed!.lastPerformedAt, isNotNull);

    // --- 5. History ---------------------------------------------------------
    container.listen(workoutHistoryProvider(), (_, _) {});
    final history = await container.read(workoutHistoryProvider().future);
    expect(history, hasLength(1));
    expect(history.single.workout.id, workoutId);
    expect(history.single.exerciseCount, 2);
    expect(history.single.prCount, greaterThan(0));

    // --- 6. Records ---------------------------------------------------------
    final squatBests = await db.recordsDao.currentBests('ex-squat');
    expect(squatBests[PrType.maxWeight], 110);
    expect(squatBests[PrType.maxReps], 5);
    expect(squatBests[PrType.maxSetVolume], 550);
    expect(
      squatBests[PrType.est1rm],
      closeTo(110 * (1 + 5 / 30), 0.0001),
    );

    final benchBests = await db.recordsDao.currentBests('ex-bench');
    expect(benchBests[PrType.maxWeight], 80);
    expect(benchBests[PrType.maxSetVolume], 640);

    // --- 7. Aggregates ------------------------------------------------------
    container.listen(lifetimeStatsProvider, (_, _) {});
    final lifetime = await container.read(lifetimeStatsProvider.future);
    expect(lifetime.workouts, 1);
    expect(lifetime.sets, 4);
    expect(lifetime.volumeKg, 1690);

    container.listen(streakProvider, (_, _) {});
    container.listen(finishedWorkoutDatesProvider, (_, _) {});
    final streak = await container.read(streakProvider.future);
    expect(streak.weeks, 1);
    expect(streak.daysSinceLast, 0);
  });

  test('the previous column reads from the last finished session', () async {
    final controller = container.read(workoutControllerProvider);

    // First session.
    final first = await controller.startEmpty(name: 'Sessie 1');
    await controller.addExercises(first, ['ex-bench']);
    var detail = await db.workoutsDao.getWorkoutDetail(first);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 80,
      reps: 8,
    );
    await controller.finish(first, discardPending: false);

    // Second session with the same exercise.
    final second = await controller.startEmpty(name: 'Sessie 2');
    await controller.addExercises(second, ['ex-bench']);

    final previous = await db.workoutsDao.previousSetsFor(
      'ex-bench',
      excludingWorkoutId: second,
    );
    expect(previous, hasLength(1));
    expect(previous.single.weightKg, 80);
    expect(previous.single.reps, 8);
  });

  test('finishing with unfilled sets can discard them', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty();
    await controller.addExercises(workoutId, ['ex-bench']);

    var detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    final setId = detail!.exercises.single.sets.single.id;
    await controller.addSet(detail.exercises.single.workoutExercise.id);
    await controller.completeSet(setId: setId, weightKg: 60, reps: 10);

    detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(detail!.pendingSets, 1);

    await controller.finish(workoutId, discardPending: true);

    final finished = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(finished!.totalSets, 1);
    expect(finished.pendingSets, 0);
  });

  test('deleting a workout replays the records that are left', () async {
    final controller = container.read(workoutControllerProvider);

    // A heavy session, then a lighter one.
    final heavy = await controller.startEmpty(name: 'Zwaar');
    await controller.addExercises(heavy, ['ex-squat']);
    var detail = await db.workoutsDao.getWorkoutDetail(heavy);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 140,
      reps: 3,
    );
    await controller.finish(heavy, discardPending: false);

    final light = await controller.startEmpty(name: 'Licht');
    await controller.addExercises(light, ['ex-squat']);
    detail = await db.workoutsDao.getWorkoutDetail(light);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    await controller.finish(light, discardPending: false);

    expect((await db.recordsDao.currentBests('ex-squat'))[PrType.maxWeight], 140);

    await container.read(historyActionsProvider).deleteWorkout(heavy);

    final bests = await db.recordsDao.currentBests('ex-squat');
    expect(bests[PrType.maxWeight], 100);
    expect(bests[PrType.maxReps], 5);
  });

  test('a session survives being interrupted', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Onderbroken');
    await controller.addExercises(workoutId, ['ex-bench']);

    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    await controller.updateSetValues(
      detail!.exercises.single.sets.single.id,
      weightKg: const Value(75),
      reps: const Value(6),
    );

    // Simulate a cold start against the same file: the running session is
    // found by its open end timestamp.
    final resumed = await db.workoutsDao.getActiveWorkoutRow();
    expect(resumed, isNotNull);
    expect(resumed!.id, workoutId);

    final restored = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(restored!.exercises.single.sets.single.weightKg, 75);
    expect(restored.exercises.single.sets.single.reps, 6);
  });
}
