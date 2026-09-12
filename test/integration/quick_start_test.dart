import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/routines/domain/quick_start.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Starring a routine, and which stars reach the home screen.
///
/// You may star as many as you like. The launcher has room for three, so the
/// ones you actually do most get those places - a ranking the app already has
/// without asking you for it.
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

  /// A routine with [sessions] finished workouts behind it.
  Future<String> routine(
    String name, {
    bool favourite = false,
    int sessions = 0,
    int? lastPerformedAt,
  }) async {
    final id = await db.routinesDao.createRoutine(
      RoutineDraft(name: name, exercises: const []),
    );
    if (favourite) {
      await db.routinesDao.setFavourite(id, favourite: true);
    }
    for (var i = 0; i < sessions; i++) {
      final workoutId = await db.workoutsDao.startWorkout(
        name: name,
        routineId: id,
        defaultRestSeconds: 90,
      );
      await db.workoutsDao.finishWorkout(workoutId, discardPending: true);
    }
    if (lastPerformedAt != null) {
      await db.routinesDao.markPerformed(id, lastPerformedAt);
    }
    return id;
  }

  Future<List<String>> favouriteNames({int limit = 3}) async {
    final rows = await db.routinesDao.favouritesByUse(limit: limit);
    return rows.map((r) => r.name).toList();
  }

  group('the star', () {
    test('goes on and off', () async {
      final id = await routine('Push');

      expect((await db.routinesDao.getRoutine(id))!.isFavourite, isFalse);
      await db.routinesDao.setFavourite(id, favourite: true);
      expect((await db.routinesDao.getRoutine(id))!.isFavourite, isTrue);
      await db.routinesDao.setFavourite(id, favourite: false);
      expect((await db.routinesDao.getRoutine(id))!.isFavourite, isFalse);
    });

    test('only starred routines are in the running', () async {
      await routine('Push', favourite: true);
      await routine('Pull', sessions: 99);

      expect(await favouriteNames(), ['Push']);
    });
  });

  group('which three reach the home screen', () {
    test('the ones you do most often', () async {
      await routine('Zelden', favourite: true, sessions: 1);
      await routine('Vaak', favourite: true, sessions: 9);
      await routine('Soms', favourite: true, sessions: 4);

      expect(await favouriteNames(), ['Vaak', 'Soms', 'Zelden']);
    });

    test('more than three stars still gives three', () async {
      for (var i = 0; i < 5; i++) {
        await routine('R$i', favourite: true, sessions: i);
      }

      final names = await favouriteNames();
      expect(names, hasLength(3));
      expect(names, ['R4', 'R3', 'R2']);
    });

    test('never done yet is not a reason to be left out', () async {
      await routine('Nieuw', favourite: true);

      expect(await favouriteNames(), ['Nieuw']);
    });

    test('a tie goes to the one done most recently', () async {
      await routine('Ouder', favourite: true, lastPerformedAt: 1000);
      await routine('Recenter', favourite: true, lastPerformedAt: 5000);

      expect(await favouriteNames(), ['Recenter', 'Ouder']);
    });

    test('an unfinished session does not count as use', () async {
      await routine('Pull', favourite: true, sessions: 1);
      final id = await routine('Push', favourite: true);
      // Started and left open: only one session may run at a time, so this
      // one goes last.
      await db.workoutsDao.startWorkout(
        name: 'Push',
        routineId: id,
        defaultRestSeconds: 90,
      );

      expect(await favouriteNames(), [
        'Pull',
        'Push',
      ], reason: 'een lopende sessie heb je nog niet gedaan');
    });

    test('the list follows a star going on', () async {
      final id = await routine('Push');
      expect(await favouriteNames(), isEmpty);

      await db.routinesDao.setFavourite(id, favourite: true);

      expect(await favouriteNames(), ['Push']);
    });

    test('deleting a favourite takes it off', () async {
      final id = await routine('Push', favourite: true);

      await db.routinesDao.deleteRoutine(id);

      expect(await favouriteNames(), isEmpty);
    });
  });

  group('what the launcher is handed', () {
    RoutineRow row(String id, String name) => RoutineRow(
      id: id,
      name: name,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      isFavourite: true,
      scheduledDays: 0,
    );

    test('one entry per routine, in the order given', () {
      final items = quickStartItems([row('a', 'Push'), row('b', 'Pull')]);

      expect(items.map((i) => i.title), ['Push', 'Pull']);
      expect(items.map((i) => i.type), ['routine:a', 'routine:b']);
    });

    test('never more than the launcher has room for', () {
      final items = quickStartItems([
        for (var i = 0; i < 6; i++) row('r$i', 'R$i'),
      ]);

      expect(items, hasLength(kQuickStartSlots));
    });

    test('a tap names the routine back', () {
      expect(routineIdFromQuickStart(quickStartType('abc')), 'abc');
    });

    test('and anything else is not one of ours', () {
      expect(routineIdFromQuickStart('something_else'), isNull);
      expect(routineIdFromQuickStart('routine:'), isNull);
    });
  });
}
