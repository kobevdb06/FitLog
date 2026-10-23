import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:flutter_test/flutter_test.dart';

/// The weeks of a schema: calendar weeks, a guide for the days, and a week
/// that only moves the sessions a little.
void main() {
  group('the first Monday', () {
    test('this week until Wednesday', () {
      expect(
        firstPlanMonday(DateTime(2026, 10, 19, 9)),
        DateTime(2026, 10, 19),
      );
      expect(
        firstPlanMonday(DateTime(2026, 10, 21, 22)),
        DateTime(2026, 10, 19),
      );
    });

    test('next week from Thursday: three days are not a week', () {
      expect(
        firstPlanMonday(DateTime(2026, 10, 22, 7)),
        DateTime(2026, 10, 26),
      );
      expect(
        firstPlanMonday(DateTime(2026, 10, 25, 23)),
        DateTime(2026, 10, 26),
      );
    });
  });

  group('which week it is', () {
    final start = DateTime(2026, 10, 19);

    test('none before it began, then one a Monday', () {
      expect(planWeekAt(start, DateTime(2026, 10, 18, 23)), 0);
      expect(planWeekAt(start, DateTime(2026, 10, 19)), 1);
      expect(planWeekAt(start, DateTime(2026, 10, 25, 23, 59)), 1);
      expect(planWeekAt(start, DateTime(2026, 10, 26)), 2);
    });

    test('a week with a change of the clocks is still seven days', () {
      // The clocks go back on 25 October 2026 in Europe.
      expect(planWeekAt(start, DateTime(2026, 11, 1, 23)), 2);
      expect(planWeekAt(start, DateTime(2026, 11, 2, 0, 30)), 3);
      expect(planWeekStart(start, 3), DateTime(2026, 11, 2));
    });
  });

  group('a week of the coach', () {
    test('is read back as it was written', () {
      const weeks = [
        PlanWeek(),
        PlanWeek(sets: 1, note: 'een set meer'),
        PlanWeek(sets: 1, reps: -2),
        PlanWeek(kind: PlanWeekKind.deload),
      ];
      expect(decodePlanWeeks(encodePlanWeeks(weeks)), weeks);
    });

    test('moves a session a few sets or repetitions at most', () {
      final week = PlanWeek.fromJson({'sets': 10, 'reps': -8});
      expect(week.sets, kPlanWeekMaxStep);
      expect(week.reps, -kPlanWeekMaxStep);
    });

    test('a damaged value is no weeks, not an error', () {
      expect(decodePlanWeeks('{nope'), isEmpty);
      expect(decodePlanWeeks('{"kind":"build"}'), isEmpty);
      expect(decodePlanWeeks(null), isEmpty);
    });
  });

  group('how a week stands', () {
    test('the next is the first in order not done, whatever the day', () {
      const week = PlanWeekStanding(
        sessions: ['push', 'pull', 'legs'],
        done: {'pull'},
      );
      expect(week.next, 'push');
      expect(week.doneCount, 1);
      expect(week.missing, ['push', 'legs']);
      expect(week.complete, isFalse);
    });

    test('done when every session was', () {
      const week = PlanWeekStanding(
        sessions: ['push', 'pull'],
        done: {'push', 'pull'},
      );
      expect(week.next, isNull);
      expect(week.complete, isTrue);
    });
  });
}
