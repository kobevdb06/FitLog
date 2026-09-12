import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:fitlog/features/workout/presentation/rest_timer_bar.dart';
import 'package:fitlog/core/widgets/numeric_keypad.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Checking a set off runs a chain of awaits (database write, record check,
/// haptic feedback with its own delays, then the timer), so the test clock has
/// to be advanced a few times before the result is visible.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late String workoutId;
  late String setId;

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
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    workoutId = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
    final created = await db.workoutsDao.addExercises(workoutId, [
      'ex-bench',
    ], defaultRestSeconds: 90);
    final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
    setId = detail!.exercises.single.sets.single.id;
    expect(created, hasLength(1));

    await db.workoutsDao.updateSet(
      setId,
      weightKg: const Value(100),
      reps: const Value(5),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Keeps the key manager off the platform channels.
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      wrapWithContainer(container, const ActiveWorkoutScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('the session shows its exercise and set row', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.byType(SetRow), findsOneWidget);
    // Column headers of the set table.
    expect(find.text('VORIGE'), findsOneWidget);
    expect(find.text('REPS'), findsOneWidget);
  });

  testWidgets('checking a set off writes it and starts the rest timer', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    expect(container.read(restTimerProvider).isActive, isFalse);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);

    final stored = await db.workoutsDao.getSet(setId);
    expect(stored!.isCompleted, isTrue);
    expect(stored.completedAt, isNotNull);

    final timer = container.read(restTimerProvider);
    expect(timer.isActive, isTrue);
    expect(timer.totalSeconds, 90);
    expect(timer.exerciseName, 'Barbell Bench Press');

    await tester.pump();
    expect(find.byType(RestTimerBar), findsOneWidget);
  });

  testWidgets('checking a set off records the first personal records', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);

    final records = await db.recordsDao.recordsForExercise('ex-bench');
    expect(records, hasLength(4));
    expect(records.map((r) => PrType.fromWire(r.recordType)).toSet(), {
      PrType.maxWeight,
      PrType.est1rm,
      PrType.maxSetVolume,
      PrType.maxReps,
    });
  });

  testWidgets('a second tap marks the set as skipped', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);
    expect((await db.workoutsDao.getSet(setId))!.isCompleted, isTrue);

    await tester.tap(find.bySemanticsLabel('Set voltooid'));
    await settle(tester);

    final stored = await db.workoutsDao.getSet(setId);
    expect(stored!.isCompleted, isFalse);
    expect(stored.completedAt, isNull);
    expect(stored.isSkipped, isTrue);

    // The values themselves survive, so a third tap loses nothing.
    expect(stored.weightKg, 100);
    expect(stored.reps, 5);

    // And the button says so: a cross where the tick was.
    expect(find.bySemanticsLabel('Set overgeslagen'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('a third tap brings the set back to empty', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Set voltooid'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Set overgeslagen'));
    await settle(tester);

    final stored = await db.workoutsDao.getSet(setId);
    expect(stored!.isCompleted, isFalse);
    expect(stored.isSkipped, isFalse);
    expect(find.bySemanticsLabel('Set afvinken'), findsOneWidget);
  });

  testWidgets('a long press clears a checked set in one gesture', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);

    await tester.longPress(find.bySemanticsLabel('Set voltooid'));
    await settle(tester);

    final stored = await db.workoutsDao.getSet(setId);
    expect(stored!.isCompleted, isFalse);
    expect(stored.isSkipped, isFalse, reason: 'niet via geskipt eromheen');
    expect(stored.weightKg, 100);
  });

  testWidgets('a long press clears a skipped set too', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Set voltooid'));
    await settle(tester);

    await tester.longPress(find.bySemanticsLabel('Set overgeslagen'));
    await settle(tester);

    expect((await db.workoutsDao.getSet(setId))!.isSkipped, isFalse);
  });

  testWidgets('the previous column says which set was skipped last time', (
    tester,
  ) async {
    // A finished session where the one set was deliberately left out.
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-old',
            name: 'Push',
            startedAt: 1000,
            endedAt: const Value(2000),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-old',
            workoutId: 'w-old',
            exerciseId: 'ex-bench',
            sortOrder: 0,
          ),
        );
    await db
        .into(db.workoutSetsTable)
        .insert(
          WorkoutSetsTableCompanion.insert(
            id: 's-old',
            workoutExerciseId: 'we-old',
            sortOrder: 0,
            isSkipped: const Value(true),
          ),
        );

    await pumpScreen(tester);

    // Not a dash, which would read as "no data": last time you left it out.
    expect(find.text('Geskipt'), findsOneWidget);
  });

  testWidgets('a timed exercise asks for a time instead of kilograms', (
    tester,
  ) async {
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-plank',
            name: 'Plank',
            primaryMuscle: 'core',
            category: 'duration',
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    await db.workoutsDao.addExercises(workoutId, [
      'ex-plank',
    ], defaultRestSeconds: 90);

    await pumpScreen(tester);

    // The bench press still has its own two columns...
    expect(find.text('KG'), findsOneWidget);
    expect(find.text('REPS'), findsOneWidget);
    // ...and the plank asks for seconds instead.
    expect(find.text('TIJD'), findsOneWidget);
  });

  testWidgets('a swiped set is gone', (tester) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(SetRow), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(SetRow), findsNothing);
    expect(await db.workoutsDao.getSet(setId), isNull);
  });

  testWidgets('changing the type changes what the set asks for', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('KG'), findsOneWidget);
    expect(find.text('TIJD'), findsNothing);

    // The same call the "Type wijzigen" menu makes.
    await db.exercisesDao.setCategory('ex-bench', ExerciseCategory.duration);
    await settle(tester);

    expect(find.text('TIJD'), findsOneWidget);
    final row = await db.exercisesDao.getById('ex-bench');
    expect(
      row!.categoryOverridden,
      isTrue,
      reason: 'een cataloguscorrectie mag dit niet terugdraaien',
    );
  });

  testWidgets('tapping the exercise name shows it without leaving the '
      'workout', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    // The sheet, over the session - not the four-tab exercise page.
    expect(find.text('Records en grafieken'), findsOneWidget);
    expect(find.byType(SetRow), findsOneWidget, reason: 'de sessie staat er nog');
  });

  group('tapping the previous column', () {
    /// A finished session of the bench press to compare against.
    Future<void> lastTime({double weightKg = 80, int reps = 8}) async {
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w-old',
              name: 'Push',
              startedAt: 1000,
              endedAt: const Value(2000),
            ),
          );
      await db
          .into(db.workoutExercisesTable)
          .insert(
            WorkoutExercisesTableCompanion.insert(
              id: 'we-old',
              workoutId: 'w-old',
              exerciseId: 'ex-bench',
              sortOrder: 0,
            ),
          );
      await db
          .into(db.workoutSetsTable)
          .insert(
            WorkoutSetsTableCompanion.insert(
              id: 's-old',
              workoutExerciseId: 'we-old',
              sortOrder: 0,
              weightKg: Value(weightKg),
              reps: Value(reps),
              isCompleted: const Value(true),
            ),
          );
    }

    testWidgets('puts those numbers in the row', (tester) async {
      await lastTime();
      // Start this set empty, so the copy is the only thing that could fill it.
      await db.workoutsDao.updateSet(
        setId,
        weightKg: const Value(null),
        reps: const Value(null),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('80 kg × 8'));
      await settle(tester);

      final stored = await db.workoutsDao.getSet(setId);
      expect(stored!.weightKg, 80);
      expect(stored.reps, 8);
      expect(stored.isCompleted, isFalse, reason: 'invullen is niet afvinken');
    });

    testWidgets('does nothing when there is nothing to take', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('-').first);
      await settle(tester);

      // Untouched: the set still holds what it held.
      final stored = await db.workoutsDao.getSet(setId);
      expect(stored!.weightKg, 100);
      expect(stored.reps, 5);
    });
  });

  group('the keypad arriving and leaving', () {
    testWidgets('it slides in rather than appearing', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('100').first);
      await tester.pump();

      // A frame in, it is on its way but not yet in place.
      await tester.pump(const Duration(milliseconds: 60));
      final moving = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.byType(NumericKeypad),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(moving.position.value.dy, greaterThan(0));
      expect(moving.position.value.dy, lessThan(1));

      await tester.pumpAndSettle();
      final settled = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.byType(NumericKeypad),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(settled.position.value.dy, 0, reason: 'aangekomen');
    });

    testWidgets('a flick down on the handle puts it away', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('100').first);
      await tester.pumpAndSettle();

      await tester.fling(
        find.bySemanticsLabel('Toetsenblok sluiten'),
        const Offset(0, 200),
        800,
      );
      await tester.pumpAndSettle();

      expect(find.byType(NumericKeypad), findsNothing);
    });

    testWidgets('a flick up on the handle does not', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('100').first);
      await tester.pumpAndSettle();

      await tester.fling(
        find.bySemanticsLabel('Toetsenblok sluiten'),
        const Offset(0, -200),
        800,
      );
      await tester.pumpAndSettle();

      expect(find.byType(NumericKeypad), findsOneWidget);
    });
  });

  group('going back with the keypad up', () {
    testWidgets('puts the keypad away instead of leaving the session', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.text('100').first);
      await tester.pumpAndSettle();
      expect(find.byType(NumericKeypad), findsOneWidget);

      // What the Android back button and the back gesture both come in as.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(NumericKeypad), findsNothing);
      expect(
        find.byType(SetRow),
        findsOneWidget,
        reason: 'de sessie staat er nog',
      );
    });

    testWidgets('and leaves it once the keypad is gone', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('100').first);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Second time: nothing in front of it any more, so back means back.
      final handled = await tester.binding.handlePopRoute();

      expect(handled, isFalse, reason: 'het scherm houdt hem niet meer tegen');
    });
  });

  testWidgets('tapping a weight cell opens the custom keypad, not the '
      'system keyboard', (tester) async {
    await pumpScreen(tester);

    // Only the note field is a real text field before the cell is tapped.
    expect(find.byType(EditableText), findsOneWidget);

    // The weight cell shows the stored value.
    await tester.tap(find.text('100').first);
    await tester.pump();

    // The custom pad appears, and no extra text field is focused for it.
    expect(find.byType(NumericKeypad), findsOneWidget);
    expect(find.text('+2,5'), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
  });
}
