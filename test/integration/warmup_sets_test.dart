import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The rules that have to hold everywhere, not just in the SET column:
/// warm-ups stay out of the volume, out of the records, out of the VORIGE
/// column and out of the charts.
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
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex',
            name: 'Barbell Bench Press',
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

  test('volume is the same with or without warm-ups in front', () async {
    final controller = container.read(workoutControllerProvider);

    final plain = await controller.startEmpty(name: 'Zonder');
    await controller.addExercises(plain, ['ex']);
    var detail = await db.workoutsDao.getWorkoutDetail(plain);
    await controller.completeSet(
      setId: detail!.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    await controller.finish(plain, discardPending: false);
    final plainVolume = (await db.workoutsDao.getWorkoutDetail(
      plain,
    ))!.workout.totalVolumeKg;
    expect(plainVolume, 500);

    final warmed = await controller.startEmpty(name: 'Met warming-up');
    await controller.addExercises(warmed, ['ex']);
    detail = await db.workoutsDao.getWorkoutDetail(warmed);
    final exerciseId = detail!.exercises.single.workoutExercise.id;

    // Two heavy-ish warm-ups plus the same working set.
    for (final weight in [40.0, 70.0]) {
      final id = await controller.addSet(exerciseId, setType: SetType.warmup);
      await controller.completeSet(setId: id, weightKg: weight, reps: 8);
    }
    await controller.completeSet(
      setId: detail.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    await controller.finish(warmed, discardPending: false);

    final warmedWorkout = (await db.workoutsDao.getWorkoutDetail(
      warmed,
    ))!.workout;
    expect(warmedWorkout.totalVolumeKg, plainVolume);
    // The warm-ups are stored and counted as completed sets, just not volume.
    expect(warmedWorkout.totalSets, 3);
  });

  test('a heavy warm-up never triggers a personal record', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty();
    await controller.addExercises(workoutId, ['ex']);
    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    final exerciseId = detail!.exercises.single.workoutExercise.id;

    // Deliberately absurd: a warm-up heavier than any working set.
    final warmupId = await controller.addSet(
      exerciseId,
      setType: SetType.warmup,
    );
    final result = await controller.completeSet(
      setId: warmupId,
      weightKg: 200,
      reps: 10,
    );

    expect(result!.records, isEmpty);
    expect(await db.recordsDao.recordsForExercise('ex'), isEmpty);
    // And it does not start a rest either.
    expect(result.restSeconds, 0);

    // The working set behind it does set the records.
    final working = await controller.completeSet(
      setId: detail.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    expect(working!.records, hasLength(4));

    final bests = await db.recordsDao.currentBests('ex');
    expect(bests[PrType.maxWeight], 100);
    expect(bests[PrType.maxReps], 5);
  });

  test('a warm-up in a finished session is not offered as VORIGE', () async {
    final controller = container.read(workoutControllerProvider);

    final first = await controller.startEmpty(name: 'Vorige week');
    await controller.addExercises(first, ['ex']);
    var detail = await db.workoutsDao.getWorkoutDetail(first);
    final exerciseId = detail!.exercises.single.workoutExercise.id;

    final warmupId = await controller.addSet(
      exerciseId,
      setType: SetType.warmup,
    );
    await controller.completeSet(setId: warmupId, weightKg: 40, reps: 10);
    await controller.completeSet(
      setId: detail.exercises.single.sets.single.id,
      weightKg: 90,
      reps: 6,
    );
    await controller.finish(first, discardPending: false);

    final second = await controller.startEmpty(name: 'Deze week');
    await controller.addExercises(second, ['ex']);

    final previous = await db.workoutsDao.previousSetsFor(
      'ex',
      excludingWorkoutId: second,
    );

    expect(previous, hasLength(1));
    expect(
      previous.single.weightKg,
      90,
      reason: 'working set 1 hoort tegenover working set 1 te staan',
    );
    expect(
      previous.map((s) => s.setType),
      isNot(contains(SetType.warmup.wire)),
    );
  });

  test('charts and stats skip warm-ups', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty();
    await controller.addExercises(workoutId, ['ex']);
    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    final exerciseId = detail!.exercises.single.workoutExercise.id;

    final warmupId = await controller.addSet(
      exerciseId,
      setType: SetType.warmup,
    );
    await controller.completeSet(setId: warmupId, weightKg: 200, reps: 1);
    await controller.completeSet(
      setId: detail.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    await controller.finish(workoutId, discardPending: false);

    final sessions = await db.workoutsDao.exerciseSessions('ex');
    final best = buildExerciseSeries(
      sessions: sessions,
      metric: ExerciseMetric.bestSet,
      range: ChartRange.all,
    );

    expect(best, hasLength(1));
    expect(
      best.single.value,
      100,
      reason: 'de 200 kg warming-up mag de grafiek niet optillen',
    );

    final volume = buildExerciseSeries(
      sessions: sessions,
      metric: ExerciseMetric.volume,
      range: ChartRange.all,
    );
    expect(volume.single.value, 500);
  });

  group('default warm-up sets', () {
    test('a new exercise starts plain when the setting is zero', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty();
      await controller.addExercises(workoutId, ['ex']);

      final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
      final sets = detail!.exercises.single.sets;
      expect(sets, hasLength(1));
      expect(sets.single.setType, SetType.normal.wire);
    });

    test('the setting puts warm-ups on top of a new exercise', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(defaultWarmupSets: Value(3)),
      );

      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty();
      await controller.addExercises(workoutId, ['ex']);

      final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
      final sets = detail!.exercises.single.sets;

      expect(sets, hasLength(4));
      expect(
        sets.map((s) => s.setType),
        [
          SetType.warmup.wire,
          SetType.warmup.wire,
          SetType.warmup.wire,
          SetType.normal.wire,
        ],
      );
      // The warm-ups come first, so the working set is at the bottom.
      expect(sets.last.sortOrder, 3);
    });

    test('the setting is capped at five', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(defaultWarmupSets: Value(99)),
      );

      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty();
      await controller.addExercises(workoutId, ['ex']);

      final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
      expect(detail!.exercises.single.sets, hasLength(6));
    });
  });

  test('switching a set to warm-up removes it from the volume', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty();
    await controller.addExercises(workoutId, ['ex']);
    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    final setId = detail!.exercises.single.sets.single.id;

    await controller.completeSet(setId: setId, weightKg: 100, reps: 5);
    expect(
      (await db.workoutsDao.getWorkoutDetail(workoutId))!.workout
          .totalVolumeKg,
      500,
    );

    await controller.setSetType(setId, SetType.warmup);

    expect(
      (await db.workoutsDao.getWorkoutDetail(workoutId))!.workout
          .totalVolumeKg,
      0,
      reason: 'een set omzetten naar warming-up haalt hem uit het volume',
    );
  });
}
