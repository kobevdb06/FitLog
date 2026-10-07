import 'package:fitlog/core/calc/milestones.dart';
import 'package:fitlog/core/calc/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Milestones on Profiel, and the streak they count.
void main() {
  group('de langste reeks', () {
    // Mondays, so the weeks are plain to read.
    DateTime week(int n) => DateTime(2026, 1, 5).add(Duration(days: 7 * n));

    test('ook als ze voorbij is', () {
      // Five weeks in a row, a gap, then two.
      final dates = [
        for (final n in [0, 1, 2, 3, 4, 7, 8])
          week(n).add(const Duration(days: 2)),
      ];
      expect(longestStreakWeeks(dates), 5);
      // Today the current streak has long ended; the longest has not.
      expect(computeStreak(dates, now: DateTime(2026, 6, 1)).weeks, 0);
    });

    test('meerdere trainingen in een week tellen als een week', () {
      expect(
        longestStreakWeeks([week(0), week(0).add(const Duration(days: 3))]),
        1,
      );
    });

    test('niets is nul', () {
      expect(longestStreakWeeks(const []), 0);
    });

    test('over de overgang naar zomertijd heen', () {
      // 30 March 2026: the first Monday after the clocks went forward.
      final dates = [DateTime(2026, 3, 25), DateTime(2026, 3, 31)];
      expect(longestStreakWeeks(dates), 2);
    });
  });

  group('een mijlpaal', () {
    Milestone workouts(int count) => milestonesFor(
      workouts: count,
      longestStreakWeeks: 0,
      volumeKg: 0,
      records: 0,
    ).first;

    test('weet welke stap de volgende is, en hoe ver je bent', () {
      final m = workouts(37);
      expect(m.kind, MilestoneKind.workouts);
      expect(m.reached, 3);
      expect(m.next, 50);
      expect(m.remaining, 13);
      expect(m.progress, closeTo(0.74, 0.001));
    });

    test('nog niets: de eerste stap is de volgende', () {
      final m = workouts(0);
      expect(m.reached, 0);
      expect(m.next, 1);
      expect(m.progress, 0);
    });

    test('alles behaald: geen volgende, vol', () {
      final m = workouts(800);
      expect(m.complete, isTrue);
      expect(m.next, isNull);
      expect(m.progress, 1);
      expect(m.remaining, 0);
    });

    test('vier soorten, in vaste volgorde', () {
      final all = milestonesFor(
        workouts: 12,
        longestStreakWeeks: 5,
        volumeKg: 123456,
        records: 9,
      );
      expect(all.map((m) => m.kind), MilestoneKind.values);
      expect(all[1].next, 12);
      expect(all[2].reached, 2);
      expect(all[3].remaining, 1);
    });
  });
}
