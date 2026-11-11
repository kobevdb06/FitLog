import 'dart:math' as math;

import 'units.dart';

// The plate calculator.
//
// Everything here is in kilograms; the display layer converts. The
// distribution is a plain greedy pass from the heaviest plate down, which is
// what a lifter does at the rack and what the brief asks for - and where that
// misses a load the plates can make, a search finds it (DECISIONS 275).

/// The default plate inventory, per side, heaviest first.
const List<double> kDefaultPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25];

/// The standard plate set for the unit you lift in, per side, heaviest
/// first, in kilograms like every weight here: a pound gym has 45, 35, 25,
/// 10, 5 and 2.5 lb plates, not kilo plates shown as 44.1 lb.
List<double> standardPlatesKg({required bool pounds}) => pounds
    ? [
        for (final lb in const [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]) lbToKg(lb),
      ]
    : kDefaultPlatesKg;

/// Whether two plates are the same plate, give or take the rounding of a
/// conversion.
bool samePlate(double a, double b) => (a - b).abs() < _epsilon;

/// The default barbell weight.
const double kDefaultBarWeightKg = 20;

/// Floating point slack. Plate weights come in quarters of a kilo, so a
/// tolerance of a gram is plenty and keeps 2.5 + 1.25 sums honest.
const double _epsilon = 0.001;

class PlateStack {
  const PlateStack(this.weightKg, this.count);

  final double weightKg;
  final int count;

  @override
  String toString() => '${count}x$weightKg';

  /// In grams: equal, and the same hash, for the same plate. Compared within
  /// a gram and hashed on the whole kilo, two equal plates either side of
  /// half a kilo had different hashes (DECISIONS 275).
  int get _grams => (weightKg * 1000).round();

  @override
  bool operator ==(Object other) =>
      other is PlateStack && other._grams == _grams && other.count == count;

  @override
  int get hashCode => Object.hash(_grams, count);
}

class PlateSolution {
  const PlateSolution({
    required this.targetKg,
    required this.barKg,
    required this.perSide,
    required this.achievedKg,
  });

  final double targetKg;
  final double barKg;

  /// Plates for one side of the bar, heaviest first.
  final List<PlateStack> perSide;

  /// The weight that the loaded bar actually reaches.
  final double achievedKg;

  /// `achieved - target`. Negative means the bar is lighter than asked for.
  double get differenceKg => achievedKg - targetKg;

  /// Whether the target can be hit exactly with the available plates.
  bool get isExact => differenceKg.abs() < _epsilon;

  /// The target is below the empty bar, so nothing can be loaded.
  bool get isBelowBar => targetKg < barKg - _epsilon;

  double get plateWeightPerSideKg =>
      perSide.fold(0.0, (sum, p) => sum + p.weightKg * p.count);
}

/// Distributes [targetKg] over the bar, greedily, heaviest plate first.
///
/// [availablePlatesKg] is treated as an unlimited supply of each listed size,
/// which matches a normal gym rack.
PlateSolution calculatePlates({
  required double targetKg,
  double barKg = kDefaultBarWeightKg,
  List<double> availablePlatesKg = kDefaultPlatesKg,
}) {
  final plates = availablePlatesKg.where((p) => p > 0).toList()
    ..sort((a, b) => b.compareTo(a));

  if (targetKg < barKg - _epsilon || plates.isEmpty) {
    return PlateSolution(
      targetKg: targetKg,
      barKg: barKg,
      perSide: const [],
      achievedKg: barKg,
    );
  }

  var remainingPerSide = (targetKg - barKg) / 2;
  final stacks = <PlateStack>[];

  for (final plate in plates) {
    if (remainingPerSide < plate - _epsilon) continue;
    final count = ((remainingPerSide + _epsilon) / plate).floor();
    if (count <= 0) continue;
    stacks.add(PlateStack(plate, count));
    remainingPerSide -= plate * count;
    if (remainingPerSide < _epsilon) break;
  }

  final perSideWeight = stacks.fold(
    0.0,
    (sum, s) => sum + s.weightKg * s.count,
  );

  final greedy = PlateSolution(
    targetKg: targetKg,
    barKg: barKg,
    perSide: stacks,
    achievedKg: barKg + perSideWeight * 2,
  );
  if (greedy.isExact) return greedy;

  // Heaviest first is right for a standard set. With your own plates it can
  // miss what they make: 25 and 20, and 40 a side, came out at 25 and 70 kg
  // in all (DECISIONS 275).
  final searched = _closestBelow((targetKg - barKg) / 2, plates);
  if (searched == null) return greedy;
  final searchedWeight = searched.fold(
    0.0,
    (sum, s) => sum + s.weightKg * s.count,
  );
  if (searchedWeight <= perSideWeight + _epsilon) return greedy;
  return PlateSolution(
    targetKg: targetKg,
    barKg: barKg,
    perSide: searched,
    achievedKg: barKg + searchedWeight * 2,
  );
}

/// The heaviest load of [plates] on one side that stays at or under
/// [perSideKg], with the fewest plates, heaviest first. Null where the
/// numbers are too large to search.
List<PlateStack>? _closestBelow(double perSideKg, List<double> plates) {
  // In grams, on the finest step the plates share.
  final grams = [for (final p in plates) (p * 1000).round()];
  var unit = grams.first;
  int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
  for (final g in grams) {
    unit = gcd(unit, g);
  }
  if (unit <= 0) return null;
  final target = ((perSideKg * 1000).round() + 1) ~/ unit;
  if (target <= 0 || target > 100000) return null;
  final sizes = [for (final g in grams) g ~/ unit];

  // fewest[w] = the fewest plates that make exactly w units; -1 = cannot.
  final fewest = List<int>.filled(target + 1, -1);
  final last = List<int>.filled(target + 1, -1);
  fewest[0] = 0;
  for (var w = 1; w <= target; w++) {
    for (var i = 0; i < sizes.length; i++) {
      final from = w - sizes[i];
      if (from < 0 || fewest[from] < 0) continue;
      final count = fewest[from] + 1;
      if (fewest[w] < 0 || count < fewest[w]) {
        fewest[w] = count;
        last[w] = i;
      }
    }
  }

  var w = target;
  while (w > 0 && fewest[w] < 0) {
    w--;
  }
  if (w == 0) return const [];
  final counts = List<int>.filled(sizes.length, 0);
  while (w > 0) {
    final i = last[w];
    counts[i]++;
    w -= sizes[i];
  }
  return [
    for (var i = 0; i < plates.length; i++)
      if (counts[i] > 0) PlateStack(plates[i], counts[i]),
  ];
}

/// The loadable weight closest to [targetKg].
///
/// The greedy pass never overshoots, so the candidate above the target is the
/// greedy result plus one of the smallest plates on each side.
double nearestAchievableWeightKg({
  required double targetKg,
  double barKg = kDefaultBarWeightKg,
  List<double> availablePlatesKg = kDefaultPlatesKg,
}) {
  final plates = availablePlatesKg.where((p) => p > 0).toList();
  if (plates.isEmpty) return barKg;

  final below = calculatePlates(
    targetKg: targetKg,
    barKg: barKg,
    availablePlatesKg: plates,
  ).achievedKg;

  if (targetKg <= barKg + _epsilon) return barKg;
  if ((below - targetKg).abs() < _epsilon) return below;

  final smallest = plates.reduce(math.min);
  final above = below + smallest * 2;

  return (targetKg - below) <= (above - targetKg) ? below : above;
}
