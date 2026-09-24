import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';

part 'recovery_providers.g.dart';

/// What you said about your muscles over the stretch the estimate looks at.
@riverpod
Stream<List<SorenessCheck>> sorenessChecks(Ref ref) {
  final since = DateTime.now().subtract(kRecoveryHistoryWindow);
  return ref
      .watch(databaseProvider)
      .recoveryDao
      .watchSorenessSince(since)
      .map(
        (rows) => [
          for (final row in rows)
            if (SorenessLevel.fromWire(row.level) case final level?)
              SorenessCheck(
                muscle: row.muscle,
                at: DateTime.fromMillisecondsSinceEpoch(row.checkedAt),
                level: level,
              ),
        ],
      );
}

/// The nights you filled in over the stretch the estimate looks at, oldest
/// first - as stored, stages and all, for the screen that shows them.
@riverpod
Stream<List<SleepEntryRow>> sleepEntries(Ref ref) {
  final since = DateTime.now().subtract(kRecoveryHistoryWindow);
  return ref.watch(databaseProvider).recoveryDao.watchSleepSince(since);
}

/// The same nights, the way the estimate reads them: when it ended and how
/// long it was.
SleepNight sleepNightOf(SleepEntryRow row) => SleepNight(
  wokeAt: DateTime.fromMillisecondsSinceEpoch(row.wokeAt),
  duration: Duration(milliseconds: row.wokeAt - row.fellAsleepAt),
);

/// One estimate per muscle group, newest session first.
///
/// A stream rather than a future: finishing a workout, editing a set and
/// rating a session all change the answer, and drift re-runs the query when
/// the tables behind it change. So does saying how a muscle feels: the
/// answers are watched here, and a new one rebuilds the estimate.
@riverpod
Stream<List<RecoveryEstimate>> recoveryEstimates(Ref ref) {
  final db = ref.watch(databaseProvider);
  final since = DateTime.now().subtract(kRecoveryHistoryWindow);
  final checks = ref.watch(sorenessChecksProvider).value ?? const [];
  final nights = [
    for (final row in ref.watch(sleepEntriesProvider).value ?? const [])
      sleepNightOf(row),
  ];

  return db.workoutsDao.watchRecoverySets(since: since).asyncMap((sets) async {
    // Bodyweight work carries no weight in the log, so the user's own weight
    // stands in for it. Absent, the estimate falls back to a stand-in figure.
    final weight = await db.recordsDao.weightNearest(DateTime.now());
    return estimateRecovery(
      muscleSessions(sets, bodyWeightKg: weight?.value),
      checks: checks,
      nights: nights,
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

  Future<void> rate(String workoutId, PerceivedEffort? effort) => ref
      .read(databaseProvider)
      .workoutsDao
      .setPerceivedEffort(workoutId, effort);

  /// Says how [muscle] feels now. Said again today, it replaces the answer.
  Future<void> feel(String muscle, SorenessLevel level, {DateTime? at}) => ref
      .read(databaseProvider)
      .recoveryDao
      .setSoreness(muscle, level, at: at ?? DateTime.now());

  /// Stores one night; filling in the same morning again corrects it.
  Future<void> sleep({
    required DateTime fellAsleepAt,
    required DateTime wokeAt,
    int? lightMinutes,
    int? remMinutes,
    int? deepMinutes,
  }) => ref
      .read(databaseProvider)
      .recoveryDao
      .setSleep(
        fellAsleepAt: fellAsleepAt,
        wokeAt: wokeAt,
        lightMinutes: lightMinutes,
        remMinutes: remMinutes,
        deepMinutes: deepMinutes,
      );

  Future<void> forgetNight(DateTime wokeAt) =>
      ref.read(databaseProvider).recoveryDao.clearSleep(wokeAt);

  /// Takes back today's answer for [muscle].
  Future<void> unfeel(String muscle, {DateTime? at}) => ref
      .read(databaseProvider)
      .recoveryDao
      .clearSoreness(muscle, at: at ?? DateTime.now());
}
