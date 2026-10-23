import '../../../core/calc/plan_weeks.dart';
import '../../../core/db/database.dart';
import '../../deload/data/deload_standing.dart';

/// Who a deload of a schema's deload week was started by.
const String kPlanDeloadSource = 'plan';

/// The deload week of a schema is a deload like one started by hand, so
/// everything that knows about deloads knows about this one: the banner,
/// the lighter sessions, the weekly review, the coach, and what looks past
/// a lighter week.
///
/// There is only ever one deload going or planned. This puts the schema's
/// next deload week there - unless one of the user's own is, which is not
/// the schema's to replace - and moves it when the schema's weeks changed.
Future<void> schedulePlanDeload(
  AppDatabase db,
  TrainingPlanRow plan, {
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final start = plan.from;
  if (start == null || plan.state != PlanStatus.running) return;

  final weeks = plan.planWeeks;
  int? deloadWeek;
  for (
    var n = plan.weekAt(at).clamp(1, weeks.length + 1);
    n <= weeks.length;
    n++
  ) {
    if (weeks[n - 1].isDeload) {
      deloadWeek = n;
      break;
    }
  }

  final current = await db.deloadDao.currentAt(at);
  final ours = current != null && current.source == kPlanDeloadSource;
  if (current != null && (!ours || current.isOnAt(at))) return;
  if (deloadWeek == null) {
    if (ours) await db.deloadDao.stop(current.id, at: at);
    return;
  }

  final from = planWeekStart(start, deloadWeek);
  if (ours && current.from == from) return;
  await db.deloadDao.start(
    from: from,
    days: 7,
    plan: deloadPlanOf(await db.settingsDao.getSettings()),
    source: kPlanDeloadSource,
    now: at,
  );
}

/// A schema stopped: its deload week, if it has not begun, goes with it.
Future<void> dropPlanDeload(AppDatabase db, {DateTime? now}) async {
  final at = now ?? DateTime.now();
  final current = await db.deloadDao.currentAt(at);
  if (current == null || current.source != kPlanDeloadSource) return;
  if (current.isAheadAt(at)) await db.deloadDao.stop(current.id, at: at);
}
