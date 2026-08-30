import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Doing a session again used to mean rebuilding it by hand: the history menu
/// only offered to delete it.
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
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A finished session with two exercises, one of them warmed up.
  Future<String> logSession() async {
    final id = await controller.startEmpty(name: 'Push A');
    await controller.addExercises(id, ['ex-squat', 'ex-bench']);

    final detail = (await db.workoutsDao.getWorkoutDetail(id))!;
    final squat = detail.exercises.first;
    await controller.setSetType(squat.sets.first.id, SetType.warmup);
    await controller.setExerciseRest(squat.workoutExercise.id, 150);
    await controller.setExerciseNote(squat.workoutExercise.id, 'diep zakken');

    for (final exercise in detail.exercises) {
      for (final set in exercise.sets) {
        await controller.completeSet(setId: set.id, weightKg: 100, reps: 5);
      }
    }
    await controller.finish(id, discardPending: true);
    return id;
  }

  test('the same exercises come back in the same order', () async {
    final source = await logSession();

    final repeated = await controller.repeat(source);

    final detail = (await db.workoutsDao.getWorkoutDetail(repeated))!;
    expect(
      detail.exercises.map((e) => e.exercise.id),
      ['ex-squat', 'ex-bench'],
    );
    expect(detail.workout.name, 'Push A');
    expect(detail.workout.endedAt, isNull, reason: 'it is the running one');
  });

  test('the set count and the set types come over', () async {
    final source = await logSession();
    final before = (await db.workoutsDao.getWorkoutDetail(source))!;

    final repeated = await controller.repeat(source);

    final after = (await db.workoutsDao.getWorkoutDetail(repeated))!;
    for (var i = 0; i < before.exercises.length; i++) {
      expect(
        after.exercises[i].sets.map((s) => s.setType),
        before.exercises[i].sets.map((s) => s.setType),
      );
    }
  });

  test('the rest and the note come over', () async {
    final source = await logSession();

    final repeated = await controller.repeat(source);

    final squat = (await db.workoutsDao.getWorkoutDetail(
      repeated,
    ))!.exercises.first;
    expect(squat.workoutExercise.restSeconds, 150);
    expect(squat.workoutExercise.notes, 'diep zakken');
  });

  test('nothing is filled in yet', () async {
    final source = await logSession();

    final repeated = await controller.repeat(source);

    final detail = (await db.workoutsDao.getWorkoutDetail(repeated))!;
    final sets = detail.exercises.expand((e) => e.sets);
    expect(sets.every((s) => s.weightKg == null), isTrue);
    expect(sets.every((s) => s.reps == null), isTrue);
    expect(sets.every((s) => !s.isCompleted), isTrue);
  });

  test('the old session is left alone', () async {
    final source = await logSession();

    await controller.repeat(source);

    final before = (await db.workoutsDao.getWorkoutDetail(source))!;
    expect(before.workout.endedAt, isNotNull);
    expect(
      before.exercises.expand((e) => e.sets).every((s) => s.isCompleted),
      isTrue,
    );
  });

  test('it refuses while a workout is running', () async {
    final source = await logSession();
    await controller.startEmpty(name: 'Bezig');

    expect(() => controller.repeat(source), throwsStateError);
  });

  test('a session that no longer exists is a clean failure', () async {
    expect(() => controller.repeat('weg'), throwsStateError);
  });

  test('an empty session repeats as an empty session', () async {
    final id = await controller.startEmpty(name: 'Leeg');
    await controller.finish(id, discardPending: true);

    final repeated = await controller.repeat(id);

    final detail = (await db.workoutsDao.getWorkoutDetail(repeated))!;
    expect(detail.exercises, isEmpty);
    expect(detail.workout.name, 'Leeg');
  });
}
