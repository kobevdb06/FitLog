import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plan_weeks.dart';
import '../../../core/db/database.dart';
import '../../chat/domain/coach_proposal.dart';

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

/// How [week] of [planId] stands: its sessions in order, and which were
/// done in it, on any day. Nothing done before the schema began.
@riverpod
Stream<PlanWeekStanding> planWeekStanding(
  Ref ref,
  String planId,
  int week,
) async* {
  // Everything watched before the wait: the week asked for changes as the
  // schema starts, and this one may be gone by the time the wait is over.
  final plans = ref.watch(databaseProvider).plansDao;
  final planAt = ref.watch(planProvider(planId).future);
  final sessionsNow = ref.watch(planSessionsProvider(planId).future);
  final plan = await planAt;
  final sessions = await sessionsNow;
  if (!ref.mounted) return;
  final ids = [for (final session in sessions) session.id];
  final start = plan?.from;
  if (start == null || week < 1) {
    yield PlanWeekStanding(sessions: ids, done: const {});
    return;
  }
  yield* plans
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

/// A change the coach proposed that waits for Aanvaarden or Houden, with
/// the message it is on and its place there: what a card needs to decide.
class WaitingPlanChange {
  const WaitingPlanChange({
    required this.message,
    required this.index,
    required this.proposal,
  });

  final ChatMessageRow message;
  final int index;
  final CoachProposal proposal;
}

/// The changes in [messages] that wait, oldest first.
List<WaitingPlanChange> waitingPlanChanges(List<ChatMessageRow> messages) => [
  for (final message in messages)
    for (final (index, proposal) in parseProposals(message.proposals).indexed)
      if (proposal.kind == ProposalKind.planChange &&
          proposal.appliedId == null &&
          !(proposal.planChange?.kept ?? false))
        WaitingPlanChange(message: message, index: index, proposal: proposal),
];

/// The changes the coach proposed for [planId] that wait.
@riverpod
Stream<List<WaitingPlanChange>> planWaitingChanges(Ref ref, String planId) =>
    ref
        .watch(databaseProvider)
        .chatDao
        .watchPlanMessages(planId)
        .map(waitingPlanChanges);

/// How many changes the coach proposed for [planId] that wait for
/// Aanvaarden or Houden.
@riverpod
Stream<int> planOpenChanges(Ref ref, String planId) => ref
    .watch(databaseProvider)
    .chatDao
    .watchPlanMessages(planId)
    .map((messages) => waitingPlanChanges(messages).length);
