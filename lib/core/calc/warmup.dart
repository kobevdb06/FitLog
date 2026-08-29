import 'plates.dart';

/// One proposed warm-up set.
class WarmupSet {
  const WarmupSet({
    required this.percentage,
    required this.weightKg,
    required this.reps,
  });

  /// The share of the working weight this set was derived from, 0..1.
  final double percentage;

  /// Rounded to a weight that can actually be loaded on the bar.
  final double weightKg;

  final int reps;
}

/// The fixed ramp used by the warm-up calculator: 40% x 5, 60% x 3,
/// 80% x 2, 90% x 1.
const List<({double percentage, int reps})> kWarmupRamp = [
  (percentage: 0.40, reps: 5),
  (percentage: 0.60, reps: 3),
  (percentage: 0.80, reps: 2),
  (percentage: 0.90, reps: 1),
];

/// Builds the four warm-up sets leading up to [workWeightKg].
///
/// Every weight is snapped to the nearest weight the available plates can
/// actually make, so the suggestion is loadable as printed.
List<WarmupSet> calculateWarmupSets({
  required double workWeightKg,
  double barKg = kDefaultBarWeightKg,
  List<double> availablePlatesKg = kDefaultPlatesKg,
}) {
  if (workWeightKg <= 0) return const [];

  return kWarmupRamp
      .map(
        (step) => WarmupSet(
          percentage: step.percentage,
          weightKg: nearestAchievableWeightKg(
            targetKg: workWeightKg * step.percentage,
            barKg: barKg,
            availablePlatesKg: availablePlatesKg,
          ),
          reps: step.reps,
        ),
      )
      .toList(growable: false);
}
