import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/formatting/formatters.dart';
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
