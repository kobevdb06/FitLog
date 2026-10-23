import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/deload.dart';
import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/plans/data/plan_actions.dart';
import 'package:fitlog/features/plans/data/plan_deload.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A session of a schema is this week's: a set more or a few repetitions
/// fewer, the weight FitLog works out, or the schema's deload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late WorkoutController controller;
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

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
            id: 'ex-bench',
            name: 'Bench Press',
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

  /// A schema whose week 1 - this week - is [thisWeek], with one session of
  /// a warm-up and three sets of 60 × 5. It starts this Monday when
  /// [started], the week after when not.
  Future<String> plan(
    PlanWeek thisWeek, {
    PlanProgression progression = PlanProgression.app,
    List<PlanWeek> later = const [
      PlanWeek(),
      PlanWeek(kind: PlanWeekKind.deload),
    ],
    bool started = true,
  }) async {
    await db.plansDao.createDraft(
      id: 'p-1',
      goal: 'Sterker',
      split: PlanSplit.fullBody,
      days: 0x01,
      progression: progression,
      at: now,
    );
    await db.plansDao.layOut(
      'p-1',
      name: 'Kracht',
      weeks: [thisWeek, ...later],
      at: now,
    );
    final id = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Full body',
        exercises: [
          RoutineExerciseDraft(
            exerciseId: 'ex-bench',
            sets: [
              RoutineSetDraft(
                setType: SetType.warmup,
                targetWeightKg: 30,
                targetReps: 10,
              ),
              RoutineSetDraft(targetWeightKg: 60, targetReps: 5),
              RoutineSetDraft(targetWeightKg: 60, targetReps: 5),
              RoutineSetDraft(targetWeightKg: 60, targetReps: 5),
            ],
          ),
        ],
      ),
    );
    await db.plansDao.placeSession(id, planId: 'p-1', position: 0);
    await PlanActions.start(
      db,
      'p-1',
      from: started
          ? monday
          : DateTime(monday.year, monday.month, monday.day + 7),
    );
    return id;
  }

  Future<List<WorkoutSetRow>> working(String workoutId) async => [
    for (final s in (await db.workoutsDao.getWorkoutDetail(
      workoutId,
    ))!.exercises.single.sets)
      if (SetType.fromWire(s.setType) != SetType.warmup) s,
  ];

  test('a week with a set more and two repetitions fewer', () async {
    final id = await controller.startFromRoutine(
      await plan(const PlanWeek(sets: 1, reps: -2)),
    );
    final sets = await working(id);
    expect(sets, hasLength(4));
    expect([for (final s in sets) s.reps], [3, 3, 3, 3]);
    expect([for (final s in sets) s.weightKg], [60, 60, 60, 60]);
  });

  test('a set fewer, but never none', () async {
    final id = await controller.startFromRoutine(
      await plan(const PlanWeek(sets: -3)),
    );
    expect(await working(id), hasLength(1));
  });

  test('FitLog keeps the numbers: one step heavier once the target was '
      'reached', () async {
    final routine = await plan(const PlanWeek());
    // Last time, every set of 60 reached its five.
    final before = await controller.startFromRoutine(routine);
    for (final set in await working(before)) {
      await controller.completeSet(setId: set.id, weightKg: 60, reps: 5);
    }
    await controller.finish(before, discardPending: true);

    final id = await controller.startFromRoutine(routine);
    expect([for (final s in await working(id)) s.weightKg], [62.5, 62.5, 62.5]);
  });

  test('when the coach keeps the numbers, the routine is the week', () async {
    final id = await controller.startFromRoutine(
      await plan(
        const PlanWeek(sets: 1, reps: -2),
        progression: PlanProgression.coach,
      ),
    );
    final sets = await working(id);
    expect(sets, hasLength(3));
    expect([for (final s in sets) s.reps], [5, 5, 5]);
  });

  test('before the schema began, a session of it is the routine', () async {
    final id = await controller.startFromRoutine(
      await plan(const PlanWeek(sets: 1), started: false),
    );
    expect(await working(id), hasLength(3));
  });

  test(
    'a deload week is the schema\'s deload, like one started by hand',
    () async {
      final id = await controller.startFromRoutine(
        await plan(
          const PlanWeek(kind: PlanWeekKind.deload),
          later: const [PlanWeek()],
        ),
      );
      final workout = (await db.workoutsDao.getWorkoutDetail(id))!;
      expect(workout.workout.isDeload, isTrue);
      final deload = (await db.deloadDao.currentAt(now))!;
      expect(deload.source, kPlanDeloadSource);
      expect(deload.from, monday);
      expect(deload.days, 7);
    },
  );

  group('the deload of the deload week', () {
    test('is planned when the schema starts', () async {
      await plan(const PlanWeek());
      final deload = (await db.deloadDao.currentAt(now))!;
      expect(deload.source, kPlanDeloadSource);
      expect(deload.from, DateTime(monday.year, monday.month, monday.day + 14));
    });

    test('does not replace one of the user\'s own', () async {
      await db.deloadDao.start(
        from: DateTime(monday.year, monday.month, monday.day + 7),
        days: 5,
        plan: const DeloadPlan(),
        source: 'user',
      );
      await plan(const PlanWeek());
      final deload = (await db.deloadDao.currentAt(now))!;
      expect(deload.source, 'user');
      expect(deload.days, 5);
    });

    test('goes when the schema stops before it', () async {
      await plan(const PlanWeek());
      await PlanActions.stop(db, 'p-1');
      expect(await db.deloadDao.currentAt(now), isNull);
    });
  });
}
