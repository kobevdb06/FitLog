import '../../../core/db/database.dart';
import 'plan_deload.dart';

/// Starting, stopping and removing a schema, with what hangs on it: the
/// deload of its deload week.
abstract final class PlanActions {
  /// Follows [planId] from the Monday [from]. The schema that was being
  /// followed stops, and its deload week if it had not begun goes with it.
  static Future<void> start(
    AppDatabase db,
    String planId, {
    required DateTime from,
  }) async {
    final before = await db.plansDao.running();
    if (before != null && before.id != planId) await dropPlanDeload(db);
    await db.plansDao.start(planId, startDay: from, at: DateTime.now());
    final plan = await db.plansDao.plan(planId);
    if (plan != null) await schedulePlanDeload(db, plan);
  }

  /// Over before its last week, or after it.
  static Future<void> stop(AppDatabase db, String planId) async {
    final plan = await db.plansDao.plan(planId);
    await db.plansDao.finish(planId, DateTime.now());
    if (plan?.state == PlanStatus.running) await dropPlanDeload(db);
  }

  /// Gone, with its sessions.
  static Future<void> delete(AppDatabase db, String planId) async {
    final plan = await db.plansDao.plan(planId);
    if (plan?.state == PlanStatus.running) await dropPlanDeload(db);
    await db.plansDao.deletePlan(planId);
  }
}
