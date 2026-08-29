import '../db/enums.dart';

/// The minimum a set has to expose for the volume maths. Keeping this separate
/// from the drift row keeps the calculation testable without a database.
class SetVolumeInput {
  const SetVolumeInput({
    required this.weightKg,
    required this.reps,
    required this.isCompleted,
    required this.setType,
  });

  final double? weightKg;
  final int? reps;
  final bool isCompleted;
  final SetType setType;
}

/// `weight * reps`, or 0 when either is missing.
double setVolumeKg({double? weightKg, int? reps}) {
  if (weightKg == null || reps == null) return 0;
  if (weightKg <= 0 || reps <= 0) return 0;
  return weightKg * reps;
}

/// The sum over every completed, non-warm-up set.
double workoutVolumeKg(Iterable<SetVolumeInput> sets) {
  var total = 0.0;
  for (final s in sets) {
    if (!s.isCompleted) continue;
    if (!s.setType.countsTowardsVolume) continue;
    total += setVolumeKg(weightKg: s.weightKg, reps: s.reps);
  }
  return total;
}

/// The number of sets that count towards the workout total.
int countedSets(Iterable<SetVolumeInput> sets) => sets
    .where((s) => s.isCompleted && s.setType.countsTowardsVolume)
    .length;

/// Total repetitions over every completed, non-warm-up set.
int totalReps(Iterable<SetVolumeInput> sets) {
  var total = 0;
  for (final s in sets) {
    if (!s.isCompleted || !s.setType.countsTowardsVolume) continue;
    total += s.reps ?? 0;
  }
  return total;
}
