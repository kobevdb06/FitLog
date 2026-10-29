import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The line under an exercise's name: its type, and its equipment where that
/// says something more.
///
/// An exercise on a machine showed "Machine · machine".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() => db.close());

  var next = 0;

  Future<String> lineFor(String category, String? equipment) async {
    final id = 'ex-${next++}';
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: id,
            name: 'Oefening',
            primaryMuscle: 'buik',
            category: category,
            equipment: Value(equipment),
            createdAt: 0,
          ),
        );
    return (await db.exercisesDao.getById(id))!.categoryAndEquipment;
  }

  test('both, where the equipment adds something', () async {
    expect(await lineFor('barbell', 'halterstang'), 'Barbell · halterstang');
  });

  test('once, where they are the same word', () async {
    expect(await lineFor('machine', 'machine'), 'Machine');
    expect(await lineFor('cable', 'Kabel'), 'Kabel');
  });

  test('the type alone, without equipment', () async {
    expect(await lineFor('cardio', null), 'Cardio');
  });
}
