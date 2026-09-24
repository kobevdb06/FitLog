import 'package:drift/drift.dart';

import '../database.dart';

part 'recovery_dao.drift.dart';

/// What the user says about their own recovery.
///
/// Kept apart from the workouts on purpose: none of this is training, and all
/// of it is optional. An empty table here is the normal state, and the
/// estimate works without it - it just knows less.
@DriftAccessor(tables: [SorenessChecksTable, SleepEntriesTable])
class RecoveryDao extends DatabaseAccessor<AppDatabase>
    with _$RecoveryDaoMixin {
  RecoveryDao(super.db);

  /// A calendar day as `yyyymmdd`.
  static String dayKey(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}'
      '${at.month.toString().padLeft(2, '0')}'
      '${at.day.toString().padLeft(2, '0')}';

  /// The key that makes one answer per muscle per day.
  static String sorenessId(String muscle, DateTime at) =>
      '$muscle|${dayKey(at)}';

  Stream<List<SorenessCheckRow>> watchSorenessSince(DateTime since) =>
      (select(sorenessChecksTable)
            ..where(
              (t) => t.checkedAt.isBiggerOrEqualValue(
                since.millisecondsSinceEpoch,
              ),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.checkedAt)]))
          .watch();

  /// Says how [muscle] feels at [at]. A second answer on the same day
  /// replaces the first.
  Future<void> setSoreness(
    String muscle,
    SorenessLevel level, {
    required DateTime at,
  }) => into(sorenessChecksTable).insertOnConflictUpdate(
    SorenessChecksTableCompanion.insert(
      id: sorenessId(muscle, at),
      muscle: muscle,
      checkedAt: at.millisecondsSinceEpoch,
      level: level.wire,
    ),
  );

  /// Takes back what was said about [muscle] on the day of [at].
  Future<void> clearSoreness(String muscle, {required DateTime at}) =>
      (delete(sorenessChecksTable)
            ..where((t) => t.id.equals(sorenessId(muscle, at))))
          .go();

  /// Nights you woke up from on or after [since], oldest first.
  Stream<List<SleepEntryRow>> watchSleepSince(DateTime since) =>
      (select(sleepEntriesTable)
            ..where(
              (t) => t.wokeAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.wokeAt)]))
          .watch();

  /// Stores one night. The morning decides which night it is, so filling it
  /// in again corrects it.
  Future<void> setSleep({
    required DateTime fellAsleepAt,
    required DateTime wokeAt,
    int? lightMinutes,
    int? remMinutes,
    int? deepMinutes,
  }) => into(sleepEntriesTable).insertOnConflictUpdate(
    SleepEntriesTableCompanion.insert(
      id: dayKey(wokeAt),
      fellAsleepAt: fellAsleepAt.millisecondsSinceEpoch,
      wokeAt: wokeAt.millisecondsSinceEpoch,
      lightMinutes: Value(lightMinutes),
      remMinutes: Value(remMinutes),
      deepMinutes: Value(deepMinutes),
    ),
  );

  /// Forgets the night you woke up from on the day of [wokeAt].
  Future<void> clearSleep(DateTime wokeAt) =>
      (delete(sleepEntriesTable)..where((t) => t.id.equals(dayKey(wokeAt))))
          .go();
}
