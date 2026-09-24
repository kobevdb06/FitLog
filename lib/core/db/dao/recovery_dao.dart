import 'package:drift/drift.dart';

import '../database.dart';

part 'recovery_dao.drift.dart';

/// What the user says about their own recovery.
///
/// Kept apart from the workouts on purpose: none of this is training, and all
/// of it is optional. An empty table here is the normal state, and the
/// estimate works without it - it just knows less.
@DriftAccessor(tables: [SorenessChecksTable])
class RecoveryDao extends DatabaseAccessor<AppDatabase>
    with _$RecoveryDaoMixin {
  RecoveryDao(super.db);

  /// The key that makes one answer per muscle per day.
  static String sorenessId(String muscle, DateTime at) {
    final day =
        '${at.year.toString().padLeft(4, '0')}'
        '${at.month.toString().padLeft(2, '0')}'
        '${at.day.toString().padLeft(2, '0')}';
    return '$muscle|$day';
  }

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
}
