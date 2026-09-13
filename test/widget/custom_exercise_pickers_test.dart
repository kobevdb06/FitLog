import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/features/exercises/presentation/custom_exercise_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Choosing a category and a muscle for an exercise you made yourself.
///
/// Both were Material dropdowns: a grey slab over the form, in a style the app
/// uses nowhere else, and with nothing but a name on each line.
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
    addTearDown(container.dispose);

    // The muscle list comes from the catalogue, so there has to be one.
    for (final (id, muscle) in [('ex-bench', 'borst'), ('ex-curl', 'biceps')]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: id,
              primaryMuscle: muscle,
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(PickerField));

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithContainer(container, const CustomExerciseScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('no dropdown is left on the form', (tester) async {
    await pumpForm(tester);

    expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    expect(field('Categorie'), findsOneWidget);
    expect(field('Primaire spiergroep'), findsOneWidget);
  });

  group('the category', () {
    testWidgets('opens the app sheet and picks', (tester) async {
      await pumpForm(tester);

      await tester.tap(field('Categorie'));
      await tester.pumpAndSettle();
      expect(find.text('Hoe doe je deze oefening?'), findsOneWidget);

      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();

      expect(find.text('Hoe doe je deze oefening?'), findsNothing);
      expect(
        find.descendant(of: field('Categorie'), matching: find.text('Cardio')),
        findsOneWidget,
      );
    });

    testWidgets('carries a picture, and a different one per kind', (
      tester,
    ) async {
      await pumpForm(tester);

      // Barbell to start with, so the field shows the barbell's own icon.
      expect(
        find.descendant(
          of: field('Categorie'),
          matching: find.byIcon(Icons.linear_scale),
        ),
        findsOneWidget,
      );

      await tester.tap(field('Categorie'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.directions_run), findsOneWidget);
      expect(find.byIcon(Icons.cable), findsOneWidget);

      await tester.tap(find.text('Cardio'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: field('Categorie'),
          matching: find.byIcon(Icons.directions_run),
        ),
        findsOneWidget,
      );
    });
  });

  group('the muscle', () {
    testWidgets('says nothing is chosen until you choose', (tester) async {
      await pumpForm(tester);

      expect(
        find.descendant(
          of: field('Primaire spiergroep'),
          matching: find.text('Kies een spiergroep'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers what the catalogue knows, with its own mark', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(field('Primaire spiergroep'));
      await tester.pumpAndSettle();

      expect(find.text('Welke spier werkt het hardst?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'biceps'),
          matching: find.byType(MuscleAvatar),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and the one you pick lands in the field, mark and all', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(field('Primaire spiergroep'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('biceps').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: field('Primaire spiergroep'),
          matching: find.text('biceps'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: field('Primaire spiergroep'),
          matching: find.byType(MuscleAvatar),
        ),
        findsOneWidget,
      );
    });
  });
}
