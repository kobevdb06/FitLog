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

    final workoutId = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
    final created = await db.workoutsDao.addExercises(
      workoutId,
      ['ex-bench'],
      defaultRestSeconds: 90,
    );
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
    expect(
      records.map((r) => PrType.fromWire(r.recordType)).toSet(),
      {
        PrType.maxWeight,
        PrType.est1rm,
        PrType.maxSetVolume,
        PrType.maxReps,
      },
    );
  });

  testWidgets('unchecking a set clears it again', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Set afvinken'));
    await settle(tester);
    expect((await db.workoutsDao.getSet(setId))!.isCompleted, isTrue);

    await tester.tap(find.bySemanticsLabel('Set voltooid'));
    await settle(tester);

    final stored = await db.workoutsDao.getSet(setId);
    expect(stored!.isCompleted, isFalse);
    expect(stored.completedAt, isNull);

    // The values themselves survive an accidental un-tick.
    expect(stored.weightKg, 100);
    expect(stored.reps, 5);
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
