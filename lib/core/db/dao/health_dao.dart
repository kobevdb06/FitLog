import 'package:drift/drift.dart';

import '../database.dart';
import 'recovery_dao.dart';

part 'health_dao.drift.dart';

/// What comes in from Health Connect, and the rules it comes in by.
///
/// Two rules, the same everywhere:
///
/// - **What you entered yourself wins.** An import never overwrites a night
///   or a weight you filled in in FitLog; it fills the gaps around them.
/// - **Importing twice changes nothing.** Every imported row carries a key
///   that the next import finds again: the morning for a night, the day for
///   the daily readings, `hc:` and Health Connect's own id for the rest.
@DriftAccessor(
  tables: [
    SleepEntriesTable,
    BodyMeasurementsTable,
    DailyVitalsTable,
    CardioSessionsTable,
    WorkoutsTable,
  ],
)
class HealthDao extends DatabaseAccessor<AppDatabase> with _$HealthDaoMixin {
  HealthDao(super.db);

  /// What an imported row's id starts with.
  static const String idPrefix = 'hc:';

  /// Adds or refreshes one night. False when you had already filled that
  /// morning in yourself, in which case nothing is written.
  Future<bool> importNight({
    required DateTime fellAsleepAt,
    required DateTime wokeAt,
    required String source,
    int? lightMinutes,
    int? remMinutes,
    int? deepMinutes,
  }) async {
    final id = RecoveryDao.dayKey(wokeAt);
    final existing = await (select(
      sleepEntriesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null && existing.source == null) return false;

    await into(sleepEntriesTable).insertOnConflictUpdate(
      SleepEntriesTableCompanion.insert(
        id: id,
        fellAsleepAt: fellAsleepAt.millisecondsSinceEpoch,
        wokeAt: wokeAt.millisecondsSinceEpoch,
        lightMinutes: Value(lightMinutes),
        remMinutes: Value(remMinutes),
        deepMinutes: Value(deepMinutes),
        source: Value(source),
      ),
    );
    return true;
  }

  /// Adds or refreshes one weight. False when you weighed yourself in FitLog
  /// that same day: two weights on one day make a trend line jump, and the
  /// one you typed is the one you meant.
  Future<bool> importWeight({
    required String recordId,
    required DateTime at,
    required double kg,
    required String source,
  }) async {
    final start = DateTime(at.year, at.month, at.day);
    final end = DateTime(at.year, at.month, at.day + 1);
    final own =
        await (select(bodyMeasurementsTable)..where(
              (t) =>
                  t.type.equals(MeasurementType.weight.wire) &
                  t.source.isNull() &
                  t.measuredAt.isBiggerOrEqualValue(
                    start.millisecondsSinceEpoch,
                  ) &
                  t.measuredAt.isSmallerThanValue(end.millisecondsSinceEpoch),
            ))
            .get();
    if (own.isNotEmpty) return false;

    await into(bodyMeasurementsTable).insertOnConflictUpdate(
      BodyMeasurementsTableCompanion.insert(
        id: '$idPrefix$recordId',
        measuredAt: at.millisecondsSinceEpoch,
        type: MeasurementType.weight.wire,
        value: kg,
        source: Value(source),
      ),
    );
    return true;
  }

  /// Sets one day's readings. A value left out stays as it was, so a day the
  /// watch reported only one of the two keeps the other.
  Future<void> importVitals({
    required DateTime day,
    double? hrvMs,
    double? restingHr,
  }) async {
    final id = RecoveryDao.dayKey(day);
    final existing = await (select(
      dailyVitalsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    await into(dailyVitalsTable).insertOnConflictUpdate(
      DailyVitalsTableCompanion.insert(
        id: id,
        day: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
        hrvMs: Value(hrvMs ?? existing?.hrvMs),
        restingHr: Value(restingHr ?? existing?.restingHr),
        // The watch's own beats any FitLog worked out.
        restingHrDerived: Value(
          restingHr == null && (existing?.restingHrDerived ?? false),
        ),
      ),
    );
  }

  /// Sets the resting heart rate FitLog worked out from the night ending on
  /// [day]. False, and nothing written, when the watch gave one of its own
  /// for that day: that one wins.
  Future<bool> setDerivedRestingHr(DateTime day, double bpm) async {
    final id = RecoveryDao.dayKey(day);
    final existing = await (select(
      dailyVitalsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing?.restingHr != null && !existing!.restingHrDerived) {
      return false;
    }

    await into(dailyVitalsTable).insertOnConflictUpdate(
      DailyVitalsTableCompanion.insert(
        id: id,
        day: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
        hrvMs: Value(existing?.hrvMs),
        restingHr: Value(bpm),
        restingHrDerived: const Value(true),
      ),
    );
    return true;
  }

  Future<void> importCardio({
    required String recordId,
    required DateTime start,
    required DateTime end,
    required String kind,
    required String source,
  }) => into(cardioSessionsTable).insertOnConflictUpdate(
    CardioSessionsTableCompanion.insert(
      id: '$idPrefix$recordId',
      startedAt: start.millisecondsSinceEpoch,
      endedAt: end.millisecondsSinceEpoch,
      kind: kind,
      source: Value(source),
    ),
  );

  /// Puts the blood oxygen of the night ending on [day] on that day.
  Future<void> setNightOxygen(
    DateTime day, {
    required double average,
    required double lowest,
  }) => _upsertDay(
    day,
    DailyVitalsTableCompanion(spo2Avg: Value(average), spo2Min: Value(lowest)),
  );

  /// Sets the steps of [day].
  Future<void> setSteps(DateTime day, int steps) =>
      _upsertDay(day, DailyVitalsTableCompanion(steps: Value(steps)));

  /// Writes [changes] onto the row of [day], creating it when needed, and
  /// leaves every other column of it as it was.
  Future<void> _upsertDay(
    DateTime day,
    DailyVitalsTableCompanion changes,
  ) async {
    final id = RecoveryDao.dayKey(day);
    final exists =
        await (select(
          dailyVitalsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull() !=
        null;
    if (exists) {
      await (update(
        dailyVitalsTable,
      )..where((t) => t.id.equals(id))).write(changes);
    } else {
      await into(dailyVitalsTable).insert(
        changes.copyWith(
          id: Value(id),
          day: Value(
            DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
          ),
        ),
      );
    }
  }

  /// The days from [from] up to [to], exclusive, oldest first.
  Stream<List<DailyVitalsRow>> watchVitalsBetween(DateTime from, DateTime to) =>
      (select(dailyVitalsTable)
            ..where(
              (t) =>
                  t.day.isBiggerOrEqualValue(from.millisecondsSinceEpoch) &
                  t.day.isSmallerThanValue(to.millisecondsSinceEpoch),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.day)]))
          .watch();

  Stream<List<DailyVitalsRow>> watchVitalsSince(DateTime since) =>
      (select(dailyVitalsTable)
            ..where(
              (t) => t.day.isBiggerOrEqualValue(
                DateTime(
                  since.year,
                  since.month,
                  since.day,
                ).millisecondsSinceEpoch,
              ),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.day)]))
          .watch();

  Stream<List<CardioSessionRow>> watchCardioSince(DateTime since) =>
      (select(cardioSessionsTable)
            ..where(
              (t) => t.startedAt.isBiggerOrEqualValue(
                since.millisecondsSinceEpoch,
              ),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
          .watch();

  /// Finished sessions since [since] that were never written to Health
  /// Connect, oldest first.
  ///
  /// Only sessions with a real length: Health Connect refuses one that ends
  /// where it starts.
  Future<List<WorkoutRow>> workoutsToWrite(DateTime since) =>
      (select(workoutsTable)
            ..where(
              (t) =>
                  t.endedAt.isNotNull() &
                  t.healthConnectId.isNull() &
                  t.startedAt.isBiggerOrEqualValue(
                    since.millisecondsSinceEpoch,
                  ) &
                  t.endedAt.isBiggerThan(t.startedAt),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
          .get();

  /// Finished sessions that ended between [from] and [to]: the ones a watch
  /// may have measured the heart rate of since the last import.
  Future<List<WorkoutRow>> workoutsEndedBetween(DateTime from, DateTime to) =>
      (select(workoutsTable)..where(
            (t) =>
                t.endedAt.isBiggerOrEqualValue(from.millisecondsSinceEpoch) &
                t.endedAt.isSmallerOrEqualValue(to.millisecondsSinceEpoch) &
                t.endedAt.isBiggerThan(t.startedAt),
          ))
          .get();

  Future<void> setWorkoutHeartRate(
    String workoutId, {
    required int average,
    required int highest,
  }) => (update(workoutsTable)..where((t) => t.id.equals(workoutId))).write(
    WorkoutsTableCompanion(
      avgHeartRate: Value(average),
      maxHeartRate: Value(highest),
    ),
  );

  /// The finished sessions that started from [from] up to [to], exclusive,
  /// newest first - with the heart rate on those a watch measured.
  Stream<List<WorkoutRow>> watchFinishedWorkoutsBetween(
    DateTime from,
    DateTime to,
  ) =>
      (select(workoutsTable)
            ..where(
              (t) =>
                  t.endedAt.isNotNull() &
                  t.startedAt.isBiggerOrEqualValue(
                    from.millisecondsSinceEpoch,
                  ) &
                  t.startedAt.isSmallerThanValue(to.millisecondsSinceEpoch),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  /// Remembers the id Health Connect gave a session FitLog wrote there.
  Future<void> markWritten(String workoutId, String healthConnectId) =>
      (update(workoutsTable)..where((t) => t.id.equals(workoutId))).write(
        WorkoutsTableCompanion(healthConnectId: Value(healthConnectId)),
      );

  /// Forgets everything that ever came in from Health Connect, and nothing
  /// you entered yourself.
  Future<void> forgetImported() => transaction(() async {
    await (delete(sleepEntriesTable)..where((t) => t.source.isNotNull())).go();
    await (delete(
      bodyMeasurementsTable,
    )..where((t) => t.source.isNotNull())).go();
    await delete(dailyVitalsTable).go();
    await delete(cardioSessionsTable).go();
    // The sessions are yours; the heart rate on them came from the watch.
    await update(workoutsTable).write(
      const WorkoutsTableCompanion(
        avgHeartRate: Value(null),
        maxHeartRate: Value(null),
      ),
    );
  });
}
