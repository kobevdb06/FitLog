import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/seeder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('the bundled catalogue holds more than 800 exercises', () async {
    final seeded = await ExerciseSeeder(db).seedIfNeeded();
    expect(seeded, greaterThan(800));
    expect(await db.exercisesDao.countExercises(), greaterThan(800));
  });

  test('seeding runs only once', () async {
    final seeder = ExerciseSeeder(db);
    final first = await seeder.seedIfNeeded();
    final second = await seeder.seedIfNeeded();

    expect(first, greaterThan(800));
    expect(second, 0);
    expect(await db.exercisesDao.countExercises(), first);
    expect((await db.settingsDao.getSettings()).exercisesSeeded, isTrue);
  });

  group('a correction to the catalogue', () {
    /// The plank, as it was typed before holds were recognised.
    Future<ExerciseRow> plank() async => (await db.exercisesDao.getExercises(
      const ExerciseFilter(query: 'Plank'),
    )).firstWhere((e) => e.name == 'Plank');

    test('a hold is logged in seconds, not in reps', () async {
      await ExerciseSeeder(db).seedIfNeeded();

      expect(
        ExerciseCategory.fromWire((await plank()).category),
        ExerciseCategory.duration,
      );
    });

    test('reaches a database that was seeded before it', () async {
      final seeder = ExerciseSeeder(db);
      await seeder.seedIfNeeded();

      // Put the database back the way an older install left it: the plank
      // typed as a body-weight exercise, and no catalogue version recorded.
      await db.exercisesDao.updateExercise(
        (await plank()).id,
        const ExercisesTableCompanion(category: Value('bodyweight')),
      );
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(seedVersion: Value(0)),
      );

      final changed = await seeder.refreshIfNeeded();

      expect(changed, greaterThan(0));
      expect((await plank()).category, 'duration');
      expect((await db.settingsDao.getSettings()).seedVersion, kSeedVersion);
    });

    test('runs only once', () async {
      final seeder = ExerciseSeeder(db);
      await seeder.seedIfNeeded();
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(seedVersion: Value(0)),
      );

      expect(await seeder.refreshIfNeeded(), 0, reason: 'niets te corrigeren');
      expect(await seeder.refreshIfNeeded(), 0);
    });

    test('leaves a type the user picked themselves alone', () async {
      final seeder = ExerciseSeeder(db);
      await seeder.seedIfNeeded();

      // You decided the plank is a body-weight exercise after all.
      await db.exercisesDao.setCategory(
        (await plank()).id,
        ExerciseCategory.bodyweight,
      );
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(seedVersion: Value(0)),
      );

      await seeder.refreshIfNeeded();

      expect(
        (await plank()).category,
        'bodyweight',
        reason: 'de catalogus overschrijft jouw keuze niet',
      );
    });

    test('leaves an exercise the user made alone', () async {
      final seeder = ExerciseSeeder(db);
      await seeder.seedIfNeeded();

      await db.exercisesDao.insertExercise(
        ExercisesTableCompanion.insert(
          id: 'mine-1',
          name: 'Mijn plank',
          primaryMuscle: 'buik',
          category: 'bodyweight',
          createdAt: 0,
          isCustom: const Value(true),
        ),
      );
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(seedVersion: Value(0)),
      );

      await seeder.refreshIfNeeded();

      final mine = (await db.exercisesDao.getExercises(
        const ExerciseFilter(customOnly: true),
      )).single;
      expect(mine.category, 'bodyweight');
    });
  });

  test('muscle groups and equipment are in Dutch', () async {
    await ExerciseSeeder(db).seedIfNeeded();

    final muscles = await db.exercisesDao.distinctPrimaryMuscles();
    expect(muscles, contains('borst'));
    expect(muscles, contains('schouders'));
    expect(muscles, contains('bilspieren'));
    expect(muscles, isNot(contains('chest')));
    expect(muscles, isNot(contains('shoulders')));

    final equipment = await db.exercisesDao.distinctEquipment();
    expect(equipment, contains('halterstang'));
    expect(equipment, contains('lichaamsgewicht'));
    expect(equipment, isNot(contains('barbell')));
  });

  test('exercise names stay in English', () async {
    await ExerciseSeeder(db).seedIfNeeded();
    final results = await db.exercisesDao.getExercises(
      const ExerciseFilter(query: 'Barbell Bench Press'),
    );
    expect(results, isNotEmpty);
  });

  test('every seeded exercise has a valid category', () async {
    await ExerciseSeeder(db).seedIfNeeded();
    final all = await db.exercisesDao.getExercises();
    final valid = ExerciseCategory.values.map((c) => c.wire).toSet();
    for (final e in all) {
      expect(valid, contains(e.category), reason: e.name);
      expect(e.primaryMuscle, isNotEmpty);
      expect(e.isCustom, isFalse);
    }
  });

  test('search and filters narrow the catalogue', () async {
    await ExerciseSeeder(db).seedIfNeeded();

    final squats = await db.exercisesDao.getExercises(
      const ExerciseFilter(query: 'squat'),
    );
    expect(squats, isNotEmpty);
    for (final e in squats) {
      expect(e.name.toLowerCase(), contains('squat'));
    }

    final chest = await db.exercisesDao.getExercises(
      const ExerciseFilter(muscles: {'borst'}),
    );
    expect(chest, isNotEmpty);
    final total = await db.exercisesDao.countExercises();
    expect(chest.length, lessThan(total));

    final barbellChest = await db.exercisesDao.getExercises(
      const ExerciseFilter(muscles: {'borst'}, categories: {'barbell'}),
    );
    expect(barbellChest, isNotEmpty);
    expect(barbellChest.length, lessThanOrEqualTo(chest.length));
    for (final e in barbellChest) {
      expect(e.category, 'barbell');
    }
  });

  test(
    'a missing asset surfaces as an error rather than an empty seed',
    () async {
      expect(
        () =>
            ExerciseSeeder(db).seedIfNeeded(assetKey: 'assets/data/nope.json'),
        throwsA(isA<FlutterError>()),
      );
    },
  );
}
