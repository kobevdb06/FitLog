import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What the "vorige" column costs.
///
/// It used to be two providers per exercise per side, and each of them awaited
/// the running workout itself while needing nothing from it but the id. So
/// every set you ticked off re-ran six queries about a session that cannot
/// have changed, and rebuilt the screen once per answer - in the middle of the
/// page transition.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  var loads = 0;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    loads = 0;
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-$i',
              name: 'Oefening $i',
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  /// A session of [count] exercises, with the history subscribed to.
  Future<WorkoutDetail> session({int count = 3}) async {
    final id = await db.workoutsDao.startWorkout(
      name: 'Chest day',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(id, [
      for (var i = 0; i < count; i++) 'ex-$i',
    ], defaultRestSeconds: 90);
    return (await db.workoutsDao.getWorkoutDetail(id))!;
  }

  /// Subscribes the way the screen does, and counts every reload.
  void watch(WorkoutDetail workout) {
    container.listen(
      previousSessionProvider(workout.workout.id, lineUpOf(workout)),
      (previous, next) {
        if (next.hasValue) loads++;
      },
      fireImmediately: true,
    );
  }

  test('one load for a whole session, however many exercises', () async {
    final workout = await session();
    watch(workout);
    await container.read(
      previousSessionProvider(workout.workout.id, lineUpOf(workout)).future,
    );

    expect(loads, 1, reason: 'drie oefeningen, één keer laden');
  });

  test('and filling in a set does not load it again', () async {
    // Nothing you do during a session can change what the session before it
    // looked like.
    final workout = await session();
    final key = lineUpOf(workout);
    watch(workout);
    await container.read(
      previousSessionProvider(workout.workout.id, key).future,
    );
    final after = loads;

    final set = workout.exercises.first.sets.first;
    await db.workoutsDao.updateSet(set.id, weightKg: const Value(100));
    await db.workoutsDao.updateSet(set.id, isCompleted: const Value(true));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(loads, after, reason: 'de vorige sessie is niet veranderd');
  });

  test('but adding an exercise does, or its history never arrives', () async {
    final workout = await session(count: 2);
    watch(workout);
    await container.read(
      previousSessionProvider(workout.workout.id, lineUpOf(workout)).future,
    );

    await db.workoutsDao.addExercises(workout.workout.id, [
      'ex-2',
    ], defaultRestSeconds: 90);
    final grown = (await db.workoutsDao.getWorkoutDetail(workout.workout.id))!;

    expect(
      lineUpOf(grown),
      isNot(lineUpOf(workout)),
      reason: 'een andere bezetting is een andere geschiedenis',
    );
  });

  test('the history itself is what the previous session held', () async {
    // One finished session, then a new one with the same exercise in it.
    final old = await session(count: 1);
    final set = old.exercises.single.sets.first;
    await db.workoutsDao.updateSet(
      set.id,
      weightKg: const Value(100),
      reps: const Value(6),
    );
    await db.workoutsDao.updateSet(set.id, isCompleted: const Value(true));
    await db.workoutsDao.finishWorkout(old.workout.id, discardPending: true);

    final now = await session(count: 1);
    final history = await container.read(
      previousSessionProvider(now.workout.id, lineUpOf(now)).future,
    );

    final previous = history.setsFor('ex-0', null);
    expect(previous, hasLength(1));
    expect(previous!.single.weightKg, 100);
    expect(previous.single.reps, 6);
    expect(history.noteFor('ex-0'), isNull);
  });
}
