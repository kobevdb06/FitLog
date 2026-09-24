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

  group('nachten', () {
    final asleep = DateTime(2026, 3, 2, 23, 30);
    final woke = DateTime(2026, 3, 3, 7);

    test('een nacht per ochtend: opnieuw invullen verbetert hem', () async {
      await db.recoveryDao.setSleep(fellAsleepAt: asleep, wokeAt: woke);
      await db.recoveryDao.setSleep(
        fellAsleepAt: asleep.add(const Duration(minutes: 30)),
        wokeAt: woke,
        deepMinutes: 80,
      );

      final rows = await db.select(db.sleepEntriesTable).get();
      expect(
        rows.single.fellAsleepAt,
        asleep.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );
      expect(rows.single.deepMinutes, 80);
      // Niet ingevuld blijft niet ingevuld, geen nul.
      expect(rows.single.lightMinutes, isNull);
    });

    test('en verwijderen haalt alleen die ochtend weg', () async {
      await db.recoveryDao.setSleep(fellAsleepAt: asleep, wokeAt: woke);
      await db.recoveryDao.setSleep(
        fellAsleepAt: asleep.add(const Duration(days: 1)),
        wokeAt: woke.add(const Duration(days: 1)),
      );

      await db.recoveryDao.clearSleep(woke);

      final rows = await db.select(db.sleepEntriesTable).get();
      expect(
        rows.single.wokeAt,
        woke.add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
    });
  });

  group('glazen', () {
    final day = DateTime(2026, 3, 3, 21, 15);

    test('een rij per dag, met het aantal', () async {
      await db.recoveryDao.setDrinks(day, 3);
      await db.recoveryDao.setDrinks(day.add(const Duration(hours: 1)), 5);

      final rows = await db.select(db.drinkDaysTable).get();
      expect(rows.single.drinks, 5);
      // Opgeslagen als het begin van die dag, niet als het uur.
      expect(rows.single.day, DateTime(2026, 3, 3).millisecondsSinceEpoch);
    });

    test('en nul is geen rij', () async {
      // Niets ingevuld en niets gedronken zeggen hetzelfde tegen de
      // schatting, dus wordt nul ook niet bewaard.
      await db.recoveryDao.setDrinks(day, 3);
      await db.recoveryDao.setDrinks(day, 0);

      expect(await db.select(db.drinkDaysTable).get(), isEmpty);
    });
  });
}
