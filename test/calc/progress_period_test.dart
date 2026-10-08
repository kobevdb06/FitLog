import 'package:fitlog/core/calc/progress_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday 8 October 2026, in the afternoon.
  final now = DateTime(2026, 10, 8, 15);

  group('bucketStarts', () {
    test('vier weken: deze week en de drie ervoor, vanaf maandag', () {
      expect(ProgressPeriod.fourWeeks.bucketStarts(now), [
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
      ]);
    });

    test('drie maanden: dertien weken', () {
      final starts = ProgressPeriod.threeMonths.bucketStarts(now);
      expect(starts, hasLength(13));
      expect(starts.first, DateTime(2026, 7, 13));
      expect(starts.last, DateTime(2026, 10, 5));
    });

    test('een jaar: twaalf maanden, de lopende als laatste', () {
      final starts = ProgressPeriod.year.bucketStarts(now);
      expect(starts, hasLength(12));
      expect(starts.first, DateTime(2025, 11));
      expect(starts.last, DateTime(2026, 10));
    });

    test('elke week begint om middernacht, ook over de zomertijd heen', () {
      // Summer time ends on 25 October 2026 and starts on 29 March 2026.
      for (final at in [DateTime(2026, 11, 12, 9), DateTime(2026, 4, 9, 9)]) {
        for (final start in ProgressPeriod.threeMonths.bucketStarts(at)) {
          expect(start.hour, 0, reason: '$start');
          expect(start.weekday, DateTime.monday, reason: '$start');
        }
      }
    });
  });

  test('bucketOf legt een dag in zijn week, of in zijn maand', () {
    final friday = DateTime(2026, 10, 2, 19);
    expect(ProgressPeriod.fourWeeks.bucketOf(friday), DateTime(2026, 9, 28));
    expect(ProgressPeriod.year.bucketOf(friday), DateTime(2026, 10));
  });

  test('weeksUpTo telt het deel van deze week dat voorbij is mee', () {
    // From Monday 14 September, midnight, to Thursday 8 October, 15:00.
    expect(
      ProgressPeriod.fourWeeks.weeksUpTo(now),
      closeTo((24 + 15 / 24) / 7, 1e-9),
    );
  });
}
