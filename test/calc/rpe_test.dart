import 'package:fitlog/core/calc/rpe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading a one-rep max off a set you did not take to failure.
void main() {
  group('the table', () {
    test('a single rep at RPE 10 is the maximum itself', () {
      expect(percentOfMax(reps: 1, rpe: 10), 100.0);
    });

    test('five reps at RPE 8 is 81,1 percent', () {
      // The worked example: index (5-1)*2 + (10-8)*2 = 12.
      expect(percentOfMax(reps: 5, rpe: 8), 81.1);
    });

    test('one more rep and one more in reserve cost the same', () {
      // Which is the diagonal the table is built on.
      expect(percentOfMax(reps: 6, rpe: 9), percentOfMax(reps: 5, rpe: 8));
    });

    test('halves land on their own entry', () {
      final at8 = percentOfMax(reps: 5, rpe: 8)!;
      final at85 = percentOfMax(reps: 5, rpe: 8.5)!;
      final at9 = percentOfMax(reps: 5, rpe: 9)!;

      expect(at85, greaterThan(at8));
      expect(at85, lessThan(at9));
    });
  });

  group('what the table refuses', () {
    test('an RPE below six says nothing', () {
      expect(percentOfMax(reps: 5, rpe: 5.5), isNull);
    });

    test('past twelve reps it would be extrapolation', () {
      expect(percentOfMax(reps: 12, rpe: 6), isNotNull, reason: 'nog net');
      expect(percentOfMax(reps: 13, rpe: 10), isNull);
    });

    test('and it does not clamp at the edges', () {
      // Clamping would answer confidently where the table has nothing to say.
      expect(percentOfMax(reps: 20, rpe: 10), isNull);
      expect(percentOfMax(reps: 0, rpe: 8), isNull);
      expect(percentOfMax(reps: 5, rpe: 11), isNull);
    });
  });

  group('the estimate', () {
    test('100 kg for 5 at RPE 8 puts the max near 123', () {
      expect(e1RmFromRpe(weightKg: 100, reps: 5, rpe: 8), closeTo(123.3, 0.1));
    });

    test('a single all-out rep is the max', () {
      expect(e1RmFromRpe(weightKg: 140, reps: 1, rpe: 10), 140);
    });

    test('the same weight felt easier means a higher max', () {
      final hard = e1RmFromRpe(weightKg: 100, reps: 5, rpe: 9)!;
      final easy = e1RmFromRpe(weightKg: 100, reps: 5, rpe: 7)!;

      expect(easy, greaterThan(hard));
    });

    test('it rises with the weight', () {
      final light = e1RmFromRpe(weightKg: 100, reps: 5, rpe: 8)!;
      final heavy = e1RmFromRpe(weightKg: 110, reps: 5, rpe: 8)!;

      expect(heavy, greaterThan(light));
    });

    test('anything missing gives nothing, never a zero', () {
      expect(e1RmFromRpe(weightKg: null, reps: 5, rpe: 8), isNull);
      expect(e1RmFromRpe(weightKg: 100, reps: null, rpe: 8), isNull);
      expect(e1RmFromRpe(weightKg: 100, reps: 5, rpe: null), isNull);
      expect(e1RmFromRpe(weightKg: 0, reps: 5, rpe: 8), isNull);
    });
  });

  group('how much a set is believed', () {
    test('close to failure is believed most', () {
      expect(rpeConfidence(rpe: 9, reps: 5), 1.0);
      expect(rpeConfidence(rpe: 6, reps: 5), lessThan(1.0));
    });

    test('a long set is believed less than a short one', () {
      expect(
        rpeConfidence(rpe: 9, reps: 12),
        lessThan(rpeConfidence(rpe: 9, reps: 5)),
      );
    });

    test('outside the table it counts for nothing', () {
      expect(rpeConfidence(rpe: 5, reps: 5), 0);
      expect(rpeConfidence(rpe: 9, reps: 20), 0);
    });
  });

  group('a whole session', () {
    ScoredSet set(double weight, int reps, double? rpe) =>
        ScoredSet(weightKg: weight, reps: reps, rpe: rpe);

    test('one set is its own estimate', () {
      expect(
        sessionE1Rm([set(100, 5, 8)]),
        closeTo(e1RmFromRpe(weightKg: 100, reps: 5, rpe: 8)!, 0.001),
      );
    });

    test('unscored sets are left out, not counted as zero', () {
      final scored = sessionE1Rm([set(100, 5, 8)])!;
      final mixed = sessionE1Rm([set(100, 5, 8), set(60, 10, null)])!;

      expect(mixed, closeTo(scored, 0.001));
    });

    test('the set that is believed more pulls harder', () {
      // Same two estimates, but one comes from a set near failure.
      final trusted = e1RmFromRpe(weightKg: 100, reps: 5, rpe: 9)!;
      final guessed = e1RmFromRpe(weightKg: 60, reps: 10, rpe: 6)!;
      final together = sessionE1Rm([set(100, 5, 9), set(60, 10, 6)])!;

      final flat = (trusted + guessed) / 2;
      expect((together - trusted).abs(), lessThan((flat - trusted).abs()));
    });

    test('a session with nothing usable has no estimate', () {
      expect(sessionE1Rm([set(100, 20, 9), set(100, 5, 5)]), isNull);
      expect(sessionE1Rm(const []), isNull);
    });
  });
}
