import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/theme/app_colors.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A routine's colour, and the copy every session started from it keeps.
///
/// Copied rather than looked up, the way the name already is: recolour the
/// routine or delete it and your history still shows what you did that day in
/// the colour you did it in.
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

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> makeRoutine({int? colour}) =>
      container.read(routineActionsProvider).create(
        RoutineDraft(
          name: 'Benen',
          colorIndex: colour,
          exercises: const [
            RoutineExerciseDraft(exerciseId: 'ex', sets: [RoutineSetDraft()]),
          ],
        ),
      );

  group('the palette', () {
    test('an index outside it is no colour, not a crash', () {
      expect(AppColors.routineColor(null), isNull);
      expect(AppColors.routineColor(-1), isNull);
      expect(AppColors.routineColor(AppColors.routinePalette.length), isNull);
    });

    test('every index in it has a colour', () {
      for (var i = 0; i < AppColors.routinePalette.length; i++) {
        expect(AppColors.routineColor(i), isNotNull);
      }
    });
  });

  test('a routine without a colour keeps none', () async {
    final id = await makeRoutine();
    expect((await db.routinesDao.getRoutine(id))!.colorIndex, isNull);
  });

  test('a colour is stored and read back', () async {
    final id = await makeRoutine(colour: 3);
    expect((await db.routinesDao.getRoutine(id))!.colorIndex, 3);
  });

  test('editing keeps it, and can clear it', () async {
    final id = await makeRoutine(colour: 3);
    final actions = container.read(routineActionsProvider);

    await actions.update(
      id,
      const RoutineDraft(
        name: 'Benen',
        colorIndex: 5,
        exercises: [
          RoutineExerciseDraft(exerciseId: 'ex', sets: [RoutineSetDraft()]),
        ],
      ),
    );
    expect((await db.routinesDao.getRoutine(id))!.colorIndex, 5);

    await actions.update(
      id,
      const RoutineDraft(
        name: 'Benen',
        exercises: [
          RoutineExerciseDraft(exerciseId: 'ex', sets: [RoutineSetDraft()]),
        ],
      ),
    );
    expect((await db.routinesDao.getRoutine(id))!.colorIndex, isNull);
  });

  test('a session takes the colour of the routine it came from', () async {
    final routineId = await makeRoutine(colour: 2);
    final workoutId = await container
        .read(workoutControllerProvider)
        .startFromRoutine(routineId);

    final workout = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(workout!.workout.colorIndex, 2);
  });

  test('a loose workout has none', () async {
    final id = await container
        .read(workoutControllerProvider)
        .startEmpty(name: 'Los');

    expect(
      (await db.workoutsDao.getWorkoutDetail(id))!.workout.colorIndex,
      isNull,
    );
  });

  test('recolouring the routine leaves finished sessions alone', () async {
    final routineId = await makeRoutine(colour: 2);
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startFromRoutine(routineId);
    await controller.finish(workoutId, discardPending: true);

    await container.read(routineActionsProvider).update(
      routineId,
      const RoutineDraft(
        name: 'Benen',
        colorIndex: 6,
        exercises: [
          RoutineExerciseDraft(exerciseId: 'ex', sets: [RoutineSetDraft()]),
        ],
      ),
    );

    final workout = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(
      workout!.workout.colorIndex,
      2,
      reason: 'that session was done in the old colour',
    );
  });

  test('deleting the routine leaves the colour on the session', () async {
    final routineId = await makeRoutine(colour: 4);
    final controller = container.read(workoutControllerProvider);
    final workoutId = await controller.startFromRoutine(routineId);
    await controller.finish(workoutId, discardPending: true);

    await container.read(routineActionsProvider).delete(routineId);

    final workout = await db.workoutsDao.getWorkoutDetail(workoutId);
    expect(workout!.workout.colorIndex, 4);
    expect(workout.workout.routineId, isNull);
  });

  test('doing a session again keeps its colour', () async {
    final routineId = await makeRoutine(colour: 1);
    final controller = container.read(workoutControllerProvider);
    final first = await controller.startFromRoutine(routineId);
    await controller.finish(first, discardPending: true);

    final again = await controller.repeat(first);

    expect(
      (await db.workoutsDao.getWorkoutDetail(again))!.workout.colorIndex,
      1,
    );
  });
}
