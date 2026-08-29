import 'package:fitlog/core/calc/one_rm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimatedOneRm', () {
    test('a single rep is the weight itself', () {
      expect(estimatedOneRm(weightKg: 140, reps: 1), 140);
    });

    test('applies Epley above one rep', () {
      // 100 * (1 + 5/30) = 116.666...
      expect(estimatedOneRm(weightKg: 100, reps: 5), closeTo(116.6667, 0.0001));
      expect(estimatedOneRm(weightKg: 60, reps: 10), closeTo(80, 0.0001));
    });

    test('returns null when the numbers are missing or useless', () {
      expect(estimatedOneRm(weightKg: null, reps: 5), isNull);
      expect(estimatedOneRm(weightKg: 100, reps: null), isNull);
      expect(estimatedOneRm(weightKg: 0, reps: 5), isNull);
      expect(estimatedOneRm(weightKg: 100, reps: 0), isNull);
      expect(estimatedOneRm(weightKg: -20, reps: 5), isNull);
    });

    test('grows with reps at the same weight', () {
      final five = estimatedOneRm(weightKg: 100, reps: 5)!;
      final eight = estimatedOneRm(weightKg: 100, reps: 8)!;
      expect(eight, greaterThan(five));
    });
  });

  group('isOneRmEstimateReliable', () {
    test('is true up to and including twelve reps', () {
      expect(isOneRmEstimateReliable(1), isTrue);
      expect(isOneRmEstimateReliable(12), isTrue);
    });

    test('is false above twelve reps', () {
      expect(isOneRmEstimateReliable(13), isFalse);
      expect(isOneRmEstimateReliable(20), isFalse);
    });

    test('is false without reps', () {
      expect(isOneRmEstimateReliable(null), isFalse);
      expect(isOneRmEstimateReliable(0), isFalse);
    });
  });
}
