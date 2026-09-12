import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/dashboard/domain/today_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ladder the Start tab reads top down.
void main() {
  // A Wednesday, at an hour nobody argues about.
  final now = DateTime(2026, 9, 9, 18);

  RoutineRow routine(
    String name, {
    List<int> days = const [],
    bool favourite = false,
    DateTime? lastPerformed,
  }) => RoutineRow(
    id: name,
    name: name,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    lastPerformedAt: lastPerformed?.millisecondsSinceEpoch,
    isFavourite: favourite,
    scheduledDays: WeekdaySet.of(days).mask,
  );

  TodayPlan plan({
    List<RoutineRow> scheduled = const [],
    List<RoutineRow> favourites = const [],
    RoutineRow? suggested,
    DateTime? at,
  }) => buildTodayPlan(
    scheduled: scheduled,
    favourites: favourites,
    suggested: suggested,
    now: at ?? now,
  );

  group('what is on today', () {
    test('the routine planned on this weekday', () {
      final wednesday = routine('Pull', days: [DateTime.wednesday]);
      final result = plan(scheduled: [wednesday]);

      expect(result.kind, TodayPlanKind.scheduled);
      expect(result.routines.single.routine.name, 'Pull');
    });

    test('every routine on that day, not just the first', () {
      // The whole point of the schedule: a chest day holds all the chest work.
      final result = plan(
        scheduled: [
          routine('Bench', days: [DateTime.wednesday]),
          routine('Flyes', days: [DateTime.wednesday]),
          routine('Squat', days: [DateTime.monday]),
        ],
      );

      expect(
        [for (final p in result.routines) p.routine.name],
        ['Bench', 'Flyes'],
      );
    });

    test('a routine can sit on more than one day', () {
      final push = routine('Push', days: [DateTime.monday, DateTime.wednesday]);

      expect(plan(scheduled: [push]).kind, TodayPlanKind.scheduled);
      expect(
        plan(scheduled: [push], at: DateTime(2026, 9, 7, 18)).kind,
        TodayPlanKind.scheduled,
      );
    });

    test('the schedule wins from the stars', () {
      final result = plan(
        scheduled: [
          routine('Pull', days: [DateTime.wednesday]),
        ],
        favourites: [routine('Arms', favourite: true)],
      );

      expect(result.kind, TodayPlanKind.scheduled);
      expect(result.lead!.routine.name, 'Pull');
    });
  });

  group('what you have already done', () {
    test('a routine done this evening is marked, not offered again', () {
      final result = plan(
        scheduled: [
          routine(
            'Pull',
            days: [DateTime.wednesday],
            lastPerformed: DateTime(2026, 9, 9, 9),
          ),
        ],
      );

      expect(result.kind, TodayPlanKind.allDone);
      expect(result.routines.single.doneToday, isTrue);
    });

    test('yesterday does not count as today', () {
      final result = plan(
        scheduled: [
          routine(
            'Pull',
            days: [DateTime.wednesday],
            lastPerformed: DateTime(2026, 9, 8, 18),
          ),
        ],
      );

      expect(result.kind, TodayPlanKind.scheduled);
      expect(result.routines.single.doneToday, isFalse);
    });

    test('the big button goes to the one still to do', () {
      final result = plan(
        scheduled: [
          routine(
            'Bench',
            days: [DateTime.wednesday],
            lastPerformed: DateTime(2026, 9, 9, 9),
          ),
          routine('Flyes', days: [DateTime.wednesday]),
        ],
      );

      expect(result.kind, TodayPlanKind.scheduled);
      expect(result.lead!.routine.name, 'Flyes');
      expect([for (final p in result.rest) p.routine.name], ['Bench']);
    });

    test('with everything done the first one leads again', () {
      final result = plan(
        scheduled: [
          routine(
            'Bench',
            days: [DateTime.wednesday],
            lastPerformed: DateTime(2026, 9, 9, 9),
          ),
          routine(
            'Flyes',
            days: [DateTime.wednesday],
            lastPerformed: DateTime(2026, 9, 9, 10),
          ),
        ],
      );

      expect(result.kind, TodayPlanKind.allDone);
      expect(result.lead!.routine.name, 'Bench');
      expect(result.rest.length, 1);
    });
  });

  group('a day the schedule leaves empty', () {
    test('says so rather than reaching for something', () {
      final result = plan(
        scheduled: [
          routine('Squat', days: [DateTime.monday]),
        ],
      );

      expect(result.kind, TodayPlanKind.rest);
      expect(result.routines, isEmpty);
    });

    test('and says when the next one is', () {
      final result = plan(
        scheduled: [
          routine('Squat', days: [DateTime.thursday]),
        ],
      );

      expect(result.nextWeekday, DateTime.thursday);
      expect(result.daysUntilNext, 1);
      expect(result.nextRoutines.single.name, 'Squat');
    });

    test('looking past the end of the week to find it', () {
      final result = plan(
        scheduled: [
          routine('Squat', days: [DateTime.monday]),
        ],
      );

      expect(result.nextWeekday, DateTime.monday);
      expect(result.daysUntilNext, 5);
    });

    test('a rest day does not answer with itself', () {
      // Searching from today would find today a week out, which is true and
      // useless.
      final result = plan(
        scheduled: [
          routine('Squat', days: [DateTime.monday]),
        ],
        at: DateTime(2026, 9, 7, 18),
      );

      expect(result.kind, TodayPlanKind.scheduled);
      expect(result.nextWeekday, DateTime.monday);
      expect(result.daysUntilNext, DateTime.daysPerWeek);
    });

    test('the favourites do not override it', () {
      final result = plan(
        scheduled: [
          routine('Squat', days: [DateTime.monday]),
        ],
        favourites: [routine('Arms', favourite: true)],
      );

      expect(result.kind, TodayPlanKind.rest);
    });
  });

  group('with no schedule at all', () {
    test('the starred routines, in the order they were handed over', () {
      final result = plan(
        favourites: [
          routine('Arms', favourite: true),
          routine('Legs', favourite: true),
        ],
      );

      expect(result.kind, TodayPlanKind.favourites);
      expect(
        [for (final p in result.routines) p.routine.name],
        ['Arms', 'Legs'],
      );
    });

    test('nothing starred falls back to what the app always showed', () {
      // Without this rung a user with routines but no stars would go from a
      // filled card to an empty one.
      final result = plan(suggested: routine('Chest day 2'));

      expect(result.kind, TodayPlanKind.suggested);
      expect(result.lead!.routine.name, 'Chest day 2');
    });

    test('and with nothing at all the card has nothing to offer', () {
      expect(plan().kind, TodayPlanKind.none);
      expect(plan().lead, isNull);
    });
  });
}
