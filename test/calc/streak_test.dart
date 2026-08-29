import 'package:fitlog/core/calc/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday 26 August 2026.
  final now = DateTime(2026, 8, 26);

  group('startOfWeek', () {
    test('returns the Monday of that week', () {
      expect(startOfWeek(DateTime(2026, 8, 26)), DateTime(2026, 8, 24));
      expect(startOfWeek(DateTime(2026, 8, 24)), DateTime(2026, 8, 24));
      expect(startOfWeek(DateTime(2026, 8, 30)), DateTime(2026, 8, 24));
    });
  });

  group('computeStreak', () {
    test('is zero without workouts', () {
      final result = computeStreak(const [], now: now);
      expect(result.weeks, 0);
      expect(result.daysSinceLast, isNull);
      expect(result.isActive, isFalse);
    });

    test('counts the current week', () {
      final result = computeStreak([DateTime(2026, 8, 25)], now: now);
      expect(result.weeks, 1);
      expect(result.daysSinceLast, 1);
    });

    test('counts consecutive weeks', () {
      final result = computeStreak([
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 11),
      ], now: now);
      expect(result.weeks, 3);
    });

    test('several workouts in one week count once', () {
      final result = computeStreak([
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 26),
      ], now: now);
      expect(result.weeks, 1);
    });

    test('an empty current week does not break the streak yet', () {
      final result = computeStreak([
        DateTime(2026, 8, 21), // last week
        DateTime(2026, 8, 14),
      ], now: now);
      expect(result.weeks, 2);
      expect(result.daysSinceLast, 5);
    });

    test('a full empty week breaks the streak', () {
      final result = computeStreak([
        DateTime(2026, 8, 12), // two weeks ago
        DateTime(2026, 8, 5),
      ], now: now);
      expect(result.weeks, 0);
      expect(result.daysSinceLast, 14);
    });

    test('a gap in the middle only counts the recent run', () {
      final result = computeStreak([
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 18),
        // no workout in the week of 10 August
        DateTime(2026, 8, 4),
        DateTime(2026, 7, 28),
      ], now: now);
      expect(result.weeks, 2);
    });

    test('unsorted input gives the same answer', () {
      final result = computeStreak([
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 18),
      ], now: now);
      expect(result.weeks, 3);
      expect(result.daysSinceLast, 1);
    });
  });
}
