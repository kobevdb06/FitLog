import 'package:fitlog/core/calc/plates.dart';
import 'package:fitlog/core/calc/warmup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateWarmupSets', () {
    test('produces four sets with the fixed rep scheme', () {
      final sets = calculateWarmupSets(workWeightKg: 100);
      expect(sets, hasLength(4));
      expect(sets.map((s) => s.reps), [5, 3, 2, 1]);
      expect(sets.map((s) => s.percentage), [0.40, 0.60, 0.80, 0.90]);
    });

    test('rounds every weight to something that can be loaded', () {
      final sets = calculateWarmupSets(workWeightKg: 100);
      // 40 -> 40, 60 -> 60, 80 -> 80, 90 -> 90; all exact on a 20 kg bar.
      expect(sets.map((s) => s.weightKg), [40, 60, 80, 90]);

      for (final s in sets) {
        final solution = calculatePlates(targetKg: s.weightKg);
        expect(solution.isExact, isTrue, reason: '${s.weightKg} kg');
      }
    });

    test('snaps awkward percentages onto the plate grid', () {
      final sets = calculateWarmupSets(workWeightKg: 87.5);
      // 35 -> 35, 52.5 -> 52.5, 70 -> 70, and 78.75 sits exactly between
      // 77.5 and 80, where the calculator rounds down.
      expect(sets[0].weightKg, closeTo(35, 0.001));
      expect(sets[1].weightKg, closeTo(52.5, 0.001));
      expect(sets[2].weightKg, closeTo(70, 0.001));
      expect(sets[3].weightKg, closeTo(77.5, 0.001));
    });

    test('never proposes less than the bar', () {
      final sets = calculateWarmupSets(workWeightKg: 30);
      for (final s in sets) {
        expect(s.weightKg, greaterThanOrEqualTo(20));
      }
    });

    test('returns nothing without a working weight', () {
      expect(calculateWarmupSets(workWeightKg: 0), isEmpty);
      expect(calculateWarmupSets(workWeightKg: -10), isEmpty);
    });

    test('honours a custom bar and plate set', () {
      final sets = calculateWarmupSets(
        workWeightKg: 60,
        barKg: 10,
        availablePlatesKg: const [10, 5, 2.5],
      );
      expect(sets, hasLength(4));
      for (final s in sets) {
        expect(s.weightKg, greaterThanOrEqualTo(10));
      }
    });
  });
}
