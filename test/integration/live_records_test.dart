import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The records of the session you are in (DECISIONS 243).
///
/// Unticking or skipping any set replayed the whole history - but only the
/// finished workouts in it. Every record of the running session was gone,
/// and finishing did not bring them back. And taking away a set, an
/// exercise, or lowering a ticked-off weight did not touch the records at
/// all: 1000 kg typed by mistake and swiped away stayed the record for good.
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
    for (final (id, name) in [
      ('ex-bench', 'Bankdrukken'),
      ('ex-row', 'Roeien'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
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

  Future<List<WorkoutExerciseDetail>> exercises(String id) async =>
      (await db.workoutsDao.getWorkoutDetail(id))!.exercises;

  /// A running session: bench with [sets] sets, and a row with one.
  Future<String> start({int sets = 2}) async {
    final id = await controller.startEmpty(name: 'Push');
    await controller.addExercises(id, ['ex-bench', 'ex-row']);
    while ((await exercises(id)).first.sets.length < sets) {
      await controller.addSet((await exercises(id)).first.workoutExercise.id);
    }
    return id;
  }

  Future<double?> heaviest(String exerciseId) async =>
      (await db.recordsDao.currentBests(exerciseId))[PrType.maxWeight];

  test('unticking another set keeps the records of this session', () async {
    final id = await start();
    final bench = (await exercises(id)).first.sets;
    final row = (await exercises(id)).last.sets.single;
    await controller.completeSet(setId: bench[0].id, weightKg: 100, reps: 5);
    await controller.completeSet(setId: row.id, weightKg: 60, reps: 8);
    expect(await heaviest('ex-bench'), 100);

    await controller.uncompleteSet(row.id);

    expect(await heaviest('ex-bench'), 100);
  });

  test('skipping another set keeps them as well', () async {
    final id = await start();
    final bench = (await exercises(id)).first.sets;
    await controller.completeSet(setId: bench[0].id, weightKg: 100, reps: 5);

    await controller.skipSet(bench[1].id);

    expect(await heaviest('ex-bench'), 100);
  });

  test('and after finishing they are still there', () async {
    final id = await start();
    final bench = (await exercises(id)).first.sets;
    await controller.completeSet(setId: bench[0].id, weightKg: 100, reps: 5);
    await controller.uncompleteSet(bench[1].id);

    await controller.finish(id, discardPending: true);

    expect(await heaviest('ex-bench'), 100);
  });

  test('a set swiped away takes its record with it', () async {
    final id = await start();
    final bench = (await exercises(id)).first.sets;
    await controller.completeSet(setId: bench[0].id, weightKg: 100, reps: 5);
    await controller.completeSet(setId: bench[1].id, weightKg: 1000, reps: 5);
    expect(await heaviest('ex-bench'), 1000);

    await controller.deleteSet(bench[1].id);

    expect(await heaviest('ex-bench'), 100);
  });

  test('a ticked-off weight made lower lowers the record', () async {
    final id = await start();
    final bench = (await exercises(id)).first.sets;
    await controller.completeSet(setId: bench[0].id, weightKg: 1000, reps: 5);

    await controller.updateSetValues(bench[0].id, weightKg: const Value(100));

    expect(await heaviest('ex-bench'), 100);
  });

  test('a ticked-off set turned into a warm-up no longer holds one', () async {
    final id = await start();
    final bench = (await exercises(id)).first.sets;
    await controller.completeSet(setId: bench[0].id, weightKg: 100, reps: 5);
    await controller.completeSet(setId: bench[1].id, weightKg: 120, reps: 5);

    await controller.setSetType(bench[1].id, SetType.warmup);

    expect(await heaviest('ex-bench'), 100);
  });

  test(
    'an exercise taken out takes its records, and the totals follow',
    () async {
      final id = await start();
      final bench = (await exercises(id)).first;
      await controller.completeSet(
        setId: bench.sets[0].id,
        weightKg: 100,
        reps: 5,
      );

      await controller.removeExercise(bench.workoutExercise.id);

      expect(await heaviest('ex-bench'), isNull);
      final workout = (await db.workoutsDao.getWorkoutDetail(id))!.workout;
      expect(workout.totalSets, 0);
      expect(workout.totalVolumeKg, 0);
    },
  );

  test('an exercise replaced does the same for the old one', () async {
    final id = await start();
    final bench = (await exercises(id)).first;
    await controller.completeSet(
      setId: bench.sets[0].id,
      weightKg: 100,
      reps: 5,
    );

    await controller.replaceExercise(bench.workoutExercise.id, 'ex-row');

    expect(await heaviest('ex-bench'), isNull);
  });
}
