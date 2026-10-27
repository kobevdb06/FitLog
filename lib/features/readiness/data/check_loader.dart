import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';
import '../../dashboard/data/today_loader.dart';
import '../../dashboard/domain/today_plan.dart';
import '../domain/training_check.dart';

/// Today's check at [now], read straight from the database: for the morning
/// report, which runs without the screens. The same answer as Vandaag gives
/// from the same rows - null likewise when there is nothing to check or the
/// check knows nothing worth a line.
Future<TodayCheck?> loadTodayCheck(
  AppDatabase db, {
  required DateTime now,
  required List<RecoveryEstimate> estimates,
  required CheckBody body,
}) async {
  final plan = await loadTodayPlan(db, now);
  final lead = plan.lead;
  if (lead == null || lead.doneToday) return null;

  Future<TrainingCheck?> check(RoutineRow routine) async {
    final detail = await db.routinesDao.getRoutineDetail(routine.id);
    if (detail == null) return null;
    return checkSession(
      routineId: routine.id,
      routineName: detail.routine.name,
      muscleSets: sessionMuscleSets(detail),
      estimates: estimates,
      body: body,
      now: now,
    );
  }

  final first = await check(lead.routine);
  if (first == null || !first.informed) return null;
  return weighToday(first, [
    if (plan.kind == TodayPlanKind.plan)
      for (final other in plan.rest) ?await check(other.routine),
  ]);
}
