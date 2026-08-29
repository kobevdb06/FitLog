import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/features/workout/domain/pr_ramp.dart';
import 'package:fitlog/features/workout/presentation/pr_attempt_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The ladder maths is covered in test/calc/pr_ramp_test.dart; this is about
/// what a PR attempt does to the session and the records.
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
            id: 'squat',
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

  PrAttemptConfig config({
    double targetKg = 120,
    int warmupSets = 4,
    int extraAttempts = 1,
  }) => PrAttemptConfig(
    targetKg: targetKg,
    warmupSets: warmupSets,
    extraAttempts: extraAttempts,
    barKg: 20,
    platesKg: const [25, 20, 15, 10, 5, 2.5, 1.25],
  );

  test('starting an attempt fills a session with the ladder', () async {
    final workoutExerciseId = await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    final active = await db.workoutsDao.getActiveWorkoutRow();
    expect(active, isNotNull, reason: 'er hoort een sessie te lopen');

    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    final exercise = detail!.exercises.single;

    expect(exercise.workoutExercise.id, workoutExerciseId);
    expect(exercise.workoutExercise.isPrAttempt, isTrue);
    expect(exercise.workoutExercise.prTargetWeightKg, 120);
    expect(exercise.workoutExercise.prResult, isNull);

    expect(exercise.sets, hasLength(5));
    // 40% of 120 is 48 and 57% is 68.6; neither fits, so both round onto
    // the nearest loadable weight.
    expect(
      exercise.sets.map((s) => s.weightKg),
      [47.5, 67.5, 87.5, 107.5, 120.0],
    );
    expect(exercise.sets.map((s) => s.reps), [5, 3, 2, 1, 1]);
  });

  test('only the attempt is a working set', () async {
    await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    final sets = detail!.exercises.single.sets;

    expect(
      sets.take(4).map((s) => s.setType),
      everyElement(SetType.warmup.wire),
    );
    expect(sets.last.setType, SetType.normal.wire);
  });

  test('warm-ups in a ladder do rest, and the rests grow', () async {
    await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    final controller = container.read(workoutControllerProvider);
    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    final sets = detail!.exercises.single.sets;

    final rests = <int>[];
    for (final set in sets) {
      final result = await controller.completeSet(setId: set.id);
      rests.add(result!.restSeconds);
    }

    // Unlike an ordinary warm-up, a ladder rung rests, and longer each time.
    expect(rests, [90, 120, 180, 240, 300]);
  });

  test('a warm-up rung never sets a record, the attempt does', () async {
    await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    final controller = container.read(workoutControllerProvider);
    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    final sets = detail!.exercises.single.sets;

    for (final warmup in sets.take(4)) {
      final result = await controller.completeSet(setId: warmup.id);
      expect(result!.records, isEmpty);
      expect(result.isPrAttemptSet, isFalse);
    }
    expect(await db.recordsDao.recordsForExercise('squat'), isEmpty);

    final attempt = await controller.completeSet(setId: sets.last.id);
    expect(attempt!.isPrAttemptSet, isTrue);
    expect(attempt.records, isNotEmpty);

    final bests = await db.recordsDao.currentBests('squat');
    expect(bests[PrType.maxWeight], 120);
    expect(bests[PrType.est1rm], 120);
  });

  test('the outcome is recorded on the exercise', () async {
    final id = await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    await container
        .read(prAttemptActionsProvider)
        .finish(id, PrAttemptResult.failed);

    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    expect(
      detail!.exercises.single.workoutExercise.prResult,
      PrAttemptResult.failed.wire,
    );

    // A failed attempt stays in the history rather than being swept away.
    expect(detail.exercises.single.workoutExercise.isPrAttempt, isTrue);
  });

  test('a follow-up attempt goes up by one plate step', () async {
    final id = await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    await container
        .read(prAttemptActionsProvider)
        .addFollowUpAttempt(
          workoutExerciseId: id,
          achievedKg: 120,
          platesKg: const [25, 20, 15, 10, 5, 2.5, 1.25],
          barKg: 20,
        );

    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    final exercise = detail!.exercises.single;

    expect(exercise.sets, hasLength(6));
    expect(exercise.sets.last.weightKg, 122.5);
    expect(exercise.sets.last.reps, 1);
    expect(exercise.workoutExercise.prTargetWeightKg, 122.5);
    expect(exercise.workoutExercise.prResult, isNull);
  });

  test('a back-off single lands at 95% on the bar', () async {
    final id = await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    await container
        .read(prAttemptActionsProvider)
        .addBackoffSingle(
          workoutExerciseId: id,
          previousBestKg: 120,
          platesKg: const [25, 20, 15, 10, 5, 2.5, 1.25],
          barKg: 20,
        );

    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    expect(detail!.exercises.single.sets.last.weightKg, 115);
  });

  test('reverting leaves an ordinary exercise with its sets', () async {
    final id = await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    await container.read(prAttemptActionsProvider).revertToNormalExercise(id);

    final active = await db.workoutsDao.getActiveWorkoutRow();
    final detail = await db.workoutsDao.getWorkoutDetail(active!.id);
    final exercise = detail!.exercises.single;

    expect(exercise.workoutExercise.isPrAttempt, isFalse);
    expect(exercise.workoutExercise.prTargetWeightKg, isNull);
    expect(exercise.sets, hasLength(5));
  });

  test('an unloadable target is refused instead of half-applied', () async {
    await expectLater(
      container
          .read(prAttemptActionsProvider)
          .start(exerciseId: 'squat', config: config(targetKg: 10)),
      throwsArgumentError,
    );

    expect(await db.workoutsDao.getActiveWorkoutRow(), isNull);
  });

  test('an attempt joins a session that is already running', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Beendag');
    await controller.addExercises(workoutId, ['squat']);

    await container
        .read(prAttemptActionsProvider)
        .start(exerciseId: 'squat', config: config());

    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(detail!.workout.name, 'Beendag');
    expect(
      detail.exercises,
      hasLength(2),
      reason: 'de poging komt naast de bestaande oefening te staan',
    );
    expect(detail.exercises.last.workoutExercise.isPrAttempt, isTrue);
  });

  group('baseline', () {
    test('is empty for an exercise that was never logged', () async {
      final baseline = await container.read(
        prBaselineProvider('squat').future,
      );
      expect(baseline.hasEstimate, isFalse);
      expect(baseline.trainedRecently, isFalse);
    });

    test('reads the estimate from the best working set', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty();
      await controller.addExercises(workoutId, ['squat']);
      final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
      await controller.completeSet(
        setId: detail!.exercises.single.sets.single.id,
        weightKg: 100,
        reps: 4,
      );
      await controller.finish(workoutId, discardPending: false);

      final baseline = await container.read(
        prBaselineProvider('squat').future,
      );

      // Epley: 100 * (1 + 4/30) = 113.33
      expect(baseline.estimatedOneRmKg, closeTo(113.333, 0.01));
      expect(baseline.sourceWeightKg, 100);
      expect(baseline.sourceReps, 4);
      expect(baseline.sourceDate, isNotNull);
      expect(
        baseline.trainedRecently,
        isTrue,
        reason: 'die sessie was net, dus vermoeidheid telt',
      );
    });

    test('the prefilled target sits one step above the estimate', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty();
      await controller.addExercises(workoutId, ['squat']);
      final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
      await controller.completeSet(
        setId: detail!.exercises.single.sets.single.id,
        weightKg: 100,
        reps: 1,
      );
      await controller.finish(workoutId, discardPending: false);

      final baseline = await container.read(
        prBaselineProvider('squat').future,
      );
      final initial = initialPrConfig(
        baseline: baseline,
        settings: await db.settingsDao.getSettings(),
        setup: container.read(barbellSetupProvider),
      );

      expect(baseline.estimatedOneRmKg, 100);
      expect(initial.targetKg, 102.5);
      expect(initial.warmupSets, kDefaultPrWarmupSets);
      expect(initial.extraAttempts, 1);
      expect(initial.ramp, isNotNull);
    });

    test('a warm-up never becomes the estimate', () async {
      final controller = container.read(workoutControllerProvider);
      final workoutId = await controller.startEmpty();
      await controller.addExercises(workoutId, ['squat']);
      final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
      final exerciseId = detail!.exercises.single.workoutExercise.id;

      final warmup = await controller.addSet(
        exerciseId,
        setType: SetType.warmup,
      );
      await controller.completeSet(setId: warmup, weightKg: 200, reps: 5);
      await controller.completeSet(
        setId: detail.exercises.single.sets.single.id,
        weightKg: 100,
        reps: 1,
      );
      await controller.finish(workoutId, discardPending: false);

      final baseline = await container.read(
        prBaselineProvider('squat').future,
      );
      expect(baseline.estimatedOneRmKg, 100);
      expect(baseline.sourceWeightKg, 100);
    });
  });
}
