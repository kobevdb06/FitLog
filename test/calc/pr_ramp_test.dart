import 'package:fitlog/core/calc/plates.dart';
import 'package:fitlog/features/workout/domain/pr_ramp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('four sets, the default', () {
    late PrRamp ramp;

    setUp(() {
      ramp = buildPrRamp(targetKg: 120, warmupSets: 4)!;
    });

    test('gives four warm-ups plus the attempt', () {
      expect(ramp.sets, hasLength(5));
      expect(ramp.warmupCount, 4);
      expect(ramp.warmups, hasLength(4));
      expect(ramp.attempt.isAttempt, isTrue);
      expect(ramp.sets.last.isAttempt, isTrue);
    });

    test('runs from 40% to 90% and then the target', () {
      expect(
        ramp.sets.map((s) => (s.percentage * 100).round()),
        [40, 57, 73, 90, 100],
      );
    });

    test('matches the rep scheme from the brief', () {
      expect(ramp.sets.map((s) => s.reps), [5, 3, 2, 1, 1]);
    });

    test('matches the rest scheme from the brief', () {
      expect(ramp.sets.map((s) => s.restSeconds), [90, 120, 180, 240, 300]);
    });

    test('every weight can actually be loaded', () {
      for (final set in ramp.sets) {
        expect(
          set.plates.isExact,
          isTrue,
          reason: '${set.weightKg} kg zou exact moeten passen',
        );
        expect(set.plates.achievedKg, closeTo(set.weightKg, 0.001));
      }
    });

    test('the weights climb towards the target', () {
      final weights = ramp.sets.map((s) => s.weightKg).toList();
      for (var i = 1; i < weights.length; i++) {
        expect(weights[i], greaterThanOrEqualTo(weights[i - 1]));
      }
      expect(weights.last, 120);
    });

    test('every set knows its plates per side', () {
      // 90% of 120 is 108, which is not on the 2.5 kg grid, so it rounds.
      final ninety = ramp.sets[3];
      expect(ninety.weightKg, closeTo(107.5, 0.001));
      expect(ninety.plates.perSide, isNotEmpty);
      expect(ninety.plates.plateWeightPerSideKg, closeTo(43.75, 0.001));
    });
  });

  group('two sets', () {
    test('pulls the ladder inwards to 50% and 80%', () {
      final ramp = buildPrRamp(targetKg: 100, warmupSets: 2)!;

      expect(ramp.sets, hasLength(3));
      expect(
        ramp.sets.map((s) => (s.percentage * 100).round()),
        [50, 80, 100],
      );
      expect(ramp.sets.map((s) => s.reps), [4, 1, 1]);
      expect(ramp.warmups.first.weightKg, 50);
      expect(ramp.warmups.last.weightKg, 80);
    });
  });

  group('eight sets', () {
    late PrRamp ramp;

    setUp(() {
      ramp = buildPrRamp(targetKg: 140, warmupSets: 8)!;
    });

    test('keeps the same ends, finer in between', () {
      expect(ramp.sets, hasLength(9));
      expect((ramp.sets.first.percentage * 100).round(), 40);
      expect((ramp.warmups.last.percentage * 100).round(), 90);
    });

    test('reps never go up as the bar gets heavier', () {
      final reps = ramp.warmups.map((s) => s.reps).toList();
      for (var i = 1; i < reps.length; i++) {
        expect(reps[i], lessThanOrEqualTo(reps[i - 1]));
      }
      expect(reps.first, 5);
      expect(reps.last, 1);
    });

    test('rest never goes down as the bar gets heavier', () {
      final rests = ramp.warmups.map((s) => s.restSeconds).toList();
      for (var i = 1; i < rests.length; i++) {
        expect(rests[i], greaterThanOrEqualTo(rests[i - 1]));
      }
      expect(rests.first, 90);
      expect(rests.last, 240);
    });
  });

  group('rounding onto the bar', () {
    test('a target that does not fit lands on the nearest loadable weight', () {
      final ramp = buildPrRamp(targetKg: 63.7)!;

      // 63.7 is not loadable; 62.5 and 65 are.
      expect(ramp.achievedTargetKg, anyOf(62.5, 65.0));
      expect(ramp.attempt.plates.isExact, isTrue);
    });

    test('a coarse plate set still produces a loadable ladder', () {
      final ramp = buildPrRamp(
        targetKg: 100,
        platesKg: const [20, 10],
      );
      expect(ramp, isNotNull);
      for (final set in ramp!.sets) {
        expect(set.plates.isExact, isTrue, reason: '${set.weightKg}');
      }
    });

    test('a 15 kg bar shifts the whole ladder', () {
      final ramp = buildPrRamp(targetKg: 100, barKg: 15)!;

      expect(ramp.barKg, 15);
      for (final set in ramp.sets) {
        expect(set.weightKg, greaterThanOrEqualTo(15));
        expect(set.plates.barKg, 15);
        expect(set.plates.isExact, isTrue);
      }
      expect(ramp.achievedTargetKg, 100);
    });

    test('never proposes less than the bar', () {
      final ramp = buildPrRamp(targetKg: 25, barKg: 20)!;
      for (final set in ramp.sets) {
        expect(set.weightKg, greaterThanOrEqualTo(20));
      }
    });
  });

  group('refusing impossible targets', () {
    test('a target below the bar is refused', () {
      expect(buildPrRamp(targetKg: 15, barKg: 20), isNull);
      expect(buildPrRamp(targetKg: 19.99, barKg: 20), isNull);
    });

    test('a zero or negative target is refused', () {
      expect(buildPrRamp(targetKg: 0), isNull);
      expect(buildPrRamp(targetKg: -50), isNull);
    });

    test('a target exactly on the bar is allowed', () {
      final ramp = buildPrRamp(targetKg: 20, barKg: 20);
      expect(ramp, isNotNull);
      expect(ramp!.achievedTargetKg, 20);
    });
  });

  group('the warm-up count is clamped', () {
    test('below two becomes two', () {
      expect(buildPrRamp(targetKg: 100, warmupSets: 0)!.warmupCount, 2);
      expect(buildPrRamp(targetKg: 100, warmupSets: 1)!.warmupCount, 2);
    });

    test('above eight becomes eight', () {
      expect(buildPrRamp(targetKg: 100, warmupSets: 20)!.warmupCount, 8);
    });

    test('every length in between is honoured', () {
      for (var n = 2; n <= 8; n++) {
        final ramp = buildPrRamp(targetKg: 100, warmupSets: n)!;
        expect(ramp.warmupCount, n);
        expect(ramp.sets, hasLength(n + 1));
      }
    });
  });

  group('reps and rest helpers', () {
    test('reps come down with the percentage', () {
      expect(repsForPercentage(0.40), 5);
      expect(repsForPercentage(0.50), 4);
      expect(repsForPercentage(0.57), 3);
      expect(repsForPercentage(0.73), 2);
      expect(repsForPercentage(0.80), 1);
      expect(repsForPercentage(0.95), 1);
    });

    test('rest goes up as the reps come down', () {
      expect(restForReps(5), 90);
      expect(restForReps(4), 90);
      expect(restForReps(3), 120);
      expect(restForReps(2), 180);
      expect(restForReps(1), 240);
    });
  });

  group('what comes after the attempt', () {
    test('success offers one plate step up', () {
      expect(nextTargetAfterSuccess(achievedKg: 120), 122.5);
      expect(
        nextTargetAfterSuccess(achievedKg: 120, platesKg: const [20, 10, 5]),
        130,
      );
    });

    test('failure offers a back-off single at 95%', () {
      // 95% of 120 is 114, which rounds onto the bar.
      final backoff = backoffAfterFailure(previousBestKg: 120);
      expect(backoff, closeTo(115, 0.001));
      expect(calculatePlates(targetKg: backoff).isExact, isTrue);
    });
  });

  group('how big a jump this is', () {
    test('reports the share above the estimate', () {
      expect(
        jumpOverEstimate(targetKg: 105, estimatedOneRmKg: 100),
        closeTo(0.05, 0.0001),
      );
      expect(
        jumpOverEstimate(targetKg: 120, estimatedOneRmKg: 100),
        closeTo(0.20, 0.0001),
      );
    });

    test('a target at or under the estimate is not a jump', () {
      expect(
        jumpOverEstimate(targetKg: 95, estimatedOneRmKg: 100),
        lessThan(0),
      );
    });

    test('without an estimate there is nothing to compare against', () {
      expect(jumpOverEstimate(targetKg: 100, estimatedOneRmKg: 0), 0);
    });

    test('the threshold is what the warning uses', () {
      expect(
        jumpOverEstimate(targetKg: 106, estimatedOneRmKg: 100),
        greaterThan(kBigJumpThreshold),
      );
      expect(
        jumpOverEstimate(targetKg: 104, estimatedOneRmKg: 100),
        lessThan(kBigJumpThreshold),
      );
    });
  });
}
