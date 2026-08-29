/// The warm-up ladder for a one-rep-max attempt.
///
/// Pure Dart, no Flutter import: the whole thing is arithmetic over the
/// available plates, and it is the part that has to be right.
library;

import 'dart:math' as math;

import '../../../core/calc/plates.dart';

/// How many warm-up sets a ladder may have.
const int kMinPrWarmupSets = 2;
const int kMaxPrWarmupSets = 8;
const int kDefaultPrWarmupSets = 4;

/// Where the ladder starts and ends, as a share of the target.
const double _lowestPercentage = 0.40;
const double _highestPercentage = 0.90;

/// With only two warm-ups, 40% straight to 90% is too big a jump to be useful,
/// so the ladder is pulled inwards. This is the one case the brief pins down
/// explicitly; see docs/DECISIONS.md.
const double _twoSetLowPercentage = 0.50;
const double _twoSetHighPercentage = 0.80;

/// Rest after the attempt itself.
const int kAttemptRestSeconds = 300;

/// A single rung of the ladder.
class PrRampSet {
  const PrRampSet({
    required this.percentage,
    required this.weightKg,
    required this.reps,
    required this.restSeconds,
    required this.isAttempt,
    required this.plates,
  });

  /// Share of the target this set was derived from, 0..1.
  final double percentage;

  /// Rounded to something the available plates can actually make.
  final double weightKg;

  final int reps;
  final int restSeconds;

  /// True for the single set that is the actual attempt.
  final bool isAttempt;

  /// What to hang on the bar, per side.
  final PlateSolution plates;
}

/// A complete attempt: the warm-ups plus the attempt itself.
class PrRamp {
  const PrRamp({
    required this.targetKg,
    required this.barKg,
    required this.platesKg,
    required this.sets,
  });

  final double targetKg;
  final double barKg;
  final List<double> platesKg;

  /// Warm-ups in order, with the attempt last.
  final List<PrRampSet> sets;

  List<PrRampSet> get warmups =>
      sets.where((s) => !s.isAttempt).toList(growable: false);

  PrRampSet get attempt => sets.firstWhere((s) => s.isAttempt);

  int get warmupCount => sets.length - 1;

  /// The weight the attempt actually lands on, which can differ from
  /// [targetKg] when the plates cannot make it exactly.
  double get achievedTargetKg => attempt.weightKg;
}

/// Builds the ladder up to [targetKg].
///
/// Returns null when the target is not loadable at all - below the empty bar -
/// rather than handing back a ladder that cannot be performed.
PrRamp? buildPrRamp({
  required double targetKg,
  int warmupSets = kDefaultPrWarmupSets,
  double barKg = kDefaultBarWeightKg,
  List<double> platesKg = kDefaultPlatesKg,
}) {
  if (targetKg <= 0) return null;
  if (targetKg < barKg) return null;

  final count = warmupSets.clamp(kMinPrWarmupSets, kMaxPrWarmupSets);
  final available = platesKg.where((p) => p > 0).toList();

  final low = count == 2 ? _twoSetLowPercentage : _lowestPercentage;
  final high = count == 2 ? _twoSetHighPercentage : _highestPercentage;

  PrRampSet build(double percentage, {required bool isAttempt}) {
    final weight = isAttempt
        ? nearestAchievableWeightKg(
            targetKg: targetKg,
            barKg: barKg,
            availablePlatesKg: available,
          )
        : nearestAchievableWeightKg(
            targetKg: targetKg * percentage,
            barKg: barKg,
            availablePlatesKg: available,
          );

    final reps = isAttempt ? 1 : repsForPercentage(percentage);

    return PrRampSet(
      percentage: percentage,
      weightKg: weight,
      reps: reps,
      restSeconds: isAttempt ? kAttemptRestSeconds : restForReps(reps),
      isAttempt: isAttempt,
      plates: calculatePlates(
        targetKg: weight,
        barKg: barKg,
        availablePlatesKg: available,
      ),
    );
  }

  final sets = <PrRampSet>[
    for (var i = 0; i < count; i++)
      build(
        count == 1 ? low : low + (high - low) * (i / (count - 1)),
        isAttempt: false,
      ),
    build(1, isAttempt: true),
  ];

  return PrRamp(
    targetKg: targetKg,
    barKg: barKg,
    platesKg: available,
    sets: sets,
  );
}

/// Reps drop from five at the bottom of the ladder to one from 80% up.
///
/// Between those, they come down linearly and are floored, which is what
/// reproduces the 5 / 3 / 2 / 1 of a four set ladder.
int repsForPercentage(double percentage) {
  if (percentage >= 0.80) return 1;
  final scaled = 5 - 3 * (percentage - 0.40) / 0.40;
  return scaled.floor().clamp(1, 5);
}

/// Rest grows as the reps come down.
///
/// Driving rest off the reps rather than off the percentage is what makes a
/// four set ladder come out at 90 / 120 / 180 / 240 seconds, and it keeps the
/// rests sensible for every other length as well.
int restForReps(int reps) => switch (reps) {
  >= 4 => 90,
  3 => 120,
  2 => 180,
  _ => 240,
};

/// The next target to offer after a successful attempt: one plate step up.
///
/// A "step" is the smallest plate on both sides, because that is the smallest
/// change you can actually make to a loaded bar.
double nextTargetAfterSuccess({
  required double achievedKg,
  List<double> platesKg = kDefaultPlatesKg,
}) {
  final available = platesKg.where((p) => p > 0);
  if (available.isEmpty) return achievedKg;
  return achievedKg + available.reduce(math.min) * 2;
}

/// The back-off single offered after a failed attempt: 95% of the previous
/// best, rounded onto the bar.
double backoffAfterFailure({
  required double previousBestKg,
  double barKg = kDefaultBarWeightKg,
  List<double> platesKg = kDefaultPlatesKg,
}) {
  return nearestAchievableWeightKg(
    targetKg: previousBestKg * 0.95,
    barKg: barKg,
    availablePlatesKg: platesKg,
  );
}

/// How far the target sits above the current estimate, as a share.
///
/// Above [kBigJumpThreshold] the UI says so; it never blocks anything.
double jumpOverEstimate({
  required double targetKg,
  required double estimatedOneRmKg,
}) {
  if (estimatedOneRmKg <= 0) return 0;
  return (targetKg - estimatedOneRmKg) / estimatedOneRmKg;
}

/// Five percent over the estimate is where a jump stops being routine.
const double kBigJumpThreshold = 0.05;

/// Sessions inside this window count as recent enough to affect an attempt.
const Duration kFatigueWindow = Duration(hours: 48);
