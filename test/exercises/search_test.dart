import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Searching the catalogue.
///
/// Looking for the kit is looking for the exercise: type "barbell" and you
/// want everything you do with one, not only what carries the word in its
/// name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();

    for (final (id, name, equipment, category) in const [
      // Its name says barbell, its type says barbell.
      ('ex-bench', 'Barbell Bench Press', 'halterstang', 'barbell'),
      // Neither its name nor its equipment says barbell; its type does.
      ('ex-squat', 'Front Squat', 'halterstang', 'barbell'),
      ('ex-curl', 'Kabel curl', 'kabel', 'cable'),
      ('ex-plank', 'Plank', 'lichaamsgewicht', 'duration'),
      ('ex-row', 'Roeien', null, 'cardio'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: 'borst',
              equipment: Value(equipment),
              category: category,
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> search(String query) async {
    final rows = await db.exercisesDao.getExercises(
      ExerciseFilter(query: query),
    );
    return rows.map((e) => e.name).toList();
  }

  test('the name still matches', () async {
    expect(await search('bench'), ['Barbell Bench Press']);
  });

  test('the kit matches, even when the name says nothing', () async {
    expect(await search('barbell'), ['Barbell Bench Press', 'Front Squat']);
  });

  test('the Dutch name of the kit matches too', () async {
    expect(await search('halterstang'), ['Barbell Bench Press', 'Front Squat']);
  });

  test('so does the Dutch label of the type', () async {
    // The type is stored as "duration"; the app calls it "Tijd".
    expect(await search('tijd'), ['Plank']);
  });

  test('an exercise without equipment is still found by its type', () async {
    expect(await search('cardio'), ['Roeien']);
  });

  test('nothing matching is still nothing', () async {
    expect(await search('kettlebell'), isEmpty);
  });

  test('a term that is both a name and a type finds both', () async {
    // "kabel" is the equipment of the curl and the label of its type.
    expect(await search('kabel'), ['Kabel curl']);
  });
}
