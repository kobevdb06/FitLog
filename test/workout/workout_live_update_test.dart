import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:fitlog/features/workout/data/workout_notice_channel.dart';
import 'package:fitlog/features/workout/domain/workout_notice.dart';
import 'package:fitlog/features/workout/presentation/workout_live_update.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The standing notification follows the workout through listeners, not
/// through a screen being drawn: nothing here pumps a single frame, which is
/// what the app has while it is in the background.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late _Poster poster;
  late WorkoutController controller;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Barbell Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
    poster = _Poster();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        workoutNoticePosterProvider.overrideWithValue(poster),
      ],
    );
    controller = container.read(workoutControllerProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// What the app's root does: listen, so the provider is not paused.
  void follow() => container.listen(workoutLiveUpdateProvider, (_, _) {});

  /// Lets the stream, the listeners and the sync they start run their course.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<List<String>> startBench({int sets = 3}) async {
    final id = await controller.startEmpty(name: 'Push A');
    await controller.addExercises(id, ['ex-bench']);
    var detail = (await db.workoutsDao.getWorkoutDetail(id))!;
    while (detail.exercises.single.sets.length < sets) {
      await controller.addSet(detail.exercises.single.workoutExercise.id);
      detail = (await db.workoutsDao.getWorkoutDetail(id))!;
    }
    return [for (final s in detail.exercises.single.sets) s.id];
  }

  test('een workout zet de melding neer, met de set die eraan komt', () async {
    follow();
    final sets = await startBench();
    await settle();

    expect(poster.shown.last.current!.setId, sets.first);
    expect(poster.shown.last.current!.label, 'Set 1 van 3');
  });

  test('afvinken schuift ze door, zonder dat er iets getekend wordt', () async {
    follow();
    final sets = await startBench();
    await settle();

    await controller.completeSet(setId: sets[0], weightKg: 80, reps: 8);
    await settle();

    final next = poster.shown.last.current!;
    expect(next.setId, sets[1]);
    expect(next.marks, [SetMark.done, SetMark.open, SetMark.open]);
  });

  test('een melding die niet veranderde, gaat er niet opnieuw op', () async {
    follow();
    await startBench();
    await settle();
    final count = poster.shown.length;

    await container.read(workoutLiveUpdateProvider.notifier).sync();
    await container.read(workoutLiveUpdateProvider.notifier).sync();

    expect(poster.shown, hasLength(count));
  });

  test('de rust staat erin zolang ze loopt, en daarna niet meer', () async {
    follow();
    await startBench();
    await settle();

    await container
        .read(restTimerProvider.notifier)
        .start(seconds: 1, withSound: false);
    await settle();
    expect(poster.shown.last.restEndsAt, isNotNull);

    // The timer the sync set for the end of the rest.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await settle();
    expect(poster.shown.last.restEndsAt, isNull);
  });

  group('afvinken vanuit de melding', () {
    test('vinkt de set af die ze toonde, en de rust begint', () async {
      follow();
      final sets = await startBench();
      await settle();

      final ticked = await container
          .read(workoutLiveUpdateProvider.notifier)
          .tick(sets[0]);

      expect(ticked, isTrue);
      final row = (await db.workoutsDao.getWorkoutDetail(
        (await db.workoutsDao.getActiveWorkoutRow())!.id,
      ))!.exercises.single.sets.first;
      expect(row.isCompleted, isTrue);
      expect(container.read(restTimerProvider).isActive, isTrue);
      // Already the next set, before the answer goes back to Android.
      expect(poster.shown.last.current!.setId, sets[1]);
      expect(poster.shown.last.restEndsAt, isNotNull);
    });

    test('bewaart wat ze toonde: hetzelfde als de set ervoor', () async {
      follow();
      final sets = await startBench();
      await settle();
      final notifier = container.read(workoutLiveUpdateProvider.notifier);
      await controller.completeSet(setId: sets[0], weightKg: 70, reps: 10);
      await settle();
      expect(poster.shown.last.current!.weightKg, 70);

      await notifier.tick(sets[1]);

      final row = (await db.workoutsDao.getWorkoutDetail(
        (await db.workoutsDao.getActiveWorkoutRow())!.id,
      ))!.exercises.single.sets[1];
      expect(row.weightKg, 70);
      expect(row.reps, 10);
    });

    test(
      'een tweede tik op een oude melding vinkt niet de volgende af',
      () async {
        follow();
        final sets = await startBench();
        await settle();
        final notifier = container.read(workoutLiveUpdateProvider.notifier);

        await notifier.tick(sets[0]);
        final again = await notifier.tick(sets[0]);

        expect(again, isFalse);
        final rows = (await db.workoutsDao.getWorkoutDetail(
          (await db.workoutsDao.getActiveWorkoutRow())!.id,
        ))!.exercises.single.sets;
        expect(rows.where((s) => s.isCompleted), hasLength(1));
      },
    );
  });

  group('het paneel over een andere app', () {
    Future<WorkoutSetRow> firstSet() async =>
        (await db.workoutsDao.getWorkoutDetail(
          (await db.workoutsDao.getActiveWorkoutRow())!.id,
        ))!.exercises.single.sets.first;

    test('schrijft wat het aanpaste op de set, zonder af te vinken', () async {
      follow();
      final sets = await startBench();
      await settle();

      final answer = await container
          .read(workoutLiveUpdateProvider.notifier)
          .edit(sets[0], (
            weightKg: 82.5,
            reps: 6,
            durationSeconds: null,
          ), complete: false);

      expect(answer['ok'], isTrue);
      final row = await firstSet();
      expect(row.weightKg, 82.5);
      expect(row.reps, 6);
      expect(row.isCompleted, isFalse);
      // The island shows the new values straight away.
      expect(poster.shown.last.current!.weightKg, 82.5);
    });

    test('vinkt af met wat het aanpaste, en zegt wat er nu komt', () async {
      follow();
      final sets = await startBench();
      await settle();

      final answer = await container
          .read(workoutLiveUpdateProvider.notifier)
          .edit(sets[0], (
            weightKg: 85,
            reps: 5,
            durationSeconds: null,
          ), complete: true);

      expect(answer['ok'], isTrue);
      final next = answer['set']! as Map<String, Object?>;
      expect(next['id'], sets[1]);
      expect(next['marks'], ['done', 'open', 'open']);
      final row = await firstSet();
      expect(row.isCompleted, isTrue);
      expect(row.weightKg, 85);
      expect(row.reps, 5);
    });

    test('een set die al voorbij is, wordt niet meer aangepast', () async {
      follow();
      final sets = await startBench();
      await settle();
      final notifier = container.read(workoutLiveUpdateProvider.notifier);
      await notifier.tick(sets[0]);

      final answer = await notifier.edit(sets[0], (
        weightKg: 100,
        reps: 1,
        durationSeconds: null,
      ), complete: false);

      expect(answer['ok'], isFalse);
      expect((await firstSet()).weightKg, isNot(100));
    });
  });

  test(
    'een set zonder waarden zegt niets, in plaats van een streepje',
    () async {
      follow();
      await startBench();
      await settle();

      final set =
          workoutNoticePayload(poster.shown.last, const Formatters())['set']!
              as Map<String, Object?>;

      expect(set['values'], isNull);
      expect(set['chip'], 'Set 1');
    },
  );

  test('wat naar Android gaat, is al uitgewerkt en verwoord', () async {
    follow();
    final sets = await startBench();
    await controller.updateSetValues(
      sets[0],
      weightKg: const Value(80),
      reps: const Value(8),
    );
    await settle();

    final payload = workoutNoticePayload(poster.shown.last, const Formatters());
    final set = payload['set']! as Map<String, Object?>;

    expect(payload['title'], 'Push A');
    expect(set['id'], sets[0]);
    expect(set['exercise'], 'Barbell Bench Press');
    expect(set['label'], 'Set 1 van 3');
    expect(set['chip'], '80×8');
    expect(set['values'], '80 kg × 8');
    expect(set['marks'], ['open', 'open', 'open']);
    expect(set['position'], 0);
    expect(set['outside'], isTrue);
  });

  test('afronden haalt ze weg', () async {
    follow();
    await startBench();
    await settle();
    final id = (await db.workoutsDao.getActiveWorkoutRow())!.id;

    await controller.finish(id, discardPending: true);
    await settle();

    expect(poster.cancelled, isTrue);
  });
}

class _Poster implements WorkoutNoticePoster {
  final shown = <WorkoutNotice>[];
  var cancelled = false;

  @override
  Future<void> show(WorkoutNotice notice, Formatters format) async {
    shown.add(notice);
    cancelled = false;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}
