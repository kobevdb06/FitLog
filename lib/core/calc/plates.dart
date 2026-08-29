import 'dart:math' as math;

// The plate calculator.
//
// Everything here is in kilograms; the display layer converts. The
// distribution is a plain greedy pass from the heaviest plate down, which is
// what a lifter does at the rack and what the brief asks for.

/// The default plate inventory, per side, heaviest first.
const List<double> kDefaultPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25];

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

  @override
  bool operator ==(Object other) =>
      other is PlateStack &&
      (other.weightKg - weightKg).abs() < _epsilon &&
      other.count == count;

  @override
  int get hashCode => Object.hash(weightKg.round(), count);
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

  return PlateSolution(
    targetKg: targetKg,
    barKg: barKg,
    perSide: stacks,
    achievedKg: barKg + perSideWeight * 2,
  );
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
