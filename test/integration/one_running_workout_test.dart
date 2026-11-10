import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// One running workout, however fast you tap (DECISIONS 245).
///
/// "Is one running already?" was asked outside the transaction that started
/// one, and the buttons on Start had no guard while starting: two quick
/// taps made two running workouts. With two rows every lookup of the
/// running one threw, and ticking off, totals and hints stopped working.
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
            id: 'ex-bench',
            name: 'Bankdrukken',
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

  Future<int> running() async => (await (db.select(
    db.workoutsTable,
  )..where((t) => t.endedAt.isNull())).get()).length;

  test('two starts at the same moment make one running workout', () async {
    final outcomes = await Future.wait([
      controller.startEmpty().then<Object>(
        (id) => id,
        onError: (Object e) => e,
      ),
      controller.startEmpty().then<Object>(
        (id) => id,
        onError: (Object e) => e,
      ),
    ]);

    expect(await running(), 1);
    expect(outcomes.whereType<StateError>(), hasLength(1));
  });

  test('the database itself holds no second running workout', () async {
    await controller.startEmpty();

    await expectLater(
      db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w-tweede',
              name: 'Tweede',
              startedAt: 1,
            ),
          ),
      throwsA(anything),
    );
    expect(await running(), 1);
  });

  test('a ticked-off set ticked again does nothing', () async {
    final id = await controller.startEmpty();
    await controller.addExercises(id, ['ex-bench']);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .first;

    final first = await controller.completeSet(
      setId: set.id,
      weightKg: 100,
      reps: 5,
    );
    final second = await controller.completeSet(
      setId: set.id,
      weightKg: 100,
      reps: 5,
    );

    expect(first, isNotNull);
    expect(second, isNull, reason: 'no second rest, no second record');
  });

  test('finishing twice keeps the moment it ended', () async {
    final id = await controller.startEmpty();
    await db.workoutsDao.finishWorkout(id, discardPending: true);
    final ended = (await db.workoutsDao.getWorkoutDetail(id))!.workout.endedAt;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await db.workoutsDao.finishWorkout(id, discardPending: true);

    expect((await db.workoutsDao.getWorkoutDetail(id))!.workout.endedAt, ended);
  });

  test('a lookup of the running one survives two of them', () async {
    // From before the guard: two rows without an end, written straight in.
    await db.customStatement('DROP INDEX IF EXISTS idx_one_running_workout');
    for (final (id, at) in [('w-1', 1000), ('w-2', 2000)]) {
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(id: id, name: id, startedAt: at),
          );
    }

    final row = await db.workoutsDao.getActiveWorkoutRow();

    expect(row?.id, 'w-2', reason: 'the newest');
  });

  test('a finished one is not running', () async {
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-klaar',
            name: 'Klaar',
            startedAt: 1,
            endedAt: const Value(2),
          ),
        );
    await controller.startEmpty();
    expect(await running(), 1);
  });
}
