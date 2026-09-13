import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/settings/presentation/catalogue_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The screen where you add what the app did not come with.
///
/// A category is the odd one out: a muscle group or a piece of kit is just a
/// name, but a category decides what a set asks you for. So adding one asks
/// twice - what you call it, and which of the built-in eight it counts as.
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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithContainer(container, const CatalogueSettingsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('categories have a section of their own', (tester) async {
    await pumpScreen(tester);

    expect(find.text('CATEGORIEËN'), findsOneWidget);
    expect(find.text('Nog geen eigen categorieën.'), findsOneWidget);
    expect(find.text('Categorie toevoegen'), findsWidgets);
  });

  testWidgets('adding one asks for a name and for what it counts as', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Categorie toevoegen'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Slee');
    await tester.tap(find.widgetWithText(FilledButton, 'Opslaan'));
    await tester.pumpAndSettle();

    // The second question, which is the one that decides the set columns.
    expect(find.text('Waarmee reken je mee?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Tijd').last);
    await tester.pumpAndSettle();

    final saved = await db.exercisesDao.customCategories();
    expect(saved.single.name, 'Slee');
    expect(saved.single.base, 'duration');

    expect(find.text('Slee'), findsOneWidget);
    expect(find.text('Rekent als tijd'), findsOneWidget);
  });

  testWidgets('one that is still in use is not removed', (tester) async {
    await db.exercisesDao.addCustomCategory('Slee', 'duration');
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-sled',
            name: 'Sledepush',
            primaryMuscle: 'benen',
            category: 'duration',
            customCategory: const Value('Slee'),
            createdAt: 0,
          ),
        );
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    expect(
      find.text('Slee wordt nog door 1 oefening gebruikt.'),
      findsOneWidget,
    );
    expect(await db.exercisesDao.customCategories(), hasLength(1));
  });

  testWidgets('and one that is not, is', (tester) async {
    await db.exercisesDao.addCustomCategory('Slee', 'duration');
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Verwijderen'));
    await tester.pumpAndSettle();

    expect(await db.exercisesDao.customCategories(), isEmpty);
  });
}
