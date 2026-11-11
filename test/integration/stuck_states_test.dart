import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Small things from the Fable report, T10 (DECISIONS 286).
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
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a workout whose deleting fails is back, not hidden for good', () async {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        historyActionsProvider.overrideWith(_FailingActions.new),
      ],
    );
    final pending = container.read(pendingWorkoutDeletionsProvider.notifier);
    pending.schedule('w-1');

    await expectLater(pending.commitNow('w-1'), throwsA(isA<StateError>()));
    expect(pending.isPending('w-1'), isFalse);
  });

  test('a superset of one is no superset', () async {
    // Two in a superset and one of them taken out: the other stayed in a
    // group of its own, marked as a superset with nothing (DECISIONS 286).
    for (final id in ['a', 'b']) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: id,
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
    final controller = container.read(workoutControllerProvider);
    final workout = await controller.startEmpty(name: 'Push');
    await controller.addExercises(workout, ['a', 'b']);
    var exercises = (await db.workoutsDao.getWorkoutDetail(workout))!.exercises;
    for (final e in exercises) {
      await controller.setSupersetGroup(e.workoutExercise.id, 0);
    }

    await controller.removeExercise(exercises.first.workoutExercise.id);

    exercises = (await db.workoutsDao.getWorkoutDetail(workout))!.exercises;
    expect(exercises.single.workoutExercise.supersetGroup, isNull);
  });

  test('a plank takes the time of last time, not its weight', () async {
    // A plank of last time with a weight on it - from before the columns
    // went by the exercise - gave this one a weight column too.
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'plank',
            name: 'Plank',
            primaryMuscle: 'buik',
            category: 'duration',
            createdAt: 0,
          ),
        );
    final controller = container.read(workoutControllerProvider);
    final before = await controller.startEmpty(name: 'Kern');
    await controller.addExercises(before, ['plank']);
    final old = (await db.workoutsDao.getWorkoutDetail(before))!
        .exercises
        .single
        .sets
        .single;
    await db.workoutsDao.updateSet(
      old.id,
      weightKg: const Value(10),
      durationSeconds: const Value(60),
    );
    await controller.completeSet(setId: old.id);
    await db.workoutsDao.finishWorkout(before, discardPending: true);

    final now = await controller.startEmpty(name: 'Kern');
    await controller.addExercises(now, ['plank']);
    final set = (await db.workoutsDao.getWorkoutDetail(now))!
        .exercises
        .single
        .sets
        .single;
    await controller.completeSet(setId: set.id);

    final done = (await db.workoutsDao.getWorkoutDetail(now))!
        .exercises
        .single
        .sets
        .single;
    expect(done.durationSeconds, 60);
    expect(done.weightKg, isNull);
  });
}

class _FailingActions extends HistoryActions {
  _FailingActions(super.ref);

  @override
  Future<void> deleteWorkout(String workoutId) async =>
      throw StateError('kapot');
}
