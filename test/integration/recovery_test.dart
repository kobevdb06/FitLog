import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/progress/presentation/recovery_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The recovery estimate over the real database: which sets the query hands
/// to the calculation, and what the session rating does to the answer.
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
            id: 'ex-squat',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            secondaryMuscles: const Value('["bilspieren"]'),
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Logs one finished session of squats and returns its id.
  Future<String> logSquats({
    int sets = 3,
    double weightKg = 100,
    int reps = 5,
    int warmups = 0,
  }) async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Benen');
    await controller.addExercises(workoutId, ['ex-squat']);

    final detail = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
    final existing = detail.exercises.single.sets.length;
    for (var i = existing; i < sets + warmups; i++) {
      await controller.addSet(detail.exercises.single.workoutExercise.id);
    }

    final full = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
    final all = full.exercises.single.sets;
    for (var i = 0; i < all.length && i < sets + warmups; i++) {
      if (i < warmups) {
        await controller.setSetType(all[i].id, SetType.warmup);
      }
      await controller.completeSet(
        setId: all[i].id,
        weightKg: weightKg,
        reps: reps,
      );
    }

    await controller.finish(workoutId, discardPending: true);
    return workoutId;
  }

  Future<List<RecoveryEstimate>> estimates() async {
    final sets = await db.workoutsDao.recoverySets(
      since: DateTime.now().subtract(kRecoveryHistoryWindow),
    );
    return estimateRecovery(muscleSessions(sets));
  }

  test('a finished session produces an estimate per muscle', () async {
    final workoutId = await logSquats();

    final result = await estimates();
    expect(result.map((e) => e.muscle).toSet(), {'quadriceps', 'bilspieren'});
    expect(result.every((e) => e.workoutId == workoutId), isTrue);
    expect(result.every((e) => e.provisional), isTrue);
  });

  test('a muscle worked only as a secondary still gets an estimate', () async {
    await logSquats();

    final glutes = (await estimates()).firstWhere(
      (e) => e.muscle == 'bilspieren',
    );
    expect(glutes.recovery, greaterThan(Duration.zero));

    // Its share of the load is smaller, but with no history to compare
    // against there is nothing for that to change yet: the estimate is the
    // starting point for the muscle either way.
    final quads = (await estimates()).firstWhere(
      (e) => e.muscle == 'quadriceps',
    );
    expect(glutes.recovery, quads.recovery);
    expect(glutes.provisional, isTrue);
  });

  test('a running workout is not counted yet', () async {
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startEmpty(name: 'Bezig');
    await controller.addExercises(workoutId, ['ex-squat']);
    final detail = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
    await controller.completeSet(
      setId: detail.exercises.single.sets.first.id,
      weightKg: 100,
      reps: 5,
    );

    expect(await estimates(), isEmpty);
  });

  test('warm-ups do not reach the calculation', () async {
    await logSquats(sets: 2, warmups: 2);

    final sets = await db.workoutsDao.recoverySets(
      since: DateTime.now().subtract(kRecoveryHistoryWindow),
    );
    expect(sets, hasLength(2));
    expect(sets.every((s) => s.setType != SetType.warmup), isTrue);
  });

  test('the query carries the muscles and the category over', () async {
    await logSquats(sets: 1);

    final sets = await db.workoutsDao.recoverySets(
      since: DateTime.now().subtract(kRecoveryHistoryWindow),
    );
    expect(sets.single.primaryMuscle, 'quadriceps');
    expect(sets.single.secondaryMuscles, ['bilspieren']);
    expect(sets.single.category, ExerciseCategory.barbell);
    expect(sets.single.effort, isNull);
  });

  group('the session rating', () {
    test('a hard session pushes the estimate out', () async {
      final workoutId = await logSquats();
      final before = (await estimates()).first.recovery;

      await container
          .read(recoveryActionsProvider)
          .rate(workoutId, PerceivedEffort.allOut);

      expect((await estimates()).first.recovery, greaterThan(before));
    });

    test('an easy session pulls it in', () async {
      final workoutId = await logSquats();
      final before = (await estimates()).first.recovery;

      await container
          .read(recoveryActionsProvider)
          .rate(workoutId, PerceivedEffort.veryEasy);

      expect((await estimates()).first.recovery, lessThan(before));
    });

    test('it can be taken back', () async {
      final workoutId = await logSquats();
      final actions = container.read(recoveryActionsProvider);
      final neutral = (await estimates()).first.recovery;

      await actions.rate(workoutId, PerceivedEffort.allOut);
      expect((await estimates()).first.recovery, isNot(neutral));

      await actions.rate(workoutId, null);
      expect((await estimates()).first.recovery, neutral);
      final row = await db.workoutsDao.getWorkoutDetail(workoutId);
      expect(row!.workout.perceivedEffort, isNull);
    });

    test('the rating is stored on the wire value', () async {
      final workoutId = await logSquats();
      await container
          .read(recoveryActionsProvider)
          .rate(workoutId, PerceivedEffort.hard);

      final row = await db.workoutsDao.getWorkoutDetail(workoutId);
      expect(row!.workout.perceivedEffort, 'hard');
      expect(
        PerceivedEffort.fromWire(row.workout.perceivedEffort),
        PerceivedEffort.hard,
      );
    });
  });
}
