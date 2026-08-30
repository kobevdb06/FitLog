import 'package:fitlog/core/app/app_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Ticking off a set without typing anything used to store nothing, while the
/// cells showed last session's numbers in grey. The hint now does what it
/// looks like it does.
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
            id: 'ex-squat',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<WorkoutExerciseDetail> squatIn(String workoutId) async =>
      (await db.workoutsDao.getWorkoutDetail(workoutId))!.exercises.single;

  /// A finished session of three working sets at increasing weights.
  Future<void> lastWeek() async {
    final id = await controller.startEmpty(name: 'Vorige week');
    await controller.addExercises(id, ['ex-squat']);
    var squat = await squatIn(id);
    while (squat.sets.length < 3) {
      await controller.addSet(squat.workoutExercise.id);
      squat = await squatIn(id);
    }

    for (var i = 0; i < 3; i++) {
      await controller.completeSet(
        setId: squat.sets[i].id,
        weightKg: 100 + i * 10,
        reps: 8 - i,
      );
    }
    await controller.finish(id, discardPending: true);
  }

  /// A running session with [sets] empty sets of the same exercise.
  Future<WorkoutExerciseDetail> thisWeek({int sets = 3}) async {
    final id = await controller.startEmpty(name: 'Deze week');
    await controller.addExercises(id, ['ex-squat']);
    var squat = await squatIn(id);
    while (squat.sets.length < sets) {
      await controller.addSet(squat.workoutExercise.id);
      squat = await squatIn(id);
    }
    return squat;
  }

  test('an empty set takes what the row was showing', () async {
    await lastWeek();
    final squat = await thisWeek();

    await controller.completeSet(setId: squat.sets.first.id);

    final stored = (await squatIn(
      squat.workoutExercise.workoutId,
    )).sets.first;
    expect(stored.weightKg, 100);
    expect(stored.reps, 8);
    expect(stored.isCompleted, isTrue);
  });

  test('each set looks at the set in its own place', () async {
    await lastWeek();
    final squat = await thisWeek();

    for (final set in squat.sets) {
      await controller.completeSet(setId: set.id);
    }

    final stored = (await squatIn(squat.workoutExercise.workoutId)).sets;
    expect(stored.map((s) => s.weightKg), [100, 110, 120]);
    expect(stored.map((s) => s.reps), [8, 7, 6]);
  });

  test('what you type wins over what was there', () async {
    await lastWeek();
    final squat = await thisWeek();

    await controller.completeSet(
      setId: squat.sets.first.id,
      weightKg: 125,
      reps: 3,
    );

    final stored = (await squatIn(
      squat.workoutExercise.workoutId,
    )).sets.first;
    expect(stored.weightKg, 125);
    expect(stored.reps, 3);
  });

  test('one typed field does not clear the other', () async {
    await lastWeek();
    final squat = await thisWeek();

    await controller.completeSet(setId: squat.sets.first.id, weightKg: 125);

    final stored = (await squatIn(
      squat.workoutExercise.workoutId,
    )).sets.first;
    expect(stored.weightKg, 125);
    expect(stored.reps, 8, reason: 'the reps still come from last time');
  });

  test('a set beyond last time is left empty', () async {
    await lastWeek();
    final squat = await thisWeek(sets: 4);

    await controller.completeSet(setId: squat.sets.last.id);

    final stored = (await squatIn(squat.workoutExercise.workoutId)).sets.last;
    expect(stored.weightKg, isNull);
    expect(stored.reps, isNull);
    expect(stored.isCompleted, isTrue);
  });

  test('a warm-up takes nothing, because it matches nothing', () async {
    await lastWeek();
    final squat = await thisWeek();
    await controller.setSetType(squat.sets.first.id, SetType.warmup);

    await controller.completeSet(setId: squat.sets.first.id);

    final stored = (await squatIn(
      squat.workoutExercise.workoutId,
    )).sets.first;
    expect(stored.weightKg, isNull);
    expect(stored.reps, isNull);
  });

  test('a warm-up shifts the working sets, and they follow', () async {
    await lastWeek();
    final squat = await thisWeek(sets: 4);
    await controller.setSetType(squat.sets.first.id, SetType.warmup);

    for (final set in squat.sets) {
      await controller.completeSet(setId: set.id);
    }

    final stored = (await squatIn(squat.workoutExercise.workoutId)).sets;
    expect(stored.first.weightKg, isNull, reason: 'the warm-up');
    expect(stored.skip(1).map((s) => s.weightKg), [100, 110, 120]);
  });

  test('the first time the exercise is done, nothing is filled in', () async {
    final squat = await thisWeek();

    await controller.completeSet(setId: squat.sets.first.id);

    final stored = (await squatIn(
      squat.workoutExercise.workoutId,
    )).sets.first;
    expect(stored.weightKg, isNull);
    expect(stored.reps, isNull);
  });

  test('a planned weight still wins over last time', () async {
    await lastWeek();
    final squat = await thisWeek();
    await controller.updateSetValues(
      squat.sets.first.id,
      weightKg: const Value(140),
    );

    await controller.completeSet(setId: squat.sets.first.id);

    final stored = (await squatIn(
      squat.workoutExercise.workoutId,
    )).sets.first;
    expect(stored.weightKg, 140);
    expect(stored.reps, 8);
  });
}
