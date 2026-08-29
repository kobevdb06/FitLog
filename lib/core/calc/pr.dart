import '../db/enums.dart';
import 'one_rm.dart';
import 'volume.dart';

/// Personal record detection.
///
/// A set is only ever considered when it has been checked off and is not a
/// warm-up. Every candidate is compared against the current best for that
/// exercise; a strictly higher value is a new record.

class PrCandidate {
  const PrCandidate(this.type, this.value);

  final PrType type;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is PrCandidate && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);

  @override
  String toString() => 'PrCandidate(${type.wire}, $value)';
}

/// The four record values a single set can produce.
///
/// Returns an empty list for sets that must not count: not completed, warm-up,
/// or without usable numbers.
List<PrCandidate> prCandidatesForSet({
  required SetType setType,
  required bool isCompleted,
  double? weightKg,
  int? reps,
}) {
  if (!isCompleted) return const [];
  if (!setType.countsTowardsVolume) return const [];

  final candidates = <PrCandidate>[];

  if (weightKg != null && weightKg > 0) {
    candidates.add(PrCandidate(PrType.maxWeight, weightKg));
  }
  if (reps != null && reps > 0) {
    candidates.add(PrCandidate(PrType.maxReps, reps.toDouble()));
  }

  final oneRm = estimatedOneRm(weightKg: weightKg, reps: reps);
  if (oneRm != null) {
    candidates.add(PrCandidate(PrType.est1rm, oneRm));
  }

  final volume = setVolumeKg(weightKg: weightKg, reps: reps);
  if (volume > 0) {
    candidates.add(PrCandidate(PrType.maxSetVolume, volume));
  }

  return candidates;
}

/// Keeps only the candidates that beat [currentBests].
///
/// A record type missing from [currentBests] means the exercise has no record
/// of that kind yet, so any usable value is a first record.
List<PrCandidate> newRecords({
  required List<PrCandidate> candidates,
  required Map<PrType, double> currentBests,
}) {
  return candidates.where((c) {
    final best = currentBests[c.type];
    return best == null || c.value > best;
  }).toList(growable: false);
}

/// Convenience wrapper combining both steps.
List<PrCandidate> detectRecordsForSet({
  required SetType setType,
  required bool isCompleted,
  double? weightKg,
  int? reps,
  required Map<PrType, double> currentBests,
}) {
  return newRecords(
    candidates: prCandidatesForSet(
      setType: setType,
      isCompleted: isCompleted,
      weightKg: weightKg,
      reps: reps,
    ),
    currentBests: currentBests,
  );
}
