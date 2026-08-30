import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/recovery.dart';
import '../../../core/db/enums.dart';

part 'recovery_providers.g.dart';

/// One estimate per muscle group, newest session first.
///
/// A stream rather than a future: finishing a workout, editing a set and
/// rating a session all change the answer, and drift re-runs the query when
/// the tables behind it change.
@riverpod
Stream<List<RecoveryEstimate>> recoveryEstimates(Ref ref) {
  final db = ref.watch(databaseProvider);
  final since = DateTime.now().subtract(kRecoveryHistoryWindow);

  return db.workoutsDao.watchRecoverySets(since: since).asyncMap((sets) async {
    // Bodyweight work carries no weight in the log, so the user's own weight
    // stands in for it. Absent, the estimate falls back to a stand-in figure.
    final weight = await db.recordsDao.weightNearest(DateTime.now());
    return estimateRecovery(
      muscleSessions(sets, bodyWeightKg: weight?.value),
    );
  });
}

/// The muscles one particular session left behind.
///
/// Filtered out of the whole picture rather than computed separately: a muscle
/// belongs to this workout's card exactly when this workout is the last thing
/// that trained it.
///
/// Null while the estimate is still being read, which is what tells the card
/// to wait rather than to say there is nothing.
@riverpod
List<RecoveryEstimate>? workoutRecovery(Ref ref, String workoutId) {
  final estimates = ref.watch(recoveryEstimatesProvider).value;
  if (estimates == null) return null;
  return [
    for (final estimate in estimates)
      if (estimate.workoutId == workoutId) estimate,
  ];
}

/// Writes how heavy the session felt.
@Riverpod(keepAlive: true)
RecoveryActions recoveryActions(Ref ref) => RecoveryActions(ref);

class RecoveryActions {
  const RecoveryActions(this.ref);

  final Ref ref;

  Future<void> rate(String workoutId, PerceivedEffort? effort) =>
      ref.read(databaseProvider).workoutsDao.setPerceivedEffort(
        workoutId,
        effort,
      );
}
