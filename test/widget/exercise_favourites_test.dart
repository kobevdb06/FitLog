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

/// Starring an exercise, and finding your starred ones back.
///
/// The catalogue has hundreds of exercises and most people do a dozen. A star
/// marks the dozen; a filter shows only them. The filter is not there until
/// there is something to filter on - a chip that can only ever produce an
/// empty list is clutter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  Future<void> add(String id, String name, {bool favourite = false}) => db
      .into(db.exercisesTable)
      .insert(
        ExercisesTableCompanion.insert(
          id: id,
          name: name,
          primaryMuscle: 'borst',
          category: 'barbell',
          createdAt: 0,
          isFavourite: Value(favourite),
        ),
      );

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
            withoutImages: {'ex-bench', 'ex-fly', 'ex-dip'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await add('ex-bench', 'Bench Press');
    await add('ex-fly', 'Cable Fly');
    await add('ex-dip', 'Dips');
  });

  tearDown(() => db.close());

  group('in de database', () {
    test('het filter toont alleen wat een ster heeft', () async {
      await db.exercisesDao.setFavourite('ex-fly', favourite: true);

      final starred = await db.exercisesDao.getExercises(
        const ExerciseFilter(favouritesOnly: true),
      );

      expect(starred.map((e) => e.id), ['ex-fly']);
    });

    test('en weet of er iets is om op te filteren', () async {
      final has = db.exercisesDao.watchHasFavourites();
      expect(await has.first, isFalse);

      await db.exercisesDao.setFavourite('ex-bench', favourite: true);
      expect(await db.exercisesDao.watchHasFavourites().first, isTrue);
    });

    test('een verborgen oefening telt daar niet voor', () async {
      // Een oefening die je verwijderde maar die in je geschiedenis staat,
      // blijft verborgen; haar ster zou een filter tonen dat niets oplevert.
      await db.exercisesDao.setFavourite('ex-dip', favourite: true);
      await db.exercisesDao.setArchived('ex-dip', archived: true);

      expect(await db.exercisesDao.watchHasFavourites().first, isFalse);
    });
  });

  group('in de catalogus', () {
    Future<void> pumpLibrary(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWithContainer(container, const ExerciseLibraryScreen()),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openFilters(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
    }

    Finder starOf(String name) => find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byTooltip('Als favoriet bewaren'),
    );

    testWidgets('zonder favorieten is er geen filter voor', (tester) async {
      await pumpLibrary(tester);
      await openFilters(tester);

      expect(find.widgetWithText(FilterChip, 'Eigen'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Favoriet'), findsNothing);
    });

    testWidgets('een ster zetten bewaart hem, en dan staat het filter er', (
      tester,
    ) async {
      await pumpLibrary(tester);
      await openFilters(tester);

      await tester.tap(starOf('Cable Fly'));
      await tester.pumpAndSettle();

      expect((await db.exercisesDao.getById('ex-fly'))!.isFavourite, isTrue);
      expect(find.widgetWithText(FilterChip, 'Favoriet'), findsOneWidget);
    });

    testWidgets('en het filter toont alleen je favorieten', (tester) async {
      await db.exercisesDao.setFavourite('ex-fly', favourite: true);
      await pumpLibrary(tester);
      await openFilters(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Favoriet'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Cable Fly'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Bench Press'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Dips'), findsNothing);
    });

    testWidgets('de laatste ster weghalen laat je niet vastzitten', (
      tester,
    ) async {
      // Met het filter aan en de laatste ster eraf zou het filter
      // verdwijnen en de lijst leeg blijven, zonder weg terug.
      await db.exercisesDao.setFavourite('ex-fly', favourite: true);
      await pumpLibrary(tester);
      await openFilters(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Favoriet'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Cable Fly'),
          matching: find.byTooltip('Uit je favorieten halen'),
        ),
      );
      await tester.pumpAndSettle();

      final chip = find.widgetWithText(FilterChip, 'Favoriet');
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();

      // Uit, en dan verdwijnt het pas: er is niets meer om op te filteren.
      expect(find.widgetWithText(ListTile, 'Bench Press'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Favoriet'), findsNothing);
    });

    testWidgets('bij het kiezen voor een routine werkt het filter ook', (
      tester,
    ) async {
      await db.exercisesDao.setFavourite('ex-bench', favourite: true);
      tester.view.physicalSize = const Size(1100, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithContainer(
          container,
          const ExerciseLibraryScreen(selectionMode: true),
        ),
      );
      await tester.pumpAndSettle();
      await openFilters(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Favoriet'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Bench Press'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Dips'), findsNothing);
    });
  });
}
