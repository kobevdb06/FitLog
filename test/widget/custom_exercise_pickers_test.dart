import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
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
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Zonder fotomap tekent het scherm de fotovakken niet, en dan valt er
        // ook niets te tikken.
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
      ],
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

  group('een tekening laten maken', () {
    /// De fotovakken staan onderaan het formulier, buiten beeld.
    Future<void> openFrameSheet(WidgetTester tester) async {
      // Het label is niet het tikvlak; het vak eronder wel.
      await tester.ensureVisible(find.text('Foto kiezen').first);
      await tester.pump();
      await tester.tap(find.text('Foto kiezen').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('staat er niet zonder token', (tester) async {
      await pumpForm(tester);

      await openFrameSheet(tester);

      expect(find.text('Nu een foto maken'), findsOneWidget);
      // Geen token, geen knop: er kan niets getekend worden en dus wordt het
      // ook niet aangeboden.
      expect(find.text('Laten tekenen'), findsNothing);
    });

    testWidgets('en er wel zodra er een token staat', (tester) async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
      await pumpForm(tester);

      await openFrameSheet(tester);

      expect(find.text('Laten tekenen'), findsOneWidget);
      expect(find.textContaining('Kost tegoed'), findsOneWidget);
    });

    testWidgets('en zonder naam wordt er niets getekend', (tester) async {
      // Een tekening van "" is weggegooid tegoed.
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
      await pumpForm(tester);

      await openFrameSheet(tester);
      await tester.tap(find.text('Laten tekenen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Geef eerst een naam'), findsOneWidget);
    });
  });

  group('a category of your own', () {
    testWidgets('stands between the built-in ones, and says what it counts '
        'as', (tester) async {
      await db.exercisesDao.addCustomCategory('Slee', 'duration');
      await pumpForm(tester);

      await tester.tap(field('Categorie'));
      await tester.pumpAndSettle();

      expect(find.text('Slee'), findsOneWidget);
      expect(find.text('Van jezelf, rekent als tijd'), findsOneWidget);

      await tester.tap(find.text('Slee'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: field('Categorie'), matching: find.text('Slee')),
        findsOneWidget,
      );
    });

    testWidgets('and is saved as a name on top of the built-in one', (
      tester,
    ) async {
      await db.exercisesDao.addCustomCategory('Slee', 'duration');
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Sledepush');
      await tester.tap(field('Categorie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slee'));
      await tester.pumpAndSettle();

      await tester.tap(field('Primaire spiergroep'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('borst').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      final saved = (await db.exercisesDao.getExercises()).firstWhere(
        (e) => e.name == 'Sledepush',
      );
      // The name is yours; how a set of it is logged is not.
      expect(saved.customCategory, 'Slee');
      expect(saved.category, 'duration');
    });
  });

  group('een tekening die je weghaalt', () {
    /// Een oefening zoals de coach ze aanmaakt: twee tekeningen, en het
    /// merkteken eronder dat zegt dat ze getekend zijn.
    Future<void> addDrawn() async {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-drawn',
              name: 'Sledepush',
              primaryMuscle: 'benen',
              category: 'duration',
              createdAt: 0,
              isCustom: const Value(true),
              startImageFile: const Value('start.jpg'),
              endImageFile: const Value('end.jpg'),
              imagesGenerated: const Value(true),
            ),
          );
    }

    Future<void> pumpEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithContainer(
          container,
          const CustomExerciseScreen(exerciseId: 'ex-drawn'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Het eerste vak dat er nog een heeft; de knop van de oefening zelf staat
    /// verderop.
    Future<void> clearFirstFrame(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Verwijderen').first);
      await tester.pump();
      await tester.tap(find.text('Verwijderen').first);
      await tester.pump();
    }

    testWidgets('neemt het merkteken mee als de laatste weg is', (
      tester,
    ) async {
      await addDrawn();
      await pumpEditor(tester);

      await clearFirstFrame(tester);
      await clearFirstFrame(tester);

      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      final saved = (await db.exercisesDao.getById('ex-drawn'))!;
      expect(saved.startImageFile, isNull);
      expect(saved.endImageFile, isNull);
      // Er is geen tekening meer, dus er valt ook niets meer over te zeggen.
      expect(saved.imagesGenerated, isFalse);
    });

    testWidgets('maar blijft staan zolang er nog een tekening hangt', (
      tester,
    ) async {
      await addDrawn();
      await pumpEditor(tester);

      await clearFirstFrame(tester);

      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      final saved = (await db.exercisesDao.getById('ex-drawn'))!;
      expect(saved.endImageFile, 'end.jpg');
      expect(saved.imagesGenerated, isTrue);
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
