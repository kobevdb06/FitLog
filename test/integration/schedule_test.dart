import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Planning a routine on the days you actually do it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> routine(String name) => db.routinesDao.createRoutine(
    RoutineDraft(name: name, exercises: const []),
  );

  Future<WeekdaySet> daysOf(String id) async =>
      WeekdaySet((await db.routinesDao.getRoutine(id))!.scheduledDays);

  group('what is written down', () {
    test('a routine starts out unplanned', () async {
      expect(await daysOf(await routine('Push')), WeekdaySet.none);
    });

    test('the days you pick come back', () async {
      final id = await routine('Push');
      final days = WeekdaySet.of([DateTime.monday, DateTime.thursday]);

      await db.routinesDao.setScheduledDays(id, days);

      expect(await daysOf(id), days);
    });

    test('and can be taken away again', () async {
      final id = await routine('Push');
      await db.routinesDao.setScheduledDays(
        id,
        WeekdaySet.of([DateTime.monday]),
      );

      await db.routinesDao.setScheduledDays(id, WeekdaySet.none);

      expect(await daysOf(id), WeekdaySet.none);
    });

    test('editing the routine does not unplan it', () async {
      // The editor saves the whole routine, which is why the schedule is its
      // own write rather than a field on the draft.
      final id = await routine('Push');
      await db.routinesDao.setScheduledDays(
        id,
        WeekdaySet.of([DateTime.monday]),
      );

      await db.routinesDao.updateRoutine(
        id,
        const RoutineDraft(name: 'Push A', exercises: []),
      );

      expect((await db.routinesDao.getRoutine(id))!.name, 'Push A');
      expect(await daysOf(id), WeekdaySet.of([DateTime.monday]));
    });

    test('a duplicate does not inherit the schedule', () async {
      // Two routines on the same day is a thing you ask for, not something a
      // copy should decide for you.
      final id = await routine('Push');
      await db.routinesDao.setScheduledDays(
        id,
        WeekdaySet.of([DateTime.monday]),
      );

      final copy = await db.routinesDao.duplicateRoutine(id);

      expect(await daysOf(copy), WeekdaySet.none);
    });
  });

  group('what the Start tab reads', () {
    test('only the routines that are planned on something', () async {
      final push = await routine('Push');
      await routine('Losse oefeningen');
      await db.routinesDao.setScheduledDays(
        push,
        WeekdaySet.of([DateTime.monday]),
      );

      final planned = await db.routinesDao.watchScheduledRoutines().first;

      expect([for (final r in planned) r.name], ['Push']);
    });

    test('several routines on one day, in your own order', () async {
      final bench = await routine('Bench');
      final flyes = await routine('Flyes');
      final monday = WeekdaySet.of([DateTime.monday]);
      await db.routinesDao.setScheduledDays(bench, monday);
      await db.routinesDao.setScheduledDays(flyes, monday);

      final planned = await db.routinesDao.watchScheduledRoutines().first;

      expect([for (final r in planned) r.name], ['Bench', 'Flyes']);
    });

    test('planning one is enough to change what is read', () async {
      final stream = db.routinesDao.watchScheduledRoutines();
      final first = await stream.first;
      expect(first, isEmpty);

      final id = await routine('Push');
      await db.routinesDao.setScheduledDays(
        id,
        WeekdaySet.of([DateTime.wednesday]),
      );

      expect(await stream.first, hasLength(1));
    });
  });
}
