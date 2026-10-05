import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// What to try today, on every exercise of a running session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late String routineId;

  /// One finished session of bench press, [daysAgo] days back.
  Future<void> logBench(
    int daysAgo,
    double kg,
    List<int> reps, {
    double? rpe,
  }) async {
    final at = DateTime.now().subtract(Duration(days: daysAgo));
    final id = 'w-$daysAgo';
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: id,
            name: 'Push',
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(at.millisecondsSinceEpoch + 3600000),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$daysAgo',
            workoutId: id,
            exerciseId: 'ex-bench',
            sortOrder: 0,
          ),
        );
    for (var i = 0; i < reps.length; i++) {
      await db
          .into(db.workoutSetsTable)
          .insert(
            WorkoutSetsTableCompanion.insert(
              id: 'ws-$daysAgo-$i',
              workoutExerciseId: 'we-$daysAgo',
              sortOrder: i,
              weightKg: Value(kg),
              reps: Value(reps[i]),
              rpe: Value(rpe),
              isCompleted: const Value(true),
            ),
          );
    }
  }

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
    routineId = await db.routinesDao.createRoutine(
      const RoutineDraft(
        name: 'Push',
        exercises: [
          RoutineExerciseDraft(
            exerciseId: 'ex-bench',
            sets: [
              RoutineSetDraft(setType: SetType.warmup, targetReps: 10),
              RoutineSetDraft(targetReps: 8, targetWeightKg: 80),
              RoutineSetDraft(targetReps: 8, targetWeightKg: 80),
              RoutineSetDraft(targetReps: 8, targetWeightKg: 80),
            ],
          ),
        ],
      ),
    );
    // Eerder 75 en 77,5: de stap op deze stang is 2,5.
    await logBench(21, 75, [8, 8, 8]);
    await logBench(14, 77.5, [8, 8, 8]);
  });

  tearDown(() => db.close());

  Future<void> pumpWorkout(
    WidgetTester tester, {
    Size size = const Size(1100, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => db.workoutsDao.startWorkout(
        routineId: routineId,
        defaultRestSeconds: 90,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ActiveWorkoutScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('alles gehaald: een stap zwaarder, en invullen vult de open '
      'sets', (tester) async {
    await tester.runAsync(() => logBench(7, 80, [8, 8, 8], rpe: 8));
    await pumpWorkout(tester);

    expect(find.text('Probeer 82,5 kg × 8'), findsOneWidget);
    expect(find.text('Vorige keer 3 × 8 met 80 kg, RPE 8'), findsOneWidget);

    await tester.tap(find.text('Invullen'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final sets = (await tester.runAsync(() async {
      final running = await db.workoutsDao.getActiveWorkoutRow();
      return db.workoutsDao.getWorkoutDetail(running!.id);
    }))!.exercises.single.sets;
    final working = sets.where((s) => s.setType != 'warmup').toList();
    expect(working.map((s) => s.weightKg), [82.5, 82.5, 82.5]);
    expect(working.map((s) => s.reps), [8, 8, 8]);
    // Ingevuld, niet afgevinkt; en de opwarming bleef zoals ze was.
    expect(working.any((s) => s.isCompleted), isFalse);
    expect(sets.first.setType, 'warmup');
    expect(sets.first.weightKg, isNull);
    expect(find.text('3 sets ingevuld'), findsOneWidget);
  });

  testWidgets('niet alles gehaald: zelfde gewicht, mik op het doel', (
    tester,
  ) async {
    await tester.runAsync(() => logBench(7, 80, [8, 7, 6]));
    await pumpWorkout(tester);

    expect(find.text('Zelfde gewicht, mik op 8'), findsOneWidget);
    expect(find.text('Vorige keer 8, 7, 6 met 80 kg'), findsOneWidget);
  });

  testWidgets('met de schakelaar uit geen hint', (tester) async {
    await tester.runAsync(() async {
      await logBench(7, 80, [8, 8, 8]);
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(progressionHints: Value(false)),
      );
    });
    await pumpWorkout(tester);

    expect(find.textContaining('Probeer'), findsNothing);
    expect(find.text('Invullen'), findsNothing);
  });

  testWidgets('past op een gsm met grote tekst', (tester) async {
    await tester.runAsync(() => logBench(7, 80, [8, 8, 8], rpe: 8));
    await pumpWorkout(tester, size: const Size(412, 915), textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.text('Invullen')).dx,
      lessThanOrEqualTo(412),
    );
    expect(find.text('Probeer 82,5 kg × 8'), findsOneWidget);
  });

  testWidgets('de eerste keer ook niet', (tester) async {
    await tester.runAsync(() async {
      await db.customStatement('DELETE FROM workout_sets');
      await db.customStatement('DELETE FROM workout_exercises');
      await db.customStatement('DELETE FROM workouts');
    });
    await pumpWorkout(tester);

    expect(find.text('Invullen'), findsNothing);
  });
}
