import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The routine editor could reorder exercises and the running session could
/// not: mid-workout you could replace, remove and superset, but not decide to
/// do the bench before the rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late WorkoutController controller;
  late String workoutId;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    controller = container.read(workoutControllerProvider);

    for (final exercise in const [
      ('ex-squat', 'Barbell Squat', 'quadriceps'),
      ('ex-bench', 'Barbell Bench Press', 'borst'),
      ('ex-row', 'Barbell Row', 'bovenrug'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: exercise.$1,
              name: exercise.$2,
              primaryMuscle: exercise.$3,
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }

    workoutId = await controller.startEmpty(name: 'Push A');
    await controller.addExercises(workoutId, [
      'ex-squat',
      'ex-bench',
      'ex-row',
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<List<String>> order() async => (await db.workoutsDao.getWorkoutDetail(
    workoutId,
  ))!.exercises.map((e) => e.exercise.id).toList();

  Future<List<String>> ids() async => (await db.workoutsDao.getWorkoutDetail(
    workoutId,
  ))!.exercises.map((e) => e.workoutExercise.id).toList();

  test('the order starts as it was added', () async {
    expect(await order(), ['ex-squat', 'ex-bench', 'ex-row']);
  });

  test('moving one to the front sticks', () async {
    final current = await ids();
    await controller.reorderExercises([current[2], current[0], current[1]]);

    expect(await order(), ['ex-row', 'ex-squat', 'ex-bench']);
  });

  test('the sets travel with their exercise', () async {
    final current = await ids();
    final detail = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
    await controller.completeSet(
      setId: detail.exercises.first.sets.first.id,
      weightKg: 100,
      reps: 5,
    );

    await controller.reorderExercises([current[1], current[2], current[0]]);

    final after = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
    final squat = after.exercises.firstWhere(
      (e) => e.exercise.id == 'ex-squat',
    );
    expect(after.exercises.last.exercise.id, 'ex-squat');
    expect(squat.sets.first.weightKg, 100);
    expect(squat.sets.first.isCompleted, isTrue);
  });

  testWidgets('the running workout has a handle per exercise', (tester) async {
    await tester.pumpWidget(
      wrapWithContainer(container, const ActiveWorkoutScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
    expect(find.byType(SliverReorderableList), findsOneWidget);
  });

  testWidgets('dragging the first exercise down reorders it', (tester) async {
    await tester.pumpWidget(
      wrapWithContainer(container, const ActiveWorkoutScreen()),
    );
    await tester.pumpAndSettle();

    final handle = find.byType(ReorderableDragStartListener).first;
    final start = tester.getCenter(handle);

    final drag = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout);
    // In steps, because the list decides on a swap while the finger moves and
    // one jump past two cards tells it nothing about where it went.
    for (var i = 0; i < 8; i++) {
      await drag.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect((await order()).first, isNot('ex-squat'));
  });
}
