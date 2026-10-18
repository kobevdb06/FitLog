import '../../../core/calc/deload.dart';
import '../../../core/db/database.dart';
import '../../progress/data/plateau_loader.dart';

/// The plan the settings give: what the start sheet opens with, and what
/// the coach proposes where it says nothing else.
DeloadPlan deloadPlanOf(AppSettingsRow settings) => DeloadPlan(
  setsPercent: settings.deloadSetsPercent,
  weightPercent: settings.deloadWeightPercent,
  repsPercent: settings.deloadRepsPercent,
  dropHardSets: settings.deloadDropHardSets,
  prAttempts: settings.deloadPrAttempts,
);

/// How many weeks in a row you trained without a break, and which exercises
/// stand still: what the proposal on Start and the coach both go by. Whether
/// that makes it time is for [deloadDue], with the settings.
Future<DeloadReason> deloadStanding(AppDatabase db, {DateTime? now}) async {
  final at = now ?? DateTime.now();
  final weeks = weeksWithoutBreak(
    now: at,
    sessions: await db.workoutsDao.ordinarySessionStarts(),
    deloads: [
      for (final row in await db.deloadDao.all())
        (from: row.from, until: row.until),
    ],
  );
  return DeloadReason(
    weeks: weeks,
    stalled: [
      for (final plateau in await loadPlateaus(db, now: at))
        plateau.exercise.name,
    ],
  );
}
