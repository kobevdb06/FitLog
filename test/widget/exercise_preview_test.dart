import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/providers/core_providers.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:fitlog/features/exercises/presentation/exercise_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The quick look while picking exercises for a routine.
///
/// Building a routine you cannot always tell one row from another by name.
/// The preview answers that without taking you off the picker - and without
/// the records and charts of the full exercise page, which are not what you
/// are there for.
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
        exerciseImagesProvider.overrideWith(
          (ref) => const ExerciseImageManifest(
            format: 'webp',
            animated: {},
            staticOnly: {},
            withoutImages: {'ex-squat'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-squat',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            secondaryMuscles: const Value('["bilspieren"]'),
            equipment: const Value('halterstang'),
            category: 'barbell',
            instructions: const Value('Zet de stang op je schouders.'),
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpPicker(WidgetTester tester, {bool selecting = true}) async {
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        ExerciseLibraryScreen(selectionMode: selecting),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('while picking, every row offers a quick look', (tester) async {
    await pumpPicker(tester);

    expect(find.byTooltip('Bekijk de oefening'), findsOneWidget);
  });

  testWidgets('browsing the library it is not there', (tester) async {
    // The whole exercise page is one tap away there; a second way in would
    // only be in the way.
    await pumpPicker(tester, selecting: false);

    expect(find.byTooltip('Bekijk de oefening'), findsNothing);
  });

  testWidgets('it shows the name, the muscles and how it is done', (
    tester,
  ) async {
    await pumpPicker(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('Zet de stang op je schouders.'), findsOneWidget);
    expect(find.text('Barbell · halterstang'), findsOneWidget);
    expect(find.text('quadriceps (primair)'), findsOneWidget);
    expect(find.text('bilspieren'), findsOneWidget);
  });

  testWidgets('and nothing you did not come for', (tester) async {
    await pumpPicker(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    for (final absent in ['Records', 'Geschiedenis', 'Grafieken']) {
      expect(find.text(absent), findsNothing, reason: absent);
    }
  });

  testWidgets('the quick look does not pick the exercise', (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // No selection was made, so there is nothing to add.
    expect(find.textContaining('toevoegen'), findsNothing);
  });

  testWidgets('the way on to the full page is only offered where asked', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    // Not in the picker: leaving the list would lose what you had selected.
    expect(find.text('Records en grafieken'), findsNothing);
  });

  testWidgets('tapping the row still picks it', (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.text('Barbell Squat'));
    await tester.pumpAndSettle();

    expect(find.text('1 toevoegen'), findsOneWidget);
  });
}
