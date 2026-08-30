import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Four sets of the same weight meant typing the same numbers four times.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late WorkoutController controller;
  late String workoutId;

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
            id: 'ex-squat',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );

    workoutId = await controller.startEmpty(name: 'Benen');
    await controller.addExercises(workoutId, ['ex-squat']);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<WorkoutExerciseDetail> squat() async =>
      (await db.workoutsDao.getWorkoutDetail(workoutId))!.exercises.single;

  Future<WorkoutExerciseDetail> withSets(int count) async {
    var detail = await squat();
    while (detail.sets.length < count) {
      await controller.addSet(detail.workoutExercise.id);
      detail = await squat();
    }
    return detail;
  }

  test('the sets after the last one you did take its numbers', () async {
    final detail = await withSets(4);
    await controller.completeSet(
      setId: detail.sets.first.id,
      weightKg: 80,
      reps: 8,
    );

    final filled = await controller.fillRemainingSets(
      detail.workoutExercise.id,
    );

    expect(filled, 3);
    final sets = (await squat()).sets;
    expect(sets.map((s) => s.weightKg), [80, 80, 80, 80]);
    expect(sets.map((s) => s.reps), [8, 8, 8, 8]);
  });

  test('they are filled in, not ticked off', () async {
    final detail = await withSets(3);
    await controller.completeSet(
      setId: detail.sets.first.id,
      weightKg: 80,
      reps: 8,
    );

    await controller.fillRemainingSets(detail.workoutExercise.id);

    final sets = (await squat()).sets;
    expect(sets.first.isCompleted, isTrue);
    expect(sets.skip(1).every((s) => !s.isCompleted), isTrue);
  });

  test('the most recent set is the one that counts', () async {
    final detail = await withSets(4);
    await controller.completeSet(
      setId: detail.sets[0].id,
      weightKg: 80,
      reps: 8,
    );
    await controller.completeSet(
      setId: detail.sets[1].id,
      weightKg: 90,
      reps: 6,
    );

    await controller.fillRemainingSets(detail.workoutExercise.id);

    final sets = (await squat()).sets;
    expect(sets.map((s) => s.weightKg), [80, 90, 90, 90]);
  });

  test('a set you already did is left alone', () async {
    final detail = await withSets(3);
    await controller.completeSet(
      setId: detail.sets[0].id,
      weightKg: 80,
      reps: 8,
    );
    await controller.completeSet(
      setId: detail.sets[2].id,
      weightKg: 60,
      reps: 12,
    );

    await controller.fillRemainingSets(detail.workoutExercise.id);

    final sets = (await squat()).sets;
    expect(sets[2].weightKg, 60, reason: 'it was already logged');
  });

  test('warm-ups are neither the source nor a target', () async {
    final detail = await withSets(3);
    await controller.setSetType(detail.sets[1].id, SetType.warmup);
    await controller.completeSet(
      setId: detail.sets[0].id,
      weightKg: 80,
      reps: 8,
    );

    final filled = await controller.fillRemainingSets(
      detail.workoutExercise.id,
    );

    expect(filled, 1);
    final sets = (await squat()).sets;
    expect(sets[1].weightKg, isNull, reason: 'the warm-up');
    expect(sets[2].weightKg, 80);
  });

  test('nothing to copy yet is nothing filled', () async {
    final detail = await withSets(3);

    expect(await controller.fillRemainingSets(detail.workoutExercise.id), 0);
    expect((await squat()).sets.every((s) => s.weightKg == null), isTrue);
  });

  test('the last set has nothing after it', () async {
    final detail = await withSets(2);
    await controller.completeSet(
      setId: detail.sets.last.id,
      weightKg: 80,
      reps: 8,
    );

    expect(await controller.fillRemainingSets(detail.workoutExercise.id), 0);
  });

  test('an exercise that is not there fills nothing', () async {
    expect(await controller.fillRemainingSets('bestaat-niet'), 0);
  });
}
