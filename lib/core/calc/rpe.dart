/// Turning "how many reps did you have left" into a number you can compare.
///
/// The estimate in `one_rm.dart` uses Epley, which assumes every set was taken
/// to failure. Almost none of them are, so the same 100 kg for 5 gives the
/// same answer whether it was comfortable or the last rep you had. An RPE says
/// which of the two it was, and the table below turns that into a share of
/// your maximum.
///
/// The table comes from Tuchscherer's RPE chart. Treat it as a starting point
/// rather than the truth: versions of it circulate with different numbers, it
/// is most reliable between RPE 7.5 and 9, and the spread between people is
/// enormous - at 70% of a true max, anything from 6 to 26 repetitions has been
/// reported. What it is good at is comparing you with yourself.
///
/// Pure Dart on purpose: nothing in `lib/core/calc/` imports Flutter.
library;

/// Share of a one-rep max, per (reps, RPE) pair.
///
/// Read with [_indexFor]: the pairs run diagonally, because one more rep and
/// one more rep in reserve cost about the same.
const List<double> kRpePercentOfMax = [
  100.0, 97.8, 95.5, 93.9, 92.2, 90.7, 89.2, 87.8, 86.3, 85.0, //
  83.7, 82.4, 81.1, 79.9, 78.6, 77.4, 76.2, 75.1, 73.9, 72.3, //
  70.7, 69.4, 68.0, 66.7, 65.3, 64.0, 62.6, 61.3, 59.9, 58.6, 57.2,
];

/// Below this the scale stops meaning anything: nobody can tell four reps in
/// reserve from six.
const double kMinUsableRpe = 6;

/// Above this the table runs out, and the estimate would be extrapolation
/// dressed up as a reading.
const int kMaxUsableReps = 12;

int? _indexFor({required int reps, required double rpe}) {
  if (reps < 1 || reps > kMaxUsableReps) return null;
  if (rpe < kMinUsableRpe || rpe > 10) return null;

  // Halves are the finest step the pad offers; anything between lands on one.
  final halves = (rpe * 2).round();
  final index = (reps - 1) * 2 + (20 - halves);
  if (index < 0 || index >= kRpePercentOfMax.length) return null;
  return index;
}

/// What share of your maximum this set represents, or null outside the table.
double? percentOfMax({required int reps, required double rpe}) {
  final index = _indexFor(reps: reps, rpe: rpe);
  return index == null ? null : kRpePercentOfMax[index];
}

/// The one-rep max this set implies.
///
/// Null whenever the set says too little: no weight, a rep count the table
/// does not cover, or an RPE too low to mean anything.
double? e1RmFromRpe({
  required double? weightKg,
  required int? reps,
  required double? rpe,
}) {
  if (weightKg == null || reps == null || rpe == null) return null;
  if (weightKg <= 0) return null;

  final percent = percentOfMax(reps: reps, rpe: rpe);
  if (percent == null || percent <= 0) return null;
  return weightKg / (percent / 100);
}

/// How much this set's estimate deserves to be believed, 0 to 1.
///
/// Two things pull it down. An RPE far from failure is a guess about reps you
/// never did, and a long set mixes being out of breath in with how close to
/// failure you were. Nothing here is precise; it is there so one lucky set
/// cannot carry a session on its own.
double rpeConfidence({required double rpe, required int reps}) {
  if (_indexFor(reps: reps, rpe: rpe) == null) return 0;

  // 1.0 from 8 upwards, falling away to 0.5 at the bottom of the usable range.
  final byRpe = rpe >= 8
      ? 1.0
      : (0.5 + (rpe - kMinUsableRpe) * 0.25).clamp(0.5, 1.0);

  // Full marks up to eight reps, then down to 0.6 at the end of the table.
  final byReps = reps <= 8 ? 1.0 : (1.0 - (reps - 8) * 0.1).clamp(0.6, 1.0);

  return byRpe * byReps;
}

/// One set, reduced to what the estimate needs.
class ScoredSet {
  const ScoredSet({
    required this.weightKg,
    required this.reps,
    required this.rpe,
  });

  final double? weightKg;
  final int? reps;
  final double? rpe;
}

/// The session's estimate: every usable set, weighted by how much it can be
/// believed.
///
/// A weighted mean rather than the best of them, which is what the Epley
/// metric takes. There, only the hardest set says anything - an easy set
/// carries no information about a maximum. Here every scored set is already an
/// estimate of the same number, so the sensible thing is to listen to all of
/// them and to the trustworthy ones most.
///
/// Null when the session contains no usable set.
double? sessionE1Rm(Iterable<ScoredSet> sets) {
  var weighted = 0.0;
  var total = 0.0;

  for (final set in sets) {
    final estimate = e1RmFromRpe(
      weightKg: set.weightKg,
      reps: set.reps,
      rpe: set.rpe,
    );
    if (estimate == null) continue;

    final confidence = rpeConfidence(rpe: set.rpe!, reps: set.reps!);
    if (confidence <= 0) continue;

    weighted += estimate * confidence;
    total += confidence;
  }

  return total > 0 ? weighted / total : null;
}
