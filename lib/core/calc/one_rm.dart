/// Estimated one-rep-max, using the Epley formula.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

/// Above this rep count the Epley estimate drifts far enough from reality that
/// the UI marks it as unreliable.
const int oneRmReliableRepLimit = 12;

/// `weight * (1 + reps / 30)`, with a single rep returning the weight itself.
///
/// Returns `null` when there is not enough information (no weight, no reps, or
/// a non-positive value), so callers never have to invent a zero.
double? estimatedOneRm({double? weightKg, int? reps}) {
  if (weightKg == null || reps == null) return null;
  if (weightKg <= 0 || reps <= 0) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Whether an estimate built on [reps] should be shown with a caveat.
bool isOneRmEstimateReliable(int? reps) =>
    reps != null && reps > 0 && reps <= oneRmReliableRepLimit;

/// The estimate only where it holds: up to [oneRmReliableRepLimit] reps.
///
/// What a record, a plateau and the best of a session compare. A set of 60
/// kg x 30 estimated 120 kg, more than 100 kg x 3 gives: an exhausting set
/// of a light weight became a record of strength, and a day of progress
/// (DECISIONS 244). One set shown on its own keeps its estimate, with the
/// caveat.
double? reliableOneRm({double? weightKg, int? reps}) =>
    isOneRmEstimateReliable(reps)
    ? estimatedOneRm(weightKg: weightKg, reps: reps)
    : null;
