import 'package:fitlog/core/calc/calendar.dart';
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/calc/streak.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Days counted on the calendar, across the nights the clocks change
/// (DECISIONS 268).
///
/// In Belgium the clocks went forward in the night of 28 to 29 March 2026:
/// that Sunday had 23 hours, and a difference in hours came out a day
/// short. These fail in a zone with the switch, as on the machine they were
/// written on; in UTC every day has 24 hours and they pass either way.
void main() {
  test('a day apart is one day, also over the short Sunday', () {
    expect(
      calendarDays(DateTime(2026, 3, 29, 10), DateTime(2026, 3, 30, 9)),
      1,
    );
    expect(calendarDays(DateTime(2026, 3, 29, 23), DateTime(2026, 3, 30)), 1);
    expect(
      calendarDays(DateTime(2026, 3, 28, 12), DateTime(2026, 3, 30, 1)),
      2,
    );
    // And over the long one in October.
    expect(
      calendarDays(DateTime(2026, 10, 25, 1), DateTime(2026, 10, 26, 0, 30)),
      1,
    );
    expect(calendarDays(DateTime(2026, 3, 30, 9), DateTime(2026, 3, 29)), -1);
  });

  test('the dashboard says yesterday, not today', () {
    expect(
      Formatters.relativeDay(
        DateTime(2026, 3, 29, 10),
        now: DateTime(2026, 3, 30, 9),
      ),
      'Gisteren',
    );
    expect(
      computeStreak([
        DateTime(2026, 3, 29, 10),
      ], now: DateTime(2026, 3, 30, 9)).daysSinceLast,
      1,
    );
  });

  test('half past midnight after the short Sunday belongs to that Sunday', () {
    expect(trainingDay(DateTime(2026, 3, 30, 0, 30)), DateTime(2026, 3, 29));
    expect(trainingDay(DateTime(2026, 10, 26, 0, 30)), DateTime(2026, 10, 25));
  });

  test('the Monday of the week is a Monday, at midnight', () {
    expect(startOfWeek(DateTime(2026, 3, 29, 12)), DateTime(2026, 3, 23));
    expect(startOfWeek(DateTime(2026, 4, 1, 1)), DateTime(2026, 3, 30));
    expect(startOfWeek(DateTime(2026, 10, 25, 23)), DateTime(2026, 10, 19));
  });
}
