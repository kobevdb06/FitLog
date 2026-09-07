import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Targets in a routine, for exercises that are not weight times reps.
///
/// A routine may only aim at what the session will actually ask you for: a
/// time for a hold, a distance and a time for a run.
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

    for (final (id, name, category) in const [
      ('ex-plank', 'Plank', 'duration'),
      ('ex-run', 'Hardlopen', 'cardio'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: 'buik',
              category: category,
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a routine can aim at a time, and the session starts on it', () async {
    final routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Core',
        exercises: [
          RoutineExerciseDraft(
            exerciseId: 'ex-plank',
            sets: [
              RoutineSetDraft(targetDurationSeconds: 60),
              RoutineSetDraft(targetDurationSeconds: 45),
            ],
          ),
        ],
      ),
    );

    final workoutId = await controller.startFromRoutine(routineId);
    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);

    expect(detail!.exercises.single.sets.map((s) => s.durationSeconds), [
      60,
      45,
    ]);
  });

  test('and at a distance, for something you measure out', () async {
    final routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Cardio',
        exercises: [
          RoutineExerciseDraft(
            exerciseId: 'ex-run',
            sets: [
              RoutineSetDraft(
                targetDistanceM: 5000,
                targetDurationSeconds: 1800,
              ),
            ],
          ),
        ],
      ),
    );

    final workoutId = await controller.startFromRoutine(routineId);
    final set = (await db.workoutsDao.getWorkoutDetail(workoutId))!
        .exercises
        .single
        .sets
        .single;

    expect(set.distanceM, 5000);
    expect(set.durationSeconds, 1800);
  });

  test('a target survives editing the routine', () async {
    final routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Cardio',
        exercises: [
          RoutineExerciseDraft(
            exerciseId: 'ex-run',
            sets: [
              RoutineSetDraft(
                targetDistanceM: 5000,
                targetDurationSeconds: 1800,
              ),
            ],
          ),
        ],
      ),
    );

    // Read it back the way the editor does, and write it out again unchanged.
    final loaded = await db.routinesDao.getRoutineDetail(routineId);
    await db.routinesDao.updateRoutine(
      routineId,
      RoutineDraft(
        name: loaded!.routine.name,
        exercises: [
          for (final e in loaded.exercises)
            RoutineExerciseDraft(
              exerciseId: e.exercise.id,
              sets: [
                for (final s in e.sets)
                  RoutineSetDraft(
                    targetReps: s.targetReps,
                    targetWeightKg: s.targetWeightKg,
                    targetDurationSeconds: s.targetDurationSeconds,
                    targetDistanceM: s.targetDistanceM,
                  ),
              ],
            ),
        ],
      ),
    );

    final again = await db.routinesDao.getRoutineDetail(routineId);
    expect(again!.exercises.single.sets.single.targetDistanceM, 5000);
  });

  test('saving a finished session as a routine keeps its distance', () async {
    final workoutId = await controller.startEmpty(name: 'Cardio');
    await controller.addExercises(workoutId, ['ex-run']);
    final set = (await db.workoutsDao.getWorkoutDetail(workoutId))!
        .exercises
        .single
        .sets
        .single;
    await controller.completeSet(
      setId: set.id,
      durationSeconds: 1800,
      distanceM: 5000,
    );
    await controller.finish(workoutId, discardPending: true);

    final routineId = await controller.saveAsRoutine(workoutId, 'Vaste ronde');

    final detail = await db.routinesDao.getRoutineDetail(routineId);
    expect(detail!.exercises.single.sets.single.targetDistanceM, 5000);
    expect(detail.exercises.single.sets.single.targetDurationSeconds, 1800);
  });
}
