import '../../../core/db/database.dart';
import '../domain/today_plan.dart';

/// What Vandaag offers at [now], read straight from the database: for what
/// runs without the screens, such as the morning report. The same ladder as
/// the card, from the same rows.
Future<TodayPlan> loadTodayPlan(AppDatabase db, DateTime now) async {
  PlanToday? schema;
  final plan = await db.plansDao.running();
  if (plan != null) {
    final week = plan.weekAt(now);
    if (week >= 1 && !plan.isOverAt(now)) {
      final standing = await db.plansDao.standing(plan, week);
      schema = PlanToday(
        name: plan.name,
        week: week,
        weeks: plan.weeks ?? plan.planWeeks.length,
        sessions: await db.plansDao.sessions(plan.id),
        done: standing.done,
      );
    }
  }
  return buildTodayPlan(
    scheduled: await db.routinesDao.scheduledRoutines(),
    favourites: await db.routinesDao.favouritesByUse(limit: kHomeFavourites),
    suggested: await db.routinesDao.suggestedRoutine(),
    now: now,
    schema: schema,
  );
}
