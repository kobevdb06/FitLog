import 'package:fitlog/core/calc/plates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculatePlates', () {
    test('an empty bar needs no plates', () {
      final s = calculatePlates(targetKg: 20);
      expect(s.perSide, isEmpty);
      expect(s.achievedKg, 20);
      expect(s.isExact, isTrue);
    });

    test('loads 100 kg as 25 + 15 per side', () {
      final s = calculatePlates(targetKg: 100);
      expect(s.perSide, [const PlateStack(25, 1), const PlateStack(15, 1)]);
      expect(s.achievedKg, 100);
      expect(s.isExact, isTrue);
    });

    test('stacks several of the same plate', () {
      final s = calculatePlates(targetKg: 160);
      // 70 kg per side: 25 + 25 + 20
      expect(s.perSide, [const PlateStack(25, 2), const PlateStack(20, 1)]);
      expect(s.achievedKg, 160);
    });

    test('uses the small plates for a quarter kilo', () {
      final s = calculatePlates(targetKg: 62.5);
      // 21.25 per side: 20 + 1.25
      expect(s.perSide, [const PlateStack(20, 1), const PlateStack(1.25, 1)]);
      expect(s.achievedKg, closeTo(62.5, 0.001));
      expect(s.isExact, isTrue);
    });

    test('reports the gap when the target cannot be made exactly', () {
      final s = calculatePlates(targetKg: 63);
      expect(s.isExact, isFalse);
      expect(s.achievedKg, closeTo(62.5, 0.001));
      expect(s.differenceKg, closeTo(-0.5, 0.001));
    });

    test('a target below the bar loads nothing and says so', () {
      final s = calculatePlates(targetKg: 15);
      expect(s.isBelowBar, isTrue);
      expect(s.perSide, isEmpty);
      expect(s.achievedKg, 20);
      expect(s.differenceKg, 5);
    });

    test('honours a custom bar weight', () {
      final s = calculatePlates(targetKg: 60, barKg: 10);
      // 25 per side: 25
      expect(s.perSide, [const PlateStack(25, 1)]);
      expect(s.achievedKg, 60);
    });

    test('honours a reduced plate inventory', () {
      final s = calculatePlates(
        targetKg: 100,
        availablePlatesKg: const [20, 10],
      );
      // 40 per side: 20 + 20
      expect(s.perSide, [const PlateStack(20, 2)]);
      expect(s.achievedKg, 100);
    });

    test('falls short when the inventory cannot reach the target', () {
      final s = calculatePlates(
        targetKg: 100,
        availablePlatesKg: const [5],
      );
      expect(s.perSide, [const PlateStack(5, 8)]);
      expect(s.achievedKg, 100);

      final short = calculatePlates(
        targetKg: 101,
        availablePlatesKg: const [5],
      );
      expect(short.achievedKg, 100);
      expect(short.differenceKg, closeTo(-1, 0.001));
    });

    test('an empty inventory returns the bare bar', () {
      final s = calculatePlates(targetKg: 100, availablePlatesKg: const []);
      expect(s.perSide, isEmpty);
      expect(s.achievedKg, 20);
    });

    test('plate weight per side adds up', () {
      final s = calculatePlates(targetKg: 140);
      expect(s.plateWeightPerSideKg, closeTo(60, 0.001));
    });
  });

  group('nearestAchievableWeightKg', () {
    test('keeps an exact weight', () {
      expect(nearestAchievableWeightKg(targetKg: 100), 100);
    });

    test('rounds down when that is closer', () {
      expect(nearestAchievableWeightKg(targetKg: 101), closeTo(100, 0.001));
    });

    test('rounds up when that is closer', () {
      expect(nearestAchievableWeightKg(targetKg: 102), closeTo(102.5, 0.001));
    });

    test('never goes below the bar', () {
      expect(nearestAchievableWeightKg(targetKg: 5), 20);
    });
  });
}
