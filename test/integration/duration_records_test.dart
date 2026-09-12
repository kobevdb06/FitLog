import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/pr.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Time and distance counting for something.
///
/// Logging a plank was possible but led nowhere: no record, no line on a
/// chart, nothing to beat. A hold you keep ten seconds longer than ever
/// before is an achievement and should read as one.
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
      ('ex-bench', 'Bankdrukken', 'barbell'),
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

  /// One finished set of [exerciseId].
  Future<void> logSet(
    String exerciseId, {
    double? weightKg,
    int? reps,
    int? durationSeconds,
    double? distanceM,
  }) async {
    final id = await controller.startEmpty(name: 'Sessie');
    await controller.addExercises(id, [exerciseId]);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    await controller.completeSet(
      setId: set.id,
      weightKg: weightKg,
      reps: reps,
      durationSeconds: durationSeconds,
      distanceM: distanceM,
    );
    await controller.finish(id, discardPending: true);
  }

  group('the records a set can set', () {
    test('a hold sets a longest time', () {
      final candidates = prCandidatesForSet(
        setType: SetType.normal,
        isCompleted: true,
        durationSeconds: 60,
      );

      expect(candidates, [const PrCandidate(PrType.maxDuration, 60)]);
    });

    test('a run is judged on distance, not on how long it took', () {
      // Running the same distance slower is not a better run.
      final candidates = prCandidatesForSet(
        setType: SetType.normal,
        isCompleted: true,
        durationSeconds: 1800,
        distanceM: 5000,
      );

      expect(candidates, [const PrCandidate(PrType.maxDistance, 5000)]);
    });

    test('a weighted hold sets both', () {
      final candidates = prCandidatesForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 20,
        durationSeconds: 45,
      );

      expect(candidates, contains(const PrCandidate(PrType.maxWeight, 20)));
      expect(candidates, contains(const PrCandidate(PrType.maxDuration, 45)));
    });

    test('a warm-up sets nothing, as before', () {
      expect(
        prCandidatesForSet(
          setType: SetType.warmup,
          isCompleted: true,
          durationSeconds: 60,
        ),
        isEmpty,
      );
    });
  });

  group('over a few sessions', () {
    test('the longest hold is the one that stands', () async {
      await logSet('ex-plank', durationSeconds: 60);
      await logSet('ex-plank', durationSeconds: 45);
      await logSet('ex-plank', durationSeconds: 75);

      final best = await db.recordsDao.currentBests('ex-plank');
      expect(best[PrType.maxDuration], 75);
      expect(best[PrType.maxWeight], isNull, reason: 'een plank weegt niets');
    });

    test('the furthest run is the one that stands', () async {
      await logSet('ex-run', distanceM: 5000, durationSeconds: 1800);
      await logSet('ex-run', distanceM: 8000, durationSeconds: 3000);

      final best = await db.recordsDao.currentBests('ex-run');
      expect(best[PrType.maxDistance], 8000);
      expect(
        best[PrType.maxDuration],
        isNull,
        reason: 'afstand telt, niet tijd',
      );
    });

    test('it survives replaying the whole history', () async {
      await logSet('ex-plank', durationSeconds: 75);

      await db.recordsDao.rebuildAllRecords();

      final best = await db.recordsDao.currentBests('ex-plank');
      expect(best[PrType.maxDuration], 75);
    });

    test('lifting records are untouched by any of this', () async {
      await logSet('ex-bench', weightKg: 100, reps: 5);

      final best = await db.recordsDao.currentBests('ex-bench');
      expect(best[PrType.maxWeight], 100);
      expect(best[PrType.maxReps], 5);
      expect(best[PrType.maxDuration], isNull);
      expect(best[PrType.maxDistance], isNull);
    });

    test('checking a hold off reports the record there and then', () async {
      final id = await controller.startEmpty(name: 'Core');
      await controller.addExercises(id, ['ex-plank']);
      final set = (await db.workoutsDao.getWorkoutDetail(id))!
          .exercises
          .single
          .sets
          .single;

      final result = await controller.completeSet(
        setId: set.id,
        durationSeconds: 60,
      );

      expect(result!.hasRecord, isTrue);
      expect(result.records.single.type, PrType.maxDuration);
    });
  });

  group('the charts on offer', () {
    test('a hold gets a line for its time and nothing that is not there', () {
      expect(ExerciseMetric.forCategory(ExerciseCategory.duration), [
        ExerciseMetric.longestHold,
      ]);
    });

    test('cardio gets distance', () {
      expect(
        ExerciseMetric.forCategory(ExerciseCategory.cardio),
        contains(ExerciseMetric.furthest),
      );
    });

    test('anything you load keeps the four it had', () {
      expect(ExerciseMetric.forCategory(ExerciseCategory.barbell), [
        ExerciseMetric.oneRm,
        ExerciseMetric.volume,
        ExerciseMetric.bestSet,
        ExerciseMetric.totalReps,
      ]);
    });

    test('the line follows the longest hold per session', () async {
      await logSet('ex-plank', durationSeconds: 60);
      await logSet('ex-plank', durationSeconds: 75);

      final sessions = await db.workoutsDao.exerciseSessions('ex-plank');
      final points = buildExerciseSeries(
        sessions: sessions,
        metric: ExerciseMetric.longestHold,
        range: ChartRange.year,
      );

      expect(points.map((p) => p.value), [60, 75]);
    });
  });
}
