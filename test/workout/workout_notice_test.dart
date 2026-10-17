import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/core/formatting/formatters.dart';
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

  group('de set die eraan komt', () {
    test('met wat je intypte, de balkjes en de stap', () async {
      final id = await startWith(['ex-bench'], sets: 4);
      final sets = (await detail(id)).exercises.single.sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 80, reps: 8);
      await controller.skipSet(sets[1].id);
      await controller.updateSetValues(
        sets[2].id,
        weightKg: const Value(82.5),
        reps: const Value(6),
      );

      final next = workoutNoticeFor(
        await detail(id),
        platesKg: const [1.25, 2.5, 5, 10, 20],
      )!.current!;

      expect(next.setId, sets[2].id);
      expect(next.exerciseName, 'Barbell Bench Press');
      expect(next.label, 'Set 3 van 4');
      expect(next.marks, [
        SetMark.done,
        SetMark.skipped,
        SetMark.open,
        SetMark.open,
      ]);
      expect(next.position, 2);
      expect(next.weightKg, 82.5);
      expect(next.reps, 6);
      // The smallest pair of plates, as on the set row without history.
      expect(next.weightStepKg, 2.5);
      expect(next.worksOutside, isTrue);
    });

    test(
      'een lege set toont wat er de vorige keer op die plek stond',
      () async {
        final before = await startWith(['ex-bench'], sets: 2);
        final done = (await detail(before)).exercises.single.sets;
        await controller.completeSet(setId: done[0].id, weightKg: 70, reps: 10);
        await controller.completeSet(setId: done[1].id, weightKg: 75, reps: 8);
        await controller.finish(before, discardPending: true);

        final id = await startWith(['ex-bench'], sets: 2);
        final sets = (await detail(id)).exercises.single.sets;
        await controller.completeSet(setId: sets[0].id);

        final next = workoutNoticeFor(
          await detail(id),
          previous: await db.workoutsDao.previousSessionFor(id),
        )!.current!;

        expect(next.weightKg, 75);
        expect(next.reps, 8);
      },
    );

    test('zonder waarden en zonder geschiedenis: wat je net deed', () async {
      final id = await startWith(['ex-bench'], sets: 3);
      final sets = (await detail(id)).exercises.single.sets;
      await controller.completeSet(setId: sets[0].id, weightKg: 60, reps: 12);

      final next = workoutNoticeFor(await detail(id))!.current!;

      expect(next.setId, sets[1].id);
      expect(next.weightKg, 60);
      expect(next.reps, 12);
    });

    test('een warming-up staat niet op de balk', () async {
      final id = await startWith(['ex-squat']);
      final sets = (await detail(id)).exercises.single.sets;
      await controller.setSetType(sets[0].id, SetType.warmup);

      final next = workoutNoticeFor(await detail(id))!.current!;

      expect(next.label, 'Warming-up');
      expect(next.position, isNull);
      expect(next.marks, hasLength(2));
    });

    test('een poging op een record kan alleen in de app', () async {
      final id = await startWith(['ex-squat']);
      final exercise = (await detail(id)).exercises.single.workoutExercise;
      await (db.update(
        db.workoutExercisesTable,
      )..where((t) => t.id.equals(exercise.id))).write(
        const WorkoutExercisesTableCompanion(isPrAttempt: Value(true)),
      );

      expect(
        workoutNoticeFor(await detail(id))!.current!.worksOutside,
        isFalse,
      );
    });

    test('alles gedaan: geen set meer', () async {
      final id = await startWith(['ex-squat'], sets: 1);
      final set = (await detail(id)).exercises.single.sets.single;
      await controller.completeSet(setId: set.id, weightKg: 100, reps: 5);

      expect(workoutNoticeFor(await detail(id))!.current, isNull);
    });
  });

  group('wat het eiland dicht toont', () {
    NoticeSet set({
      ExerciseCategory category = ExerciseCategory.barbell,
      double? weightKg,
      int? reps,
      int? durationSeconds,
      int? position = 0,
    }) => NoticeSet(
      setId: 's',
      exerciseName: 'X',
      label: 'Set 1 van 3',
      marks: const [SetMark.open],
      category: category,
      weightStepKg: 2.5,
      position: position,
      weightKg: weightKg,
      reps: reps,
      durationSeconds: durationSeconds,
    );

    const kg = Formatters();
    const lb = Formatters(weightUnit: WeightUnit.lb);

    test('wat je moet tillen, kort genoeg voor de chip', () {
      expect(noticeChip(set(weightKg: 80, reps: 8), kg), '80×8');
      expect(noticeChip(set(weightKg: 82.5, reps: 6), kg), '82,5×6');
      expect(noticeChip(set(weightKg: 100, reps: 5), lb), '220,5×5');
      expect(noticeValues(set(weightKg: 80, reps: 8), kg), '80 kg × 8');
    });

    test('zonder gewicht, of op tijd', () {
      expect(
        noticeChip(set(category: ExerciseCategory.bodyweight, reps: 12), kg),
        '×12',
      );
      expect(
        noticeChip(
          set(category: ExerciseCategory.duration, durationSeconds: 45),
          kg,
        ),
        '0:45',
      );
      expect(
        noticeChip(
          set(category: ExerciseCategory.duration, durationSeconds: 90),
          kg,
        ),
        '1:30',
      );
    });

    test('zonder waarden: welke set', () {
      expect(noticeChip(set(position: 2), kg), 'Set 3');
      expect(noticeChip(set(position: null), kg), 'W');
    });
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
