import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// What the running-workout screen rebuilds, and what it leaves alone.
///
/// It used to rebuild entirely once a second - every visible exercise and
/// every set row - so that one line of text could show a new number. That is
/// tens of milliseconds of work per second while you are logging, and it lands
/// in the middle of a page transition often enough to be seen.
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithContainer(container, const ActiveWorkoutScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The widget instance, not the element: a rebuild reuses the element and
  /// puts a brand new widget in it, so identity here is what says whether that
  /// part of the tree was built again.
  Object instanceOf(WidgetTester tester, String text) =>
      tester.widget(find.text(text));

  testWidgets('a second passing does not rebuild the exercises', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Oefening 0'), findsOneWidget);
    final before = instanceOf(tester, 'Oefening 0');

    await tester.pump(const Duration(seconds: 1));

    expect(
      identical(instanceOf(tester, 'Oefening 0'), before),
      isTrue,
      reason: 'de oefeningen horen niet mee te bouwen voor een klok',
    );
  });

  testWidgets('and neither does five of them', (tester) async {
    // The old screen did this once a second for the whole session.
    await pump(tester);
    final before = instanceOf(tester, 'Oefening 2');

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(identical(instanceOf(tester, 'Oefening 2'), before), isTrue);
  });
}
