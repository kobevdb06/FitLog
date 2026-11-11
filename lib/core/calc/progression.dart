/// What to try today on an exercise, from what you did last time.
///
/// Double progression: first the repetitions, then the weight. Once every
/// working set reaches the target - and did not take everything you had -
/// the weight goes up by one step and the target starts over; until then the
/// weight stays and the repetitions are what to chase.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

import '../db/enums.dart';
import 'units.dart';

/// Above this RPE the sets took close to everything: the same again, until
/// it feels lighter, rather than more.
const double kHintMaxRpeToProgress = 8.5;

/// How much longer a hold is to try.
const int kHintHoldStepSeconds = 5;

/// The step for a weight when the exercise's own history does not show one.
///
/// A barbell takes the smallest plate on each side; a pair of dumbbells
/// usually goes up by two kilos, a stack by two and a half - and in a gym
/// that counts in [pounds], both by five pounds: two kilos on 50 lb showed
/// 54,5 lb (DECISIONS 274).
double defaultWeightStep(
  ExerciseCategory category, {
  List<double> platesKg = const [],
  bool pounds = false,
}) {
  if (category == ExerciseCategory.barbell) {
    final plates = platesKg.where((p) => p > 0).toList()..sort();
    if (plates.isNotEmpty) return plates.first * 2;
    return pounds ? 5 * kKgPerLb : 2.5;
  }
  if (pounds) return 5 * kKgPerLb;
  if (category == ExerciseCategory.dumbbell) return 2;
  return 2.5;
}

/// The step you take on an exercise, read off the weights you have used on
/// it: of the gaps between two of them, the one whose steps hold the most
/// of those weights, and of those the largest. It was the smallest gap: 60,
/// 62,5 and 65 with one 61 among them made a step of a kilo (DECISIONS 274).
///
/// Null with fewer than three different weights: one gap says too little,
/// and 60 to 70 once is not a habit of ten-kilo steps.
double? learnedWeightStep(Iterable<double> weightsKg) {
  final sorted = [
    for (final w in weightsKg)
      if (w > 0) w,
  ]..sort();
  // Weights less than half a kilo apart are one weight: 60 and 60.25 is a
  // rounding or a slip of the finger, not a step of a quarter.
  final kept = <double>[];
  for (final w in sorted) {
    if (kept.isEmpty || w - kept.last >= 0.5) kept.add(w);
  }
  if (kept.length < 3) return null;

  final gaps = <double>{
    for (var i = 1; i < kept.length; i++)
      (((kept[i] - kept[i - 1]) * 1000).round()) / 1000,
  };
  bool onGrid(double weight, double step) {
    final steps = (weight - kept.first) / step;
    return (steps - steps.round()).abs() < 1e-6;
  }

  double? best;
  var bestHeld = 0;
  for (final gap in gaps) {
    final held = kept.where((w) => onGrid(w, gap)).length;
    if (held > bestHeld || (held == bestHeld && gap > best!)) {
      best = gap;
      bestHeld = held;
    }
  }
  return best;
}

/// One working set of the last time, as far as the hint goes.
class HintSet {
  const HintSet({this.weightKg, this.reps, this.durationSeconds, this.rpe});

  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? rpe;
}

/// What the hint says to do.
enum HintKind {
  /// Every set reached the target: one step heavier.
  heavier,

  /// Not every set reached it: the same weight, and the target to chase.
  sameWeight,

  /// Every set reached it, but at an RPE that left little: the same again.
  repeat,

  /// No weight: every set reached the best one, so one repetition more.
  moreReps,

  /// No weight, and the sets were uneven: bring them all up to the best.
  evenReps,

  /// A hold: a few seconds longer.
  longer,
}

/// What to try today, and what it is based on.
class ProgressionHint {
  const ProgressionHint({
    required this.kind,
    required this.last,
    this.weightKg,
    this.reps,
    this.seconds,
    this.lastWeightKg,
    this.lastRpe,
  });

  final HintKind kind;

  /// What to put in the open sets. Null where the hint says nothing about it.
  final double? weightKg;
  final int? reps;
  final int? seconds;

  /// The working sets of last time, in order.
  final List<HintSet> last;

  /// The weight those were done at - the heaviest, where they differed.
  final double? lastWeightKg;

  /// The highest RPE among them, when it was filled in.
  final double? lastRpe;
}

/// The hint for an exercise of [category], from [last] - the completed
/// working sets of the last time it was done.
///
/// [targetReps] is what the routine asks for; without one, the best of last
/// time is the target. [step] is how much heavier one step is; see
/// [learnedWeightStep] and [defaultWeightStep].
///
/// Null when there is nothing to go on, and for assisted work and cardio,
/// where more is not simply better.
ProgressionHint? progressionHint({
  required ExerciseCategory category,
  required List<HintSet> last,
  int? targetReps,
  required double step,
}) {
  if (last.isEmpty) return null;

  if (category == ExerciseCategory.duration) {
    final longest = last
        .map((s) => s.durationSeconds ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (longest <= 0) return null;
    return ProgressionHint(
      kind: HintKind.longer,
      last: last,
      seconds: longest + kHintHoldStepSeconds,
    );
  }

  if (category == ExerciseCategory.bodyweight) {
    final reps = [
      for (final s in last)
        if (s.reps != null && s.reps! > 0) s.reps!,
    ];
    if (reps.isEmpty) return null;
    final best = reps.reduce((a, b) => a > b ? a : b);
    final even = reps.every((r) => r == best);
    return ProgressionHint(
      kind: even ? HintKind.moreReps : HintKind.evenReps,
      last: last,
      reps: even ? best + 1 : best,
    );
  }

  if (category == ExerciseCategory.assistedBodyweight ||
      category == ExerciseCategory.cardio) {
    return null;
  }

  final weighed = [
    for (final s in last)
      if (s.weightKg != null &&
          s.weightKg! > 0 &&
          s.reps != null &&
          s.reps! > 0)
        s,
  ];
  if (weighed.isEmpty) return null;

  // The work was done at the heaviest weight; lighter sets around it - a
  // back-off, a pyramid - are not what the next step is measured on.
  final top = weighed.map((s) => s.weightKg!).reduce((a, b) => a > b ? a : b);
  final atTop = [
    for (final s in weighed)
      if (s.weightKg == top) s,
  ];
  final target =
      targetReps ?? atTop.map((s) => s.reps!).reduce((a, b) => a > b ? a : b);
  final rpes = [
    for (final s in atTop)
      if (s.rpe != null) s.rpe!,
  ];
  final rpe = rpes.isEmpty ? null : rpes.reduce((a, b) => a > b ? a : b);

  final reached = atTop.every((s) => s.reps! >= target);
  if (!reached) {
    return ProgressionHint(
      kind: HintKind.sameWeight,
      last: last,
      weightKg: top,
      reps: target,
      lastWeightKg: top,
      lastRpe: rpe,
    );
  }
  if (rpe != null && rpe > kHintMaxRpeToProgress) {
    return ProgressionHint(
      kind: HintKind.repeat,
      last: last,
      weightKg: top,
      reps: target,
      lastWeightKg: top,
      lastRpe: rpe,
    );
  }
  return ProgressionHint(
    kind: HintKind.heavier,
    last: last,
    weightKg: top + step,
    reps: target,
    lastWeightKg: top,
    lastRpe: rpe,
  );
}
