import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

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
    for (var i = 0; i < 5; i++) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex$i',
              name: 'Oefening $i',
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  test('deleting a 5 exercise, 20 set workout leaves no orphans', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Groot');
    await controller.addExercises(workoutId, [
      'ex0',
      'ex1',
      'ex2',
      'ex3',
      'ex4',
    ]);

    var detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    for (final exercise in detail!.exercises) {
      for (var i = 0; i < 3; i++) {
        await controller.addSet(exercise.workoutExercise.id);
      }
    }
    detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    for (final exercise in detail!.exercises) {
      for (final set in exercise.sets) {
        await controller.completeSet(setId: set.id, weightKg: 100, reps: 5);
      }
    }
    await controller.finish(workoutId, discardPending: false);

    expect(await count('workout_exercises'), 5);
    expect(await count('workout_sets'), 20);
    expect(await count('personal_records'), greaterThan(0));

    await container.read(historyActionsProvider).deleteWorkout(workoutId);

    expect(await count('workouts'), 0);
    expect(await count('workout_exercises'), 0);
    expect(await count('workout_sets'), 0);
    expect(await count('personal_records'), 0);

    // And nothing is left pointing at a set that no longer exists.
    final broken = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(broken, isEmpty);
  });

  test('a record set in the deleted workout falls back to the previous best',
      () async {
    final controller = container.read(workoutControllerProvider);

    final light = await controller.startEmpty(name: 'Licht');
    await controller.addExercises(light, ['ex0']);
    var detail = await db.workoutsDao.getWorkoutDetail(light);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    await controller.finish(light, discardPending: false);

    final heavy = await controller.startEmpty(name: 'Zwaar');
    await controller.addExercises(heavy, ['ex0']);
    detail = await db.workoutsDao.getWorkoutDetail(heavy);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 140,
      reps: 3,
    );
    await controller.finish(heavy, discardPending: false);

    expect((await db.recordsDao.currentBests('ex0'))[PrType.maxWeight], 140);

    await container.read(historyActionsProvider).deleteWorkout(heavy);

    final bests = await db.recordsDao.currentBests('ex0');
    expect(bests[PrType.maxWeight], 100);
    expect(bests[PrType.maxReps], 5);
    expect(bests[PrType.maxSetVolume], 500);
  });

  test('records of exercises that were not in the workout are untouched',
      () async {
    final controller = container.read(workoutControllerProvider);

    final other = await controller.startEmpty(name: 'Andere oefening');
    await controller.addExercises(other, ['ex1']);
    var detail = await db.workoutsDao.getWorkoutDetail(other);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 60,
      reps: 8,
    );
    await controller.finish(other, discardPending: false);

    final target = await controller.startEmpty(name: 'Weg hiermee');
    await controller.addExercises(target, ['ex0']);
    detail = await db.workoutsDao.getWorkoutDetail(target);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 90,
      reps: 5,
    );
    await controller.finish(target, discardPending: false);

    final before = await db.recordsDao.recordsForExercise('ex1');
    await container.read(historyActionsProvider).deleteWorkout(target);
    final after = await db.recordsDao.recordsForExercise('ex1');

    expect(after.map((r) => r.value), before.map((r) => r.value));
    expect(await db.recordsDao.recordsForExercise('ex0'), isEmpty);
  });

  test('the routine falls back to the session that is left', () async {
    final routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Push',
        exercises: [
          RoutineExerciseDraft(exerciseId: 'ex0', sets: [RoutineSetDraft()]),
        ],
      ),
    );
    final controller = container.read(workoutControllerProvider);

    final first = await controller.startFromRoutine(routineId);
    await controller.finish(first, discardPending: false);
    final firstStamp = (await db.routinesDao.getRoutine(
      routineId,
    ))!.lastPerformedAt;

    // Make sure the second session is unmistakably later.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await controller.startFromRoutine(routineId);
    await controller.finish(second, discardPending: false);
    expect(
      (await db.routinesDao.getRoutine(routineId))!.lastPerformedAt,
      greaterThan(firstStamp!),
    );

    await container.read(historyActionsProvider).deleteWorkout(second);

    expect(
      (await db.routinesDao.getRoutine(routineId))!.lastPerformedAt,
      firstStamp,
      reason: 'de stempel moet terugvallen op de sessie die overblijft',
    );
  });

  test('deleting the only session clears the routine stamp', () async {
    final routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Pull',
        exercises: [
          RoutineExerciseDraft(exerciseId: 'ex0', sets: [RoutineSetDraft()]),
        ],
      ),
    );
    final controller = container.read(workoutControllerProvider);
    final only = await controller.startFromRoutine(routineId);
    await controller.finish(only, discardPending: false);

    await container.read(historyActionsProvider).deleteWorkout(only);

    expect(
      (await db.routinesDao.getRoutine(routineId))!.lastPerformedAt,
      isNull,
    );
  });

  test('deleting the running workout leaves no active session', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Loopt nog');
    await controller.addExercises(workoutId, ['ex0']);

    await container
        .read(restTimerProvider.notifier)
        .start(seconds: 90, exerciseName: 'Oefening 0');
    container.read(appControllerProvider.notifier).workoutInProgress = true;

    await container.read(historyActionsProvider).deleteWorkout(workoutId);

    expect(await db.workoutsDao.getActiveWorkoutRow(), isNull);
    expect(
      container.read(restTimerProvider).isActive,
      isFalse,
      reason: 'de rusttimer mag niet doortikken voor een verdwenen sessie',
    );
    expect(
      container.read(appControllerProvider.notifier).workoutInProgress,
      isFalse,
    );

    // A new session can start right away.
    final next = await controller.startEmpty(name: 'Volgende');
    expect(next, isNotEmpty);
  });

  test('cancelling a workout cleans up just as thoroughly', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Weg');
    await controller.addExercises(workoutId, ['ex0', 'ex1']);

    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    await controller.completeSet(
      setId: detail!.exercises.first.sets.single.id,
      weightKg: 120,
      reps: 2,
    );

    await controller.cancel(workoutId);

    expect(await count('workouts'), 0);
    expect(await count('workout_exercises'), 0);
    expect(await count('workout_sets'), 0);
    expect(await count('personal_records'), 0);
    expect(container.read(restTimerProvider).isActive, isFalse);
  });

  test('deleting a workout that does not exist is a no-op', () async {
    await container.read(historyActionsProvider).deleteWorkout('bestaat-niet');
    expect(await count('workouts'), 0);
  });

  group('undo', () {
    test('nothing is deleted while the undo window is open', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty(name: 'Twijfel');
      await controller.finish(workoutId, discardPending: false);

      final pending = container.read(
        pendingWorkoutDeletionsProvider.notifier,
      );
      pending.schedule(workoutId);

      expect(container.read(pendingWorkoutDeletionsProvider), {workoutId});
      // Still on disk: undo restores nothing, it just cancels a timer.
      expect(await count('workouts'), 1);

      pending.undo(workoutId);
      expect(container.read(pendingWorkoutDeletionsProvider), isEmpty);
      expect(await count('workouts'), 1);
    });

    test('committing early deletes immediately', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty(name: 'Zeker');
      await controller.finish(workoutId, discardPending: false);

      final pending = container.read(
        pendingWorkoutDeletionsProvider.notifier,
      );
      pending.schedule(workoutId);
      await pending.commitNow(workoutId);

      expect(await count('workouts'), 0);
      expect(container.read(pendingWorkoutDeletionsProvider), isEmpty);
    });

    test('the timer really fires after the grace period', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty(name: 'Geduld');
      await controller.finish(workoutId, discardPending: false);

      container
          .read(pendingWorkoutDeletionsProvider.notifier)
          .schedule(workoutId);

      expect(await count('workouts'), 1);
      await Future<void>.delayed(
        PendingWorkoutDeletions.grace + const Duration(milliseconds: 300),
      );
      expect(await count('workouts'), 0);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
