import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/set_numbering.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Doing an exercise one arm at a time.
///
/// A left set and a right set are two separate sets with their own weight and
/// reps, because the two sides rarely match. They also keep their own history:
/// what you lifted with one hand says nothing about what you lifted with two,
/// so the previous column and the records keep them apart.
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
            id: 'ex-curl',
            name: 'Kabel curl',
            primaryMuscle: 'biceps',
            category: 'cable',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<WorkoutExerciseDetail> curl(String workoutId) async =>
      (await db.workoutsDao.getWorkoutDetail(workoutId))!.exercises.single;

  /// A running session with [sets] working sets of the curl.
  Future<String> start({int sets = 3}) async {
    final id = await controller.startEmpty(name: 'Armen');
    await controller.addExercises(id, ['ex-curl']);
    while ((await curl(id)).sets.length < sets) {
      await controller.addSet((await curl(id)).workoutExercise.id);
    }
    return id;
  }

  group('switching over', () {
    test('every working set becomes a left and a right', () async {
      final id = await start(sets: 3);

      await controller.setUnilateral(
        (await curl(id)).workoutExercise.id,
        unilateral: true,
      );

      final sets = (await curl(id)).sets;
      expect(sets, hasLength(6));
      expect(sets.map((s) => s.side), [
        'left',
        'right',
        'left',
        'right',
        'left',
        'right',
      ]);
      expect((await curl(id)).workoutExercise.isUnilateral, isTrue);
    });

    test('and back again', () async {
      final id = await start(sets: 3);
      final weId = (await curl(id)).workoutExercise.id;

      await controller.setUnilateral(weId, unilateral: true);
      await controller.setUnilateral(weId, unilateral: false);

      final sets = (await curl(id)).sets;
      expect(sets, hasLength(3));
      expect(sets.every((s) => s.side == null), isTrue);
      expect((await curl(id)).workoutExercise.isUnilateral, isFalse);
    });

    test('a warm-up stays one set', () async {
      final id = await start(sets: 3);
      final detail = await curl(id);
      await controller.setSetType(detail.sets.first.id, SetType.warmup);

      await controller.setUnilateral(
        detail.workoutExercise.id,
        unilateral: true,
      );

      final sets = (await curl(id)).sets;
      expect(sets, hasLength(5), reason: '1 warming-up + 2 werksets maal twee');
      expect(sets.first.side, isNull);
    });

    test('what you already logged is left alone', () async {
      final id = await start(sets: 3);
      final detail = await curl(id);
      await controller.completeSet(
        setId: detail.sets.first.id,
        weightKg: 30,
        reps: 10,
      );

      await controller.setUnilateral(
        detail.workoutExercise.id,
        unilateral: true,
      );

      final sets = (await curl(id)).sets;
      expect(sets.first.isCompleted, isTrue);
      expect(sets.first.weightKg, 30);
      expect(sets.first.side, isNull, reason: 'die set was met twee handen');
      expect(sets.skip(1).map((s) => s.side), ['left', 'right', 'left', 'right']);
    });

    test('the new sets start empty', () async {
      final id = await start(sets: 2);
      final detail = await curl(id);
      await controller.updateSetValues(
        detail.sets.first.id,
        weightKg: const Value(30),
      );

      await controller.setUnilateral(
        detail.workoutExercise.id,
        unilateral: true,
      );

      // 30 kg with two hands says nothing about one; the previous column
      // fills it in from the right history instead.
      expect((await curl(id)).sets.every((s) => s.weightKg == null), isTrue);
    });
  });

  group('the numbering', () {
    test('each side counts for itself', () {
      final labels = labelSetsWithSides(const [
        (SetType.warmup, null),
        (SetType.normal, SetSide.left),
        (SetType.normal, SetSide.right),
        (SetType.normal, SetSide.left),
        (SetType.normal, SetSide.right),
      ]);

      expect(labels.map((l) => l.text), ['W', '1L', '1R', '2L', '2R']);
      expect(labels.map((l) => l.workingIndex), [null, 0, 0, 1, 1]);
    });

    test('without sides nothing changes', () {
      expect(
        labelSets(const [SetType.warmup, SetType.normal, SetType.failure])
            .map((l) => l.text),
        ['W', '1', 'F'],
      );
    });
  });

  group('the two histories stay apart', () {
    /// A finished session, one-sided or not, with the given weights.
    Future<void> session({
      required bool unilateral,
      required List<double> weights,
    }) async {
      final id = await controller.startEmpty(name: 'Armen');
      await controller.addExercises(id, ['ex-curl']);
      final weId = (await curl(id)).workoutExercise.id;

      while ((await curl(id)).sets.length < (unilateral ? 1 : weights.length)) {
        await controller.addSet(weId);
      }
      if (unilateral) {
        await controller.setUnilateral(weId, unilateral: true);
        while ((await curl(id)).sets.length < weights.length) {
          await controller.addSet(weId);
        }
      }

      final sets = (await curl(id)).sets;
      for (var i = 0; i < weights.length && i < sets.length; i++) {
        await controller.completeSet(
          setId: sets[i].id,
          weightKg: weights[i],
          reps: 10,
        );
      }
      await controller.finish(id, discardPending: true);
    }

    test('two hands looks at the last two-handed session', () async {
      await session(unilateral: false, weights: [30, 32]);
      await session(unilateral: true, weights: [15, 14]);

      final previous = await db.workoutsDao.previousSetsFor('ex-curl');
      expect(previous.map((s) => s.weightKg), [30, 32]);
    });

    test('and one hand at the last one-handed session', () async {
      await session(unilateral: false, weights: [30, 32]);
      await session(unilateral: true, weights: [15, 14]);

      final left = await db.workoutsDao.previousSetsFor(
        'ex-curl',
        side: SetSide.left,
      );
      final right = await db.workoutsDao.previousSetsFor(
        'ex-curl',
        side: SetSide.right,
      );
      expect(left.map((s) => s.weightKg), [15]);
      expect(right.map((s) => s.weightKg), [14]);
    });

    test('with no one-handed session behind you, there is nothing to show',
        () async {
      await session(unilateral: false, weights: [30, 32]);

      expect(
        await db.workoutsDao.previousSetsFor('ex-curl', side: SetSide.left),
        isEmpty,
      );
    });

    test('an empty set takes the numbers of its own side', () async {
      await session(unilateral: true, weights: [15, 12]);

      final id = await start(sets: 1);
      final weId = (await curl(id)).workoutExercise.id;
      await controller.setUnilateral(weId, unilateral: true);

      final sets = (await curl(id)).sets;
      await controller.completeSet(setId: sets[0].id);
      await controller.completeSet(setId: sets[1].id);

      final stored = (await curl(id)).sets;
      expect(stored[0].weightKg, 15, reason: 'links');
      expect(stored[1].weightKg, 12, reason: 'rechts');
    });
  });

  group('records', () {
    test('a one-armed set does not become a record', () async {
      final id = await controller.startEmpty(name: 'Armen');
      await controller.addExercises(id, ['ex-curl']);
      final weId = (await curl(id)).workoutExercise.id;
      await controller.setUnilateral(weId, unilateral: true);

      final sets = (await curl(id)).sets;
      final result = await controller.completeSet(
        setId: sets.first.id,
        weightKg: 15,
        reps: 10,
      );
      await controller.finish(id, discardPending: true);

      expect(result!.records, isEmpty);
      expect(await db.recordsDao.recordsForExercise('ex-curl'), isEmpty);
    });

    test('and does not spoil the two-handed one', () async {
      // 30 kg with both hands, then 15 kg with one. The record has to stay 30.
      final first = await controller.startEmpty(name: 'Armen');
      await controller.addExercises(first, ['ex-curl']);
      await controller.completeSet(
        setId: (await curl(first)).sets.first.id,
        weightKg: 30,
        reps: 10,
      );
      await controller.finish(first, discardPending: true);

      final second = await controller.startEmpty(name: 'Armen');
      await controller.addExercises(second, ['ex-curl']);
      await controller.setUnilateral(
        (await curl(second)).workoutExercise.id,
        unilateral: true,
      );
      await controller.completeSet(
        setId: (await curl(second)).sets.first.id,
        weightKg: 15,
        reps: 10,
      );
      await controller.finish(second, discardPending: true);

      await db.recordsDao.rebuildAllRecords();

      final best = await db.recordsDao.currentBests('ex-curl');
      expect(best[PrType.maxWeight], 30);
    });
  });

  test('both sides count towards the volume', () async {
    final id = await controller.startEmpty(name: 'Armen');
    await controller.addExercises(id, ['ex-curl']);
    final weId = (await curl(id)).workoutExercise.id;
    await controller.setUnilateral(weId, unilateral: true);

    final sets = (await curl(id)).sets;
    await controller.completeSet(setId: sets[0].id, weightKg: 15, reps: 10);
    await controller.completeSet(setId: sets[1].id, weightKg: 15, reps: 8);
    await controller.finish(id, discardPending: true);

    final workout = await db.workoutsDao.getWorkoutDetail(id);
    expect(
      workout!.workout.totalVolumeKg,
      15 * 10 + 15 * 8,
      reason: 'links en rechts zijn allebei echt gedaan',
    );
  });
}
