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

  test('a missing asset surfaces as an error rather than an empty seed',
      () async {
    expect(
      () => ExerciseSeeder(db).seedIfNeeded(assetKey: 'assets/data/nope.json'),
      throwsA(isA<FlutterError>()),
    );
  });
}
