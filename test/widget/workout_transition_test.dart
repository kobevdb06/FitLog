import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The exercises wait for the page to finish sliding in.
///
/// Building them costs 36 to 44 ms on a phone and a frame is 16,7 ms, so doing
/// it while the page is still moving loses two frames of every transition -
/// measured, on the device, four times out of four. Nothing here makes the
/// list cheaper; it stops being built while something is animating.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-$i',
              name: 'Oefening $i',
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
    final id = await db.workoutsDao.startWorkout(
      name: 'Chest day',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(id, [
      'ex-0',
      'ex-1',
      'ex-2',
    ], defaultRestSeconds: 90);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        exerciseImagesProvider.overrideWith(
          (ref) => const ExerciseImageManifest(
            format: 'webp',
            animated: {},
            staticOnly: {},
            withoutImages: {'ex-0', 'ex-1', 'ex-2'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('not while the page is still moving, and right after', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      wrapWithContainer(container, const SizedBox.shrink()),
    );
    // The frame above has no navigator of its own, so the screen is pushed
    // onto one that does - the same kind of route the app uses.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => const ActiveWorkoutScreen(),
      ),
    );

    // Halfway through the slide.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.text('Oefening 0'),
      findsNothing,
      reason: 'de lijst hoort niet gebouwd te worden terwijl de pagina beweegt',
    );
    // The chrome is there from the first frame; only the list waits.
    expect(find.text('Chest day'), findsOneWidget);

    // And once it has landed.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Oefening 0'), findsOneWidget);
  });

  testWidgets('and immediately where there is nothing to wait for', (
    tester,
  ) async {
    // A screen that is simply there - a test, or one embedded somewhere - has
    // no arriving animation, and waiting for one would wait forever.
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithContainer(container, const ActiveWorkoutScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Oefening 0'), findsOneWidget);
  });
}
