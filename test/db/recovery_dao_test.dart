import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What you say about your muscles, as it is stored.
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  final morning = DateTime(2026, 3, 3, 8);
  final evening = DateTime(2026, 3, 3, 21);
  final tomorrow = DateTime(2026, 3, 4, 8);

  Future<List<SorenessCheckRow>> all() =>
      db.select(db.sorenessChecksTable).get();

  test('een antwoord per spier per dag', () async {
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.sore,
      at: morning,
    );
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.stiff,
      at: evening,
    );

    // Dezelfde dag: het nieuwe vervangt het oude, ook het tijdstip.
    final rows = await all();
    expect(rows.single.level, SorenessLevel.stiff.wire);
    expect(rows.single.checkedAt, evening.millisecondsSinceEpoch);
  });

  test('maar elke dag telt apart, en elke spier ook', () async {
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.sore,
      at: morning,
    );
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.fresh,
      at: tomorrow,
    );
    await db.recoveryDao.setSoreness(
      'hamstrings',
      SorenessLevel.stiff,
      at: morning,
    );

    expect(await all(), hasLength(3));
  });

  test('terugnemen haalt alleen die dag weg', () async {
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.sore,
      at: morning,
    );
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.fresh,
      at: tomorrow,
    );

    await db.recoveryDao.clearSoreness('quadriceps', at: evening);

    final rows = await all();
    expect(rows.single.level, SorenessLevel.fresh.wire);
  });

  test('en lezen begint waar je het vraagt', () async {
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.sore,
      at: morning,
    );
    await db.recoveryDao.setSoreness(
      'quadriceps',
      SorenessLevel.fresh,
      at: tomorrow,
    );

    final since = await db.recoveryDao.watchSorenessSince(evening).first;
    expect(since.single.level, SorenessLevel.fresh.wire);
  });
}
