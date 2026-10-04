import 'package:drift/drift.dart';

import '../database.dart';

part 'recovery_dao.drift.dart';

/// What the user says about their own recovery.
///
/// Kept apart from the workouts on purpose: none of this is training, and all
/// of it is optional. An empty table here is the normal state, and the
/// estimate works without it - it just knows less.
@DriftAccessor(tables: [SorenessChecksTable, SleepEntriesTable, DrinkDaysTable])
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
      _sorenessSince(since).watch();

  /// The same, read once.
  Future<List<SorenessCheckRow>> sorenessSince(DateTime since) =>
      _sorenessSince(since).get();

  SimpleSelectStatement<$SorenessChecksTableTable, SorenessCheckRow>
  _sorenessSince(DateTime since) => select(sorenessChecksTable)
    ..where(
      (t) => t.checkedAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
    )
    ..orderBy([(t) => OrderingTerm.asc(t.checkedAt)]);

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
  Future<void> clearSoreness(String muscle, {required DateTime at}) => (delete(
    sorenessChecksTable,
  )..where((t) => t.id.equals(sorenessId(muscle, at)))).go();

  /// The nights that ended from [from] up to [to], both included, read
  /// once - for the import, which runs where a stream would never settle.
  Future<List<SleepEntryRow>> sleepEndedBetween(DateTime from, DateTime to) =>
      (select(sleepEntriesTable)..where(
            (t) =>
                t.wokeAt.isBiggerOrEqualValue(from.millisecondsSinceEpoch) &
                t.wokeAt.isSmallerOrEqualValue(to.millisecondsSinceEpoch),
          ))
          .get();

  /// The nights that ended from [from] up to [to], exclusive, newest
  /// first: one week of them on the screen that shows them by week.
  Stream<List<SleepEntryRow>> watchSleepBetween(DateTime from, DateTime to) =>
      (select(sleepEntriesTable)
            ..where(
              (t) =>
                  t.wokeAt.isBiggerOrEqualValue(from.millisecondsSinceEpoch) &
                  t.wokeAt.isSmallerThanValue(to.millisecondsSinceEpoch),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.wokeAt)]))
          .watch();

  /// Nights you woke up from on or after [since], oldest first.
  Stream<List<SleepEntryRow>> watchSleepSince(DateTime since) =>
      _sleepSince(since).watch();

  /// The same, read once.
  Future<List<SleepEntryRow>> sleepSince(DateTime since) =>
      _sleepSince(since).get();

  SimpleSelectStatement<$SleepEntriesTableTable, SleepEntryRow> _sleepSince(
    DateTime since,
  ) => select(sleepEntriesTable)
    ..where((t) => t.wokeAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch))
    ..orderBy([(t) => OrderingTerm.asc(t.wokeAt)]);

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
      // Filled in or corrected by hand: yours from now on, and an import
      // from Health Connect leaves it alone.
      source: const Value(null),
    ),
  );

  /// Forgets the night you woke up from on the day of [wokeAt].
  Future<void> clearSleep(DateTime wokeAt) => (delete(
    sleepEntriesTable,
  )..where((t) => t.id.equals(dayKey(wokeAt)))).go();

  /// Days with drinks on them from [since] on, oldest first.
  Stream<List<DrinkDayRow>> watchDrinksSince(DateTime since) =>
      _drinksSince(since).watch();

  /// The same, read once.
  Future<List<DrinkDayRow>> drinksSince(DateTime since) =>
      _drinksSince(since).get();

  SimpleSelectStatement<$DrinkDaysTableTable, DrinkDayRow> _drinksSince(
    DateTime since,
  ) => select(drinkDaysTable)
    ..where(
      (t) => t.day.isBiggerOrEqualValue(
        DateTime(since.year, since.month, since.day).millisecondsSinceEpoch,
      ),
    )
    ..orderBy([(t) => OrderingTerm.asc(t.day)]);

  /// Sets how much was drunk on the day of [day]. Zero removes the day.
  Future<void> setDrinks(DateTime day, int drinks) async {
    if (drinks <= 0) {
      await (delete(
        drinkDaysTable,
      )..where((t) => t.id.equals(dayKey(day)))).go();
      return;
    }
    await into(drinkDaysTable).insertOnConflictUpdate(
      DrinkDaysTableCompanion.insert(
        id: dayKey(day),
        day: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
        drinks: drinks,
      ),
    );
  }
}
