import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Muscle groups, kit and categories the app did not come with.
///
/// The pickers used to offer only what the bundled catalogue happened to
/// contain, so a group nothing used could not be chosen at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bench',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('spiergroepen', () {
    test('de catalogus levert wat ze zelf gebruikt', () async {
      expect(await db.exercisesDao.distinctPrimaryMuscles(), ['borst']);
    });

    test('een eigen groep komt erbij zonder dat iets hem gebruikt', () async {
      await db.exercisesDao.addCustomMuscle('serratus');

      expect(await db.exercisesDao.distinctPrimaryMuscles(), [
        'borst',
        'serratus',
      ]);
    });

    test('en blijft ook als de oefening die hem gebruikte weggaat', () async {
      // Precies het gat: afgeleid uit de catalogus verdween een groep zodra
      // niets hem meer gebruikte.
      await db.exercisesDao.addCustomMuscle('serratus');
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-pullover',
              name: 'Pullover',
              primaryMuscle: 'serratus',
              category: 'dumbbell',
              createdAt: 0,
            ),
          );
      await db.exercisesDao.setArchived('ex-pullover', archived: true);

      expect(
        await db.exercisesDao.distinctPrimaryMuscles(),
        contains('serratus'),
      );
    });

    test('tweemaal toevoegen geeft geen dubbele regel', () async {
      await db.exercisesDao.addCustomMuscle('serratus');
      await db.exercisesDao.addCustomMuscle('Serratus');

      expect(await db.exercisesDao.distinctPrimaryMuscles(), [
        'borst',
        'serratus',
      ]);
    });

    test('een groep die de catalogus al kent wordt niet verdubbeld', () async {
      await db.exercisesDao.addCustomMuscle('borst');

      expect(await db.exercisesDao.distinctPrimaryMuscles(), ['borst']);
    });

    test('weghalen kan, en dan is hij weg', () async {
      await db.exercisesDao.addCustomMuscle('serratus');
      await db.exercisesDao.removeCustomMuscle('serratus');

      expect(await db.exercisesDao.distinctPrimaryMuscles(), ['borst']);
    });
  });

  group('wat er nog aan hangt', () {
    test('telt de oefeningen die een groep gebruiken', () async {
      expect(await db.exercisesDao.exercisesUsingMuscle('borst'), 1);
      expect(await db.exercisesDao.exercisesUsingMuscle('serratus'), 0);
    });

    test('ook als tweede spier', () async {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-dip',
              name: 'Dip',
              primaryMuscle: 'triceps',
              secondaryMuscles: const Value('["borst","schouders"]'),
              category: 'bodyweight',
              createdAt: 0,
            ),
          );

      expect(await db.exercisesDao.exercisesUsingMuscle('borst'), 2);
    });
  });

  group('categorieën', () {
    test('een eigen categorie onthoudt waarmee ze rekent', () async {
      await db.exercisesDao.addCustomCategory('Slee', 'bodyweight');

      final own = await db.exercisesDao.customCategories();
      expect(own.single.name, 'Slee');
      expect(own.single.base, 'bodyweight');
    });

    test('een oefening erin blijft gelogd als haar basis', () async {
      // Dat is het hele punt: een naam van jezelf verandert niets aan wat een
      // set van je vraagt.
      await db.exercisesDao.addCustomCategory('Slee', 'duration');
      await db.exercisesDao.setCategory(
        'ex-bench',
        const CategoryChoice(ExerciseCategory.duration, 'Slee'),
      );

      final row = (await db.exercisesDao.getById('ex-bench'))!;
      expect(row.category, 'duration');
      expect(row.customCategory, 'Slee');
      expect(row.categoryChoice.base, ExerciseCategory.duration);
      expect(row.categoryLabel, 'Slee');
      expect(row.categoryChoice.base.hasDuration, isTrue);
    });

    test('en zonder eigen naam blijft het label van de app staan', () async {
      final row = (await db.exercisesDao.getById('ex-bench'))!;
      expect(row.customCategory, isNull);
      expect(row.categoryLabel, ExerciseCategory.barbell.label);
    });

    test('filteren op een eigen categorie vraagt om die naam', () async {
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
      // Een oefening die toevallig hetzelfde gelogd wordt, maar niet van jou
      // heet.
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-plank',
              name: 'Plank',
              primaryMuscle: 'core',
              category: 'duration',
              createdAt: 0,
            ),
          );

      final own = await db.exercisesDao.getExercises(
        const ExerciseFilter(customCategories: {'Slee'}),
      );
      expect(own.map((e) => e.id), ['ex-sled']);

      // En op de ingebouwde categorie vind je ze allebei: zo worden ze
      // allebei gelogd.
      final both = await db.exercisesDao.getExercises(
        const ExerciseFilter(categories: {'duration'}),
      );
      expect(both.map((e) => e.id), ['ex-plank', 'ex-sled']);
    });

    test('zoeken vindt een oefening op de naam die jij gaf', () async {
      await db.exercisesDao.addCustomCategory('Slee', 'duration');
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-sled',
              name: 'Duwen',
              primaryMuscle: 'benen',
              category: 'duration',
              customCategory: const Value('Slee'),
              createdAt: 0,
            ),
          );

      final found = await db.exercisesDao.getExercises(
        const ExerciseFilter(query: 'slee'),
      );
      expect(found.map((e) => e.id), ['ex-sled']);
    });

    test('verwijderen mag pas als niets het nog gebruikt', () async {
      await db.exercisesDao.addCustomCategory('Slee', 'duration');
      await db.exercisesDao.setCategory(
        'ex-bench',
        const CategoryChoice(ExerciseCategory.duration, 'Slee'),
      );

      expect(await db.exercisesDao.exercisesUsingCategory('Slee'), 1);

      await db.exercisesDao.setCategory(
        'ex-bench',
        const CategoryChoice(ExerciseCategory.barbell),
      );

      expect(await db.exercisesDao.exercisesUsingCategory('Slee'), 0);
      await db.exercisesDao.removeCustomCategory('Slee');
      expect(await db.exercisesDao.customCategories(), isEmpty);
    });
  });

  group('materiaal', () {
    test('begint leeg en groeit mee', () async {
      expect(await db.exercisesDao.distinctEquipment(), isEmpty);

      await db.exercisesDao.addCustomEquipment('ringen');

      expect(await db.exercisesDao.distinctEquipment(), ['ringen']);
    });

    test('en telt wat het gebruikt', () async {
      await db.exercisesDao.addCustomEquipment('ringen');
      expect(await db.exercisesDao.exercisesUsingEquipment('ringen'), 0);
    });
  });
}
