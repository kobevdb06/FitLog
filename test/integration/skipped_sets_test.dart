import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/domain/workout_notice.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Skipping a set on purpose.
///
/// An empty set and a skipped set look the same to the database - neither is
/// completed - but they mean different things: one you have not got to, the
/// other you decided to leave out. Only the second is worth carrying into the
/// next session, and that is what these tests pin down.
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

  Future<WorkoutExerciseDetail> bench(String workoutId) async =>
      (await db.workoutsDao.getWorkoutDetail(workoutId))!.exercises.single;

  /// A running session with [sets] working sets of the bench press.
  Future<String> start({int sets = 3}) async {
    final id = await controller.startEmpty(name: 'Push');
    await controller.addExercises(id, ['ex-bench']);
    while ((await bench(id)).sets.length < sets) {
      await controller.addSet((await bench(id)).workoutExercise.id);
    }
    return id;
  }

  group('the three states', () {
    test('done, then skipped, then empty again', () async {
      final id = await start(sets: 1);
      final setId = (await bench(id)).sets.single.id;

      await controller.completeSet(setId: setId, weightKg: 100, reps: 5);
      var row = (await db.workoutsDao.getSet(setId))!;
      expect(row.isCompleted, isTrue);
      expect(row.isSkipped, isFalse);

      await controller.skipSet(setId);
      row = (await db.workoutsDao.getSet(setId))!;
      expect(row.isCompleted, isFalse);
      expect(row.isSkipped, isTrue);

      await controller.uncompleteSet(setId);
      row = (await db.workoutsDao.getSet(setId))!;
      expect(row.isCompleted, isFalse);
      expect(row.isSkipped, isFalse);
    });

    test('skipping keeps what was typed, so going back loses nothing', () async {
      final id = await start(sets: 1);
      final setId = (await bench(id)).sets.single.id;
      await controller.updateSetValues(
        setId,
        weightKg: const Value(100),
        reps: const Value(5),
      );

      await controller.skipSet(setId);

      final row = (await db.workoutsDao.getSet(setId))!;
      expect(row.weightKg, 100);
      expect(row.reps, 5);
    });

    test('a skipped set is not pending', () async {
      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
      await controller.skipSet(sets[1].id);

      final workout = (await db.workoutsDao.getWorkoutDetail(id))!;
      expect(workout.completedSets, 1);
      expect(workout.skippedSets, 1);
      expect(workout.pendingSets, 1, reason: 'alleen de lege set staat open');
    });
  });

  group('finishing', () {
    test('throwing away what is not filled in keeps the skipped set', () async {
      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
      await controller.skipSet(sets[1].id);

      await controller.finish(id, discardPending: true);

      final stored = (await bench(id)).sets;
      expect(stored, hasLength(2), reason: 'de lege set is weg, de rest niet');
      expect(stored[0].isCompleted, isTrue);
      expect(stored[1].isSkipped, isTrue);
    });

    test('a session of nothing but skipped sets still has its exercise', () async {
      final id = await start(sets: 2);
      for (final set in (await bench(id)).sets) {
        await controller.skipSet(set.id);
      }

      await controller.finish(id, discardPending: true);

      final workout = (await db.workoutsDao.getWorkoutDetail(id))!;
      expect(workout.exercises, hasLength(1));
      expect(workout.exercises.single.sets, hasLength(2));
    });

    test('it counts for no volume and no record', () async {
      final id = await start(sets: 2);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
      await controller.skipSet(sets[1].id);
      await controller.finish(id, discardPending: false);

      final workout = (await db.workoutsDao.getWorkoutDetail(id))!;
      expect(workout.workout.totalVolumeKg, 100 * 5);
      expect(workout.workout.totalSets, 1);
    });

    test('skipping a set that was already checked off takes its record away', () async {
      final id = await start(sets: 1);
      final setId = (await bench(id)).sets.single.id;
      await controller.completeSet(setId: setId, weightKg: 100, reps: 5);
      await controller.finish(id, discardPending: true);
      expect(await db.recordsDao.recordsForExercise('ex-bench'), isNotEmpty);

      await controller.skipSet(setId);

      expect(await db.recordsDao.recordsForExercise('ex-bench'), isEmpty);
    });
  });

  group('the next session', () {
    /// A finished session where the middle set was skipped.
    Future<void> sessionWithSkip() async {
      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
      await controller.skipSet(sets[1].id);
      await controller.completeSet(setId: sets[2].id, weightKg: 90, reps: 5);
      await controller.finish(id, discardPending: true);
    }

    test('the previous column knows which set was left out', () async {
      await sessionWithSkip();

      final previous = await db.workoutsDao.previousSetsFor('ex-bench');
      expect(previous, hasLength(3), reason: 'de nummering schuift niet op');
      expect(previous[0].isSkipped, isFalse);
      expect(previous[1].isSkipped, isTrue);
      expect(previous[2].isSkipped, isFalse);
      expect(previous[2].weightKg, 90, reason: 'set 3 blijft set 3');
    });

    test('an empty set takes nothing over from a skipped one', () async {
      await sessionWithSkip();

      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[1].id);

      final stored = (await bench(id)).sets[1];
      expect(stored.isCompleted, isTrue);
      expect(stored.weightKg, isNull, reason: 'vorige keer overgeslagen');
      expect(stored.reps, isNull);
    });

    test('the set after it still takes over its own numbers', () async {
      await sessionWithSkip();

      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[2].id);

      expect((await bench(id)).sets[2].weightKg, 90);
    });
  });

  group('the rest of the app leaves it alone', () {
    test('the notification names the next set you still have to do', () async {
      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
      await controller.skipSet(sets[1].id);

      final notice = workoutNoticeFor(
        await db.workoutsDao.getWorkoutDetail(id),
      );
      expect(notice!.body, 'Bankdrukken · set 3 van 3');
    });

    test('filling the rest in does not fill a skipped set', () async {
      final id = await start(sets: 3);
      final sets = (await bench(id)).sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
      await controller.skipSet(sets[1].id);

      final filled = await controller.fillRemainingSets(
        (await bench(id)).workoutExercise.id,
      );

      expect(filled, 1, reason: 'alleen de lege set');
      final stored = (await bench(id)).sets;
      expect(stored[1].isSkipped, isTrue);
      expect(stored[1].weightKg, isNull);
      expect(stored[2].weightKg, 100);
    });

    test('switching to one arm at a time keeps it', () async {
      final id = await start(sets: 2);
      final weId = (await bench(id)).workoutExercise.id;
      await controller.skipSet((await bench(id)).sets.first.id);

      await controller.setUnilateral(weId, unilateral: true);

      final sets = (await bench(id)).sets;
      expect(sets.first.isSkipped, isTrue);
      expect(sets.first.side, isNull, reason: 'die set is al afgehandeld');
      expect(
        sets.skip(1).map((s) => s.side),
        ['left', 'right'],
        reason: 'alleen de openstaande set wordt verdubbeld',
      );
    });
  });
}
