import 'package:drift/drift.dart';

import '../../calc/plan_weeks.dart';
import '../database.dart';

part 'plans_dao.drift.dart';

/// Where a schema stands in time: its weeks, read from the row.
extension TrainingPlanWeeks on TrainingPlanRow {
  PlanStatus get state => PlanStatus.fromWire(status);
  PlanSplit get splitKind => PlanSplit.fromWire(split);
  PlanProgression get progressionKind => PlanProgression.fromWire(progression);
  List<PlanWeek> get planWeeks => decodePlanWeeks(pattern);

  DateTime? get from => switch (startDay) {
    final day? => DateTime.fromMillisecondsSinceEpoch(day),
    null => null,
  };

  /// The week it is at [at], from 1; 0 before it began or when it never
  /// did.
  int weekAt(DateTime at) => switch (from) {
    final start? => planWeekAt(start, at),
    null => 0,
  };

  /// Running, and past its last week: over, though nobody said so yet.
  bool isOverAt(DateTime at) {
    final length = weeks;
    return state == PlanStatus.running && length != null && weekAt(at) > length;
  }

  /// What [week] asks, or an ordinary week where the coach said nothing.
  PlanWeek weekPlan(int week) {
    final all = planWeeks;
    return week >= 1 && week <= all.length ? all[week - 1] : const PlanWeek();
  }
}

/// The schema's: the one being followed, the ones being talked over, and
/// the ones that were.
@DriftAccessor(tables: [TrainingPlansTable, RoutinesTable, WorkoutsTable])
class PlansDao extends DatabaseAccessor<AppDatabase> with _$PlansDaoMixin {
  PlansDao(super.db);

  /// What a schema is called before the coach names it.
  static const String unnamed = 'Nieuw schema';

  /// A new schema, still to be talked over: the user's goal and wishes,
  /// nothing laid out yet.
  Future<void> createDraft({
    required String id,
    required String goal,
    required PlanSplit split,
    String? splitNote,
    required int days,
    required PlanProgression progression,
    required DateTime at,
  }) => into(trainingPlansTable).insert(
    TrainingPlansTableCompanion.insert(
      id: id,
      name: unnamed,
      goal: goal.trim(),
      split: split.wire,
      splitNote: Value(
        split == PlanSplit.custom && (splitNote?.trim().isNotEmpty ?? false)
            ? splitNote!.trim()
            : null,
      ),
      days: Value(days),
      progression: Value(progression.wire),
      createdAt: at.millisecondsSinceEpoch,
      updatedAt: at.millisecondsSinceEpoch,
    ),
  );

  SimpleSelectStatement<$TrainingPlansTableTable, TrainingPlanRow> _all() =>
      select(trainingPlansTable)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

  /// Every schema, the last changed first.
  Stream<List<TrainingPlanRow>> watchPlans() => _all().watch();

  Future<TrainingPlanRow?> plan(String id) => (select(
    trainingPlansTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<TrainingPlanRow?> watchPlan(String id) => (select(
    trainingPlansTable,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  SimpleSelectStatement<$TrainingPlansTableTable, TrainingPlanRow> _running() =>
      select(trainingPlansTable)
        ..where((t) => t.status.equals(PlanStatus.running.wire))
        ..limit(1);

  /// The schema being followed; there is never more than one.
  Future<TrainingPlanRow?> running() => _running().getSingleOrNull();

  Stream<TrainingPlanRow?> watchRunning() => _running().watchSingleOrNull();

  SimpleSelectStatement<$RoutinesTableTable, RoutineRow> _sessions(
    String planId,
  ) => select(routinesTable)
    ..where((t) => t.planId.equals(planId))
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

  /// The sessions of a schema, in its order.
  Future<List<RoutineRow>> sessions(String planId) => _sessions(planId).get();

  Stream<List<RoutineRow>> watchSessions(String planId) =>
      _sessions(planId).watch();

  /// What the coach decided: the name, how many weeks, and what each asks.
  Future<void> layOut(
    String planId, {
    required String name,
    required List<PlanWeek> weeks,
    required DateTime at,
  }) => (update(trainingPlansTable)..where((t) => t.id.equals(planId))).write(
    TrainingPlansTableCompanion(
      name: Value(name.trim()),
      weeks: Value(weeks.length),
      pattern: Value(encodePlanWeeks(weeks)),
      updatedAt: Value(at.millisecondsSinceEpoch),
    ),
  );

  /// Makes [routineId] the session of [planId] at [position], meant for
  /// [weekday].
  Future<void> placeSession(
    String routineId, {
    required String planId,
    required int position,
    int? weekday,
  }) => (update(routinesTable)..where((t) => t.id.equals(routineId))).write(
    RoutinesTableCompanion(
      planId: Value(planId),
      planWeekday: Value(weekday),
      sortOrder: Value(position),
    ),
  );

  /// Follows [planId] from [startDay] on. A schema that was being followed
  /// stops: there is only ever one.
  Future<void> start(
    String planId, {
    required DateTime startDay,
    required DateTime at,
  }) => transaction(() async {
    await (update(trainingPlansTable)..where(
          (t) =>
              t.status.equals(PlanStatus.running.wire) &
              t.id.equals(planId).not(),
        ))
        .write(
          TrainingPlansTableCompanion(
            status: Value(PlanStatus.done.wire),
            endedAt: Value(at.millisecondsSinceEpoch),
            updatedAt: Value(at.millisecondsSinceEpoch),
          ),
        );
    await (update(trainingPlansTable)..where((t) => t.id.equals(planId))).write(
      TrainingPlansTableCompanion(
        status: Value(PlanStatus.running.wire),
        startDay: Value(
          DateTime(
            startDay.year,
            startDay.month,
            startDay.day,
          ).millisecondsSinceEpoch,
        ),
        endedAt: const Value(null),
        updatedAt: Value(at.millisecondsSinceEpoch),
      ),
    );
  });

  /// Over: finished, or stopped before its last week. Its sessions stay,
  /// with everything done in them.
  Future<void> finish(String planId, DateTime at) =>
      (update(trainingPlansTable)..where(
            (t) =>
                t.id.equals(planId) &
                t.status.equals(PlanStatus.done.wire).not(),
          ))
          .write(
            TrainingPlansTableCompanion(
              status: Value(PlanStatus.done.wire),
              endedAt: Value(at.millisecondsSinceEpoch),
              updatedAt: Value(at.millisecondsSinceEpoch),
            ),
          );

  /// Gone, with its sessions. What was done in them stays in the history,
  /// as sessions of a routine that no longer exists.
  Future<void> deletePlan(String planId) => transaction(() async {
    await (delete(routinesTable)..where((t) => t.planId.equals(planId))).go();
    await (delete(trainingPlansTable)..where((t) => t.id.equals(planId))).go();
  });

  Selectable<String> _done(
    List<String> routineIds,
    DateTime from,
    DateTime to,
  ) {
    final marks = List.filled(routineIds.length, '?').join(', ');
    return customSelect(
      'SELECT DISTINCT routine_id FROM workouts '
      'WHERE routine_id IN ($marks) AND ended_at IS NOT NULL '
      'AND started_at >= ? AND started_at < ?',
      variables: [
        for (final id in routineIds) Variable.withString(id),
        Variable.withInt(from.millisecondsSinceEpoch),
        Variable.withInt(to.millisecondsSinceEpoch),
      ],
      readsFrom: {workoutsTable},
    ).map((row) => row.read<String>('routine_id'));
  }

  /// Which of [routineIds] were done - finished - between [from] and [to].
  Future<Set<String>> doneBetween(
    List<String> routineIds,
    DateTime from,
    DateTime to,
  ) async => routineIds.isEmpty
      ? const {}
      : (await _done(routineIds, from, to).get()).toSet();

  Stream<Set<String>> watchDoneBetween(
    List<String> routineIds,
    DateTime from,
    DateTime to,
  ) => routineIds.isEmpty
      ? Stream.value(const {})
      : _done(routineIds, from, to).watch().map((ids) => ids.toSet());

  /// How [week] of [plan] stands: its sessions, and which were done.
  Future<PlanWeekStanding> standing(TrainingPlanRow plan, int week) async {
    final ids = [for (final s in await sessions(plan.id)) s.id];
    final start = plan.from;
    if (start == null || week < 1) {
      return PlanWeekStanding(sessions: ids, done: const {});
    }
    return PlanWeekStanding(
      sessions: ids,
      done: await doneBetween(
        ids,
        planWeekStart(start, week),
        planWeekStart(start, week + 1),
      ),
    );
  }
}
