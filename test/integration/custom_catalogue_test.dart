import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Muscle groups and kit the app did not come with.
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
