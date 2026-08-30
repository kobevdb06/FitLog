import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/progress/presentation/records_screen.dart';
import 'package:fitlog/features/routines/presentation/routine_detail_screen.dart';
import 'package:fitlog/features/routines/presentation/routine_editor_screen.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The illustrations only ever reached the catalogue. Every other screen
/// showed the coloured muscle badge, because [ExerciseThumb] has to be given
/// the manifest and nobody passed it down.
///
/// A screen consults the manifest exactly when it builds an [ExerciseThumb],
/// so that is what these assert; whether the thumb then draws the picture or
/// its own fallback is [ExerciseThumb]'s own business and covered below.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  const seeded = 'barbell_squat';

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // The real manifest is read from the asset bundle, which a widget
        // test does not have.
        exerciseImagesProvider.overrideWith(
          (ref) => const ExerciseImageManifest(
            format: 'webp',
            animated: {seeded},
            staticOnly: {},
            withoutImages: {},
          ),
        ),
      ],
    );

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: seeded,
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

  Future<String> makeRoutine() =>
      container.read(routineActionsProvider).create(
        const RoutineDraft(
          name: 'Beenwerk',
          exercises: [
            RoutineExerciseDraft(exerciseId: seeded, sets: [RoutineSetDraft()]),
          ],
        ),
      );

  testWidgets('the routine editor shows the illustration', (tester) async {
    final routineId = await makeRoutine();

    await tester.pumpWidget(
      wrapWithContainer(container, RoutineEditorScreen(routineId: routineId)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.byType(ExerciseThumb), findsOneWidget);
  });

  testWidgets('the routine detail shows the illustration', (tester) async {
    final routineId = await makeRoutine();

    await tester.pumpWidget(
      wrapWithContainer(container, RoutineDetailScreen(routineId: routineId)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseThumb), findsOneWidget);
  });

  testWidgets('the record list shows the illustration', (tester) async {
    final workoutId = await container
        .read(workoutControllerProvider)
        .startEmpty(name: 'Squatten');
    await container.read(workoutControllerProvider).addExercises(workoutId, [
      seeded,
    ]);
    final detail = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
    await container.read(workoutControllerProvider).completeSet(
      setId: detail.exercises.single.sets.single.id,
      weightKg: 100,
      reps: 5,
    );
    await container
        .read(workoutControllerProvider)
        .finish(workoutId, discardPending: true);

    await tester.pumpWidget(wrapWithContainer(container, const RecordsScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseThumb), findsWidgets);
  });

  group('the thumb itself', () {
    ExerciseRow row({bool isCustom = false}) => ExerciseRow(
      id: isCustom ? 'mine' : seeded,
      name: 'Barbell Squat',
      primaryMuscle: 'quadriceps',
      secondaryMuscles: '',
      equipment: null,
      category: 'barbell',
      instructions: null,
      isCustom: isCustom,
      isArchived: false,
      createdAt: 0,
    );

    const manifest = ExerciseImageManifest(
      format: 'webp',
      animated: {seeded},
      staticOnly: {},
      withoutImages: {},
    );

    testWidgets('draws the asset when the manifest lists it', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          Center(child: ExerciseThumb(exercise: row(), manifest: manifest)),
        ),
      );

      final provider = tester.widget<Image>(find.byType(Image)).image;
      // cacheWidth wraps the asset so it decodes at display size, not at the
      // size of the file.
      expect(provider, isA<ResizeImage>());
      final asset = (provider as ResizeImage).imageProvider as AssetImage;
      expect(asset.assetName, 'assets/exercises/${seeded}_thumb.webp');
    });

    testWidgets('falls back to the badge for an own exercise', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          Center(
            child: ExerciseThumb(
              exercise: row(isCustom: true),
              manifest: manifest,
            ),
          ),
        ),
      );

      expect(find.byType(MuscleAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('falls back to the badge without a manifest', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          Center(child: ExerciseThumb(exercise: row(), manifest: null)),
        ),
      );

      expect(find.byType(MuscleAvatar), findsOneWidget);
    });
  });
}
