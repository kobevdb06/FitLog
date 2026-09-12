import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/history/presentation/workout_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Correcting a set in your history.
///
/// The dialog used to ask for kilograms and repetitions whatever the exercise.
/// For a plank that left the time - the only thing it is measured in -
/// impossible to correct, and typing into those two questions hid the time
/// behind a weight that means nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late String workoutId;

  /// A finished session with one set of [exerciseId].
  Future<String> session({
    required String exerciseId,
    double? weightKg,
    int? reps,
    int? durationSeconds,
  }) async {
    final id = await db.workoutsDao.startWorkout(
      name: 'Sessie',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(id, [exerciseId], defaultRestSeconds: 90);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    await db.workoutsDao.updateSet(
      set.id,
      weightKg: Value(weightKg),
      reps: Value(reps),
      durationSeconds: Value(durationSeconds),
      isCompleted: const Value(true),
    );
    await db.workoutsDao.finishWorkout(id, discardPending: false);
    return id;
  }

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        exerciseImagesProvider.overrideWith(
          (ref) => const ExerciseImageManifest(
            format: 'webp',
            animated: {},
            staticOnly: {},
            withoutImages: {'ex-plank', 'ex-bench'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    for (final (id, name, category) in const [
      ('ex-plank', 'Plank', 'duration'),
      ('ex-bench', 'Bankdrukken', 'barbell'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: 'buik',
              category: category,
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithContainer(container, WorkoutDetailScreen(workoutId: workoutId)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a plank is corrected in seconds, not in kilograms', (
    tester,
  ) async {
    workoutId = await session(exerciseId: 'ex-plank', durationSeconds: 60);
    await pumpDetail(tester);

    await tester.tap(find.text('01:00'));
    await tester.pumpAndSettle();

    expect(find.text('Tijd'), findsOneWidget);
    expect(find.text('Gewicht'), findsNothing);
    expect(find.text('Reps'), findsNothing);
  });

  testWidgets('and the correction lands on the time', (tester) async {
    workoutId = await session(exerciseId: 'ex-plank', durationSeconds: 60);
    await pumpDetail(tester);

    await tester.tap(find.text('01:00'));
    await tester.pumpAndSettle();
    // The pad opens on the value that is there; clear it before typing.
    await tester.tap(find.byTooltip('Leegmaken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final set = (await db.workoutsDao.getWorkoutDetail(workoutId))!
        .exercises
        .single
        .sets
        .single;
    expect(set.durationSeconds, 75);
    expect(set.weightKg, isNull, reason: 'een plank heeft geen gewicht');
    expect(set.reps, isNull);
  });

  testWidgets('an ordinary set is still corrected in weight and reps', (
    tester,
  ) async {
    workoutId = await session(exerciseId: 'ex-bench', weightKg: 100, reps: 5);
    await pumpDetail(tester);

    await tester.tap(find.textContaining('100'));
    await tester.pumpAndSettle();

    expect(find.text('Gewicht'), findsOneWidget);
  });
}
