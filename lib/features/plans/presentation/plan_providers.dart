import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plan_weeks.dart';
import '../../../core/db/database.dart';

part 'plan_providers.g.dart';

/// Every schema, the last changed first.
@riverpod
Stream<List<TrainingPlanRow>> plans(Ref ref) =>
    ref.watch(databaseProvider).plansDao.watchPlans();

@riverpod
Stream<TrainingPlanRow?> plan(Ref ref, String id) =>
    ref.watch(databaseProvider).plansDao.watchPlan(id);

/// The schema being followed, if any.
@riverpod
Stream<TrainingPlanRow?> runningPlan(Ref ref) =>
    ref.watch(databaseProvider).plansDao.watchRunning();

/// The sessions of a schema, in its order.
@riverpod
Stream<List<RoutineRow>> planSessions(Ref ref, String planId) =>
    ref.watch(databaseProvider).plansDao.watchSessions(planId);

/// The conversations of the schema's, the last added to first.
@riverpod
Stream<List<ChatThreadRow>> planThreads(Ref ref) =>
    ref.watch(databaseProvider).chatDao.watchPlanThreads();

/// How the current week of [planId] stands: its sessions in order, and
/// which were done this week, on any day.
@riverpod
Stream<PlanWeekStanding> planThisWeek(Ref ref, String planId) async* {
  final plan = await ref.watch(planProvider(planId).future);
  final sessions = await ref.watch(planSessionsProvider(planId).future);
  final ids = [for (final session in sessions) session.id];
  final start = plan?.from;
  final week = plan?.weekAt(DateTime.now()) ?? 0;
  if (start == null || week < 1) {
    yield PlanWeekStanding(sessions: ids, done: const {});
    return;
  }
  yield* ref
      .watch(databaseProvider)
      .plansDao
      .watchDoneBetween(
        ids,
        planWeekStart(start, week),
        planWeekStart(start, week + 1),
      )
      .map((done) => PlanWeekStanding(sessions: ids, done: done));
}

/// Which half of Trainen is showing: your own workouts, or the schema's.
/// Kept while the app runs, so coming back to the tab finds it as it was.
enum TrainShelf { workouts, plans }

@Riverpod(keepAlive: true)
class TrainShelfChoice extends _$TrainShelfChoice {
  @override
  TrainShelf build() => TrainShelf.workouts;

  void show(TrainShelf shelf) => state = shelf;
}
