import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/features/workout/domain/workout_notice.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What the standing notification says while a workout runs. Worked out from
/// the session rather than from the screen, because the screen may be gone.
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

    for (final e in const [
      ('ex-squat', 'Barbell Squat', 'quadriceps'),
      ('ex-bench', 'Barbell Bench Press', 'borst'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: e.$1,
              name: e.$2,
              primaryMuscle: e.$3,
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<WorkoutDetail> detail(String id) async =>
      (await db.workoutsDao.getWorkoutDetail(id))!;

  Future<String> startWith(List<String> exercises, {int sets = 3}) async {
    final id = await controller.startEmpty(name: 'Push A');
    await controller.addExercises(id, exercises);
    for (final exercise in (await detail(id)).exercises) {
      while ((await detail(id)).exercises
              .firstWhere((e) => e.exercise.id == exercise.exercise.id)
              .sets
              .length <
          sets) {
        await controller.addSet(exercise.workoutExercise.id);
      }
    }
    return id;
  }

  test('there is nothing to show without a workout', () {
    expect(workoutNoticeFor(null), isNull);
  });

  test('a finished workout shows nothing either', () async {
    final id = await startWith(['ex-squat']);
    await controller.finish(id, discardPending: true);

    expect(workoutNoticeFor(await detail(id)), isNull);
  });

  test('it names the workout and the first set still to do', () async {
    final id = await startWith(['ex-squat']);

    final notice = workoutNoticeFor(await detail(id))!;
    expect(notice.title, 'Push A');
    expect(notice.body, 'Barbell Squat · set 1 van 3');
    expect(notice.isResting, isFalse);
  });

  test('it moves along as sets are ticked off', () async {
    final id = await startWith(['ex-squat']);
    final sets = (await detail(id)).exercises.single.sets;

    await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
    expect(
      workoutNoticeFor(await detail(id))!.body,
      'Barbell Squat · set 2 van 3',
    );

    await controller.completeSet(setId: sets[1].id, weightKg: 100, reps: 5);
    expect(
      workoutNoticeFor(await detail(id))!.body,
      'Barbell Squat · set 3 van 3',
    );
  });

  test('it moves on to the next exercise', () async {
    final id = await startWith(['ex-squat', 'ex-bench']);
    for (final set in (await detail(id)).exercises.first.sets) {
      await controller.completeSet(setId: set.id, weightKg: 100, reps: 5);
    }

    expect(
      workoutNoticeFor(await detail(id))!.body,
      startsWith('Barbell Bench Press'),
    );
  });

  test('a warm-up is called a warm-up, and does not take a number', () async {
    final id = await startWith(['ex-squat']);
    final sets = (await detail(id)).exercises.single.sets;
    await controller.setSetType(sets[0].id, SetType.warmup);

    final notice = workoutNoticeFor(await detail(id))!;
    expect(notice.body, 'Barbell Squat · warming-up');

    await controller.completeSet(setId: sets[0].id);
    expect(
      workoutNoticeFor(await detail(id))!.body,
      'Barbell Squat · set 1 van 2',
      reason: 'the working sets are numbered without the warm-up',
    );
  });

  test('everything done says so rather than a set number', () async {
    final id = await startWith(['ex-squat'], sets: 1);
    for (final set in (await detail(id)).exercises.single.sets) {
      await controller.completeSet(setId: set.id, weightKg: 100, reps: 5);
    }

    expect(workoutNoticeFor(await detail(id))!.body, 'Alle sets gedaan');
  });

  test('an empty workout says there is nothing in it yet', () async {
    final id = await controller.startEmpty(name: 'Leeg');
    expect(workoutNoticeFor(await detail(id))!.body, 'Nog geen oefeningen');
  });

  test('resting carries the moment the rest is over', () async {
    final id = await startWith(['ex-squat']);
    final endsAt = DateTime.now().add(const Duration(seconds: 90));

    final notice = workoutNoticeFor(await detail(id), restEndsAt: endsAt)!;
    expect(notice.isResting, isTrue);
    expect(notice.restEndsAt, endsAt);
  });

  test('the start time comes from the session, not from now', () async {
    final id = await controller.startEmpty(name: 'Push A');
    final started = (await detail(id)).workout.startedAt;

    expect(
      workoutNoticeFor(await detail(id))!.startedAt.millisecondsSinceEpoch,
      started,
    );
  });

  test('two notices for the same state are the same notice', () async {
    // The root listener leans on this: an unchanged workout must not repost
    // the notification on every rebuild.
    final id = await startWith(['ex-squat']);
    final first = workoutNoticeFor(await detail(id));
    final second = workoutNoticeFor(await detail(id));

    expect(first, second);

    final sets = (await detail(id)).exercises.single.sets;
    await controller.completeSet(setId: sets[0].id, weightKg: 100, reps: 5);
    expect(workoutNoticeFor(await detail(id)), isNot(first));
  });
}
