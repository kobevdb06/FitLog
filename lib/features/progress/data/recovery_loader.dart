import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';

/// The rows the recovery estimate reads, turned into what it reads them as.
///
/// Shared by the screen, which watches them, and by everything that needs
/// the estimate once - the coach's lookup and the morning report - so the
/// two can never disagree about what a night or a run is.
SleepNight sleepNightOf(SleepEntryRow row) => SleepNight(
  wokeAt: DateTime.fromMillisecondsSinceEpoch(row.wokeAt),
  duration: Duration(milliseconds: row.wokeAt - row.fellAsleepAt),
);

DrinkDay drinkDayOf(DrinkDayRow row) => DrinkDay(
  day: DateTime.fromMillisecondsSinceEpoch(row.day),
  drinks: row.drinks,
);

VitalsDay vitalsDayOf(DailyVitalsRow row) => VitalsDay(
  day: DateTime.fromMillisecondsSinceEpoch(row.day),
  hrvMs: row.hrvMs,
  restingHr: row.restingHr,
);

/// Null for a kind this version does not know.
CardioSession? cardioSessionOf(CardioSessionRow row) {
  final kind = CardioKind.fromWire(row.kind);
  if (kind == null) return null;
  return CardioSession(
    start: DateTime.fromMillisecondsSinceEpoch(row.startedAt),
    end: DateTime.fromMillisecondsSinceEpoch(row.endedAt),
    kind: kind,
  );
}

/// Null for a level this version does not know.
SorenessCheck? sorenessCheckOf(SorenessCheckRow row) {
  final level = SorenessLevel.fromWire(row.level);
  if (level == null) return null;
  return SorenessCheck(
    muscle: row.muscle,
    at: DateTime.fromMillisecondsSinceEpoch(row.checkedAt),
    level: level,
  );
}

/// The whole estimate as of [now], read once.
///
/// Without [healthConnect], from what you filled in yourself only: no
/// readings, no runs, and only the nights and the weight you entered - the
/// estimate as the coach may see it when Health Connect is not shared with
/// it (DECISIONS 212).
Future<List<RecoveryEstimate>> loadRecoveryEstimates(
  AppDatabase db, {
  DateTime? now,
  bool healthConnect = true,
}) async {
  final at = now ?? DateTime.now();
  final since = at.subtract(kRecoveryHistoryWindow);
  final sets = await db.workoutsDao.recoverySets(since: since);
  final weight = await db.recordsDao.weightNearest(at, ownOnly: !healthConnect);

  return estimateRecovery(
    muscleSessions(sets, bodyWeightKg: weight?.value),
    checks: [
      for (final row in await db.recoveryDao.sorenessSince(since))
        ?sorenessCheckOf(row),
    ],
    nights: [
      for (final row in await db.recoveryDao.sleepSince(since))
        if (healthConnect || row.source == null) sleepNightOf(row),
    ],
    drinks: [
      for (final row in await db.recoveryDao.drinksSince(since))
        drinkDayOf(row),
    ],
    vitals: [
      if (healthConnect)
        for (final row in await db.healthDao.vitalsSince(
          since.subtract(kVitalsBaselineWindow),
        ))
          vitalsDayOf(row),
    ],
    cardio: [
      if (healthConnect)
        for (final row in await db.healthDao.cardioSince(since))
          ?cardioSessionOf(row),
    ],
    bodyWeightKg: weight?.value,
  );
}
