import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/photos/presentation/photo_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:fitlog/features/workout/presentation/pr_attempt_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The action objects hold a `Ref` and are used across async gaps: the user
/// confirms a dialog, picks a photo, waits out a file copy. If the provider
/// that owns that `Ref` is auto-disposed in the meantime, every call after the
/// gap throws and - with no listener on screen - the failure is invisible.
///
/// These are the providers that must therefore outlive a gap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Nothing listens to these providers, so a few turns of the event loop is
  /// all it takes for an auto-disposing one to be torn down. That is exactly
  /// what happens while a confirmation dialog is open.
  Future<void> letTheUserThink() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('routine actions survive the confirmation dialog', () async {
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex',
            name: 'Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );
    final actions = container.read(routineActionsProvider);
    final routineId = await actions.create(
      const RoutineDraft(
        name: 'Weg hiermee',
        exercises: [
          RoutineExerciseDraft(exerciseId: 'ex', sets: [RoutineSetDraft()]),
        ],
      ),
    );

    // The screen reads the actions, then shows a dialog and waits.
    final held = container.read(routineActionsProvider);
    await letTheUserThink();

    await held.delete(routineId);
    expect(await db.routinesDao.getRoutine(routineId), isNull);
  });

  test('folder actions survive the rename dialog', () async {
    final actions = container.read(routineActionsProvider);
    final folderId = await actions.createFolder('Push Pull Legs');

    await letTheUserThink();

    await actions.renameFolder(folderId, 'Bovenlichaam');
    final folders = await db.routinesDao.watchFolders().first;
    expect(folders.single.name, 'Bovenlichaam');
  });

  test('history actions survive the confirmation dialog', () async {
    final workoutId = await container
        .read(workoutControllerProvider)
        .startEmpty(name: 'Weg');
    await container
        .read(workoutControllerProvider)
        .finish(workoutId, discardPending: false);

    final actions = container.read(historyActionsProvider);
    await letTheUserThink();

    await actions.deleteWorkout(workoutId);
    expect(await db.workoutsDao.getWorkoutDetail(workoutId), isNull);
  });

  test('photo actions survive the picker', () async {
    // Picking a photo takes the app to another screen for seconds on end,
    // which is the longest gap in the app.
    final actions = container.read(photoActionsProvider);
    await letTheUserThink();

    // Reaching the paths at all is what used to throw; the picker itself
    // needs a platform channel and is covered in test/photos/.
    expect(() => actions.paths(), returnsNormally);
  });

  test('exercise editor survives the delete confirmation', () async {
    final editor = container.read(exerciseEditorProvider);
    final id = await editor.create(
      name: 'Eigen oefening',
      primaryMuscle: 'borst',
      secondaryMuscles: const [],
      category: ExerciseCategory.barbell,
    );

    await letTheUserThink();

    final deleted = await editor.removeOrArchive(id);
    expect(deleted, isTrue);
    expect(await db.exercisesDao.getById(id), isNull);
  });

  test('PR actions survive the configuration screen', () async {
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'squat',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );

    final actions = container.read(prAttemptActionsProvider);
    await letTheUserThink();

    final id = await actions.start(
      exerciseId: 'squat',
      config: const PrAttemptConfig(
        targetKg: 120,
        warmupSets: 4,
        extraAttempts: 1,
        barKg: 20,
        platesKg: [25, 20, 15, 10, 5, 2.5, 1.25],
      ),
    );
    expect(id, isNotEmpty);
  });
}
