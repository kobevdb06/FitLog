import 'package:drift/drift.dart';

import '../../../core/calc/milestones.dart';
import '../../../core/calc/one_rm.dart';
import '../../../core/calc/streak.dart';
import '../../../core/db/dao/recovery_dao.dart';
import '../../../core/db/database.dart';
import '../../dashboard/data/today_loader.dart';
import '../../morning/data/morning_reporter.dart' show loadMorningFacts;
import '../../progress/data/plateau_loader.dart';
import '../../readiness/domain/training_check.dart';
import '../../review/data/week_facts_builder.dart';
import 'workout_facts.dart';

/// What each moment is about, as text: the second half of its key.
abstract final class MomentSubject {
  static String plateau(String exerciseId, DateTime since) =>
      '$exerciseId@${RecoveryDao.dayKey(since)}';

  static String wait(DateTime day, String routineId) =>
      '${RecoveryDao.dayKey(day)}/$routineId';

  static String milestone(MilestoneKind kind, double step) =>
      '${kind.name}:${step.round()}';

  static String month(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// The first day of the month [subject] names.
  static DateTime monthStart(String subject) {
    final parts = subject.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String day(DateTime day) => RecoveryDao.dayKey(day);
}

/// The facts the coach is given at [moment] about [subject], as FitLog works
/// them out; null when there is nothing (any more) to say anything about.
///
/// The morning and the week have their own reporters, with their own facts.
/// [health] is whether the coach may see what came from Health Connect.
Future<Map<String, Object?>?> momentFacts(
  AppDatabase db,
  CoachMoment moment,
  String subject, {
  required bool health,
  required DateTime now,
}) => switch (moment) {
  CoachMoment.workout => buildWorkoutFacts(db, subject, health: health),
  CoachMoment.before => _before(db, subject, health: health, now: now),
  CoachMoment.month => _month(db, subject, health: health),
  CoachMoment.plateau => _plateau(db, subject, health: health, now: now),
  CoachMoment.wait => _wait(db, health: health, now: now),
  CoachMoment.planDone => _planDone(db, subject),
  CoachMoment.milestone => _milestone(db, subject),
  CoachMoment.weighing => _weighing(db, health: health, now: now),
  CoachMoment.idle => _idle(db, now: now),
  CoachMoment.free => _free(db, health: health, now: now),
  CoachMoment.morning || CoachMoment.week => Future.value(),
};

/// The workout that starts, as it stands ready: the sets the routine put
/// in, each exercise the time before, which stand still, and today.
Future<Map<String, Object?>?> _before(
  AppDatabase db,
  String workoutId, {
  required bool health,
  required DateTime now,
}) async {
  final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
  if (detail == null || detail.exercises.isEmpty) return null;
  final workout = detail.workout;
  final routine = workout.routineId == null
      ? null
      : await db.routinesDao.getRoutine(workout.routineId!);
  final stalled = {
    for (final item in await loadPlateaus(db, now: now, healthConnect: health))
      item.exercise.id: item.plateau.weeksAt(now),
  };
  final today = await loadMorningFacts(db, now, healthConnect: health);

  return {
    'name': workout.name,
    'from_routine': ?routine?.name,
    if (workout.isDeload) 'deload': true,
    if (workout.isLight) 'light': true,
    'exercises': [
      for (final item in detail.exercises)
        {
          'name': item.exercise.name,
          'muscle': item.exercise.primaryMuscle,
          if (item.workoutExercise.isUnilateral) 'per_side': true,
          'superset': ?item.workoutExercise.supersetGroup,
          'sets': [
            for (final set in item.sets)
              {
                'type': set.setType,
                'weight_kg': ?set.weightKg,
                'reps': ?set.reps,
                'seconds': ?set.durationSeconds,
              },
          ],
          'last_time': ?await lastTimeOf(
            db,
            exerciseId: item.exercise.id,
            before: workout.startedAt,
            unilateral: item.workoutExercise.isUnilateral,
          ),
          'stalled_weeks': ?stalled[item.exercise.id],
        },
    ],
    'vandaag': today.forCoach(),
  };
}

/// The exercise of [subject] as it stalled, or null when it moves again.
Future<Map<String, Object?>?> _plateau(
  AppDatabase db,
  String subject, {
  required bool health,
  required DateTime now,
}) async {
  final exerciseId = subject.split('@').first;
  for (final item in await loadPlateaus(db, now: now, healthConnect: health)) {
    if (item.exercise.id == exerciseId) return plateauForCoach(item, now: now);
  }
  return null;
}

/// Today, when the check says the session had better wait; null when it
/// does not (any more).
Future<Map<String, Object?>?> _wait(
  AppDatabase db, {
  required bool health,
  required DateTime now,
}) async {
  final today = await loadMorningFacts(db, now, healthConnect: health);
  if (today.check?.verdict != CheckVerdict.wait) return null;
  return {'vandaag': today.forCoach()};
}

/// The schema of [planId] from its first week to its last: sessions done per
/// week, and each exercise's best set at the start and at the end.
Future<Map<String, Object?>?> _planDone(AppDatabase db, String planId) async {
  final plan = await db.plansDao.plan(planId);
  final startDay = plan?.startDay;
  if (plan == null || startDay == null) return null;
  final start = DateTime.fromMillisecondsSinceEpoch(startDay);
  final end = switch (plan.endedAt) {
    final at? => DateTime.fromMillisecondsSinceEpoch(at),
    null => DateTime.now(),
  };
  final sessions = await db.plansDao.sessions(planId);
  final ids = [for (final session in sessions) session.id];
  if (ids.isEmpty) return null;
  final marks = List.filled(ids.length, '?').join(', ');

  final done = await db
      .customSelect(
        'SELECT started_at FROM workouts WHERE ended_at IS NOT NULL '
        'AND routine_id IN ($marks) AND started_at >= ? AND started_at <= ?',
        variables: [
          for (final id in ids) Variable.withString(id),
          Variable.withInt(start.millisecondsSinceEpoch),
          Variable.withInt(end.millisecondsSinceEpoch),
        ],
      )
      .get();
  final weeks = <int, int>{};
  for (final row in done) {
    final at = DateTime.fromMillisecondsSinceEpoch(row.read<int>('started_at'));
    final week = at.difference(start).inDays ~/ 7;
    weeks[week] = (weeks[week] ?? 0) + 1;
  }
  final weekCount = (end.difference(start).inDays ~/ 7) + 1;
  final lastWeek = DateTime(
    start.year,
    start.month,
    start.day + 7 * (weekCount - 1),
  );

  Future<Map<String, double>> best(DateTime from, DateTime to) async {
    final rows = await db
        .customSelect(
          'SELECT e.name AS name, ws.weight_kg AS kg, ws.reps AS reps '
          'FROM workout_sets ws '
          'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
          'JOIN workouts w ON w.id = we.workout_id '
          'JOIN exercises e ON e.id = we.exercise_id '
          'WHERE w.routine_id IN ($marks) AND w.ended_at IS NOT NULL '
          'AND ws.is_completed = 1 AND ws.set_type != ? '
          'AND ws.weight_kg > 0 AND ws.reps > 0 '
          'AND w.started_at >= ? AND w.started_at < ?',
          variables: [
            for (final id in ids) Variable.withString(id),
            Variable.withString(SetType.warmup.wire),
            Variable.withInt(from.millisecondsSinceEpoch),
            Variable.withInt(to.millisecondsSinceEpoch),
          ],
        )
        .get();
    final found = <String, double>{};
    for (final row in rows) {
      final value = estimatedOneRm(
        weightKg: row.read<double>('kg'),
        reps: row.read<int>('reps'),
      );
      if (value == null) continue;
      final name = row.read<String>('name');
      if (value > (found[name] ?? 0)) found[name] = value;
    }
    return found;
  }

  final first = await best(
    start,
    DateTime(start.year, start.month, start.day + 7),
  );
  final last = await best(lastWeek, end.add(const Duration(days: 1)));
  double one(double value) => (value * 10).round() / 10;

  return {
    'name': plan.name,
    'goal': plan.goal,
    'weeks_planned': ?plan.weeks,
    'started': MomentSubject.day(start),
    'ended': MomentSubject.day(end),
    'sessions': [for (final session in sessions) session.name],
    'sessions_per_week_planned': sessions.length,
    'weeks': [
      for (var week = 0; week < weekCount; week++)
        {'week': week + 1, 'done': weeks[week] ?? 0},
    ],
    'exercises': [
      for (final name in {...first.keys, ...last.keys})
        {
          'name': name,
          'first_week_1rm_kg': ?switch (first[name]) {
            final v? => one(v),
            null => null,
          },
          'last_week_1rm_kg': ?switch (last[name]) {
            final v? => one(v),
            null => null,
          },
        },
    ],
  };
}

/// The milestone of [subject], with the totals that reached it.
Future<Map<String, Object?>?> _milestone(AppDatabase db, String subject) async {
  final parts = subject.split(':');
  final totals = await lifetimeTotals(db);
  if (totals.workouts == 0) return null;
  return {
    'milestone': {'kind': parts.first, 'reached': int.tryParse(parts.last)},
    'workouts': totals.workouts,
    'volume_kg': totals.volumeKg.round(),
    'records': totals.records,
    'longest_streak_weeks': totals.longestStreakWeeks,
    'first_workout': ?switch (totals.first) {
      final at? => MomentSubject.day(at),
      null => null,
    },
  };
}

/// Everything ever: what the milestones count.
typedef LifetimeTotals = ({
  int workouts,
  double volumeKg,
  int records,
  int longestStreakWeeks,
  DateTime? first,
});

Future<LifetimeTotals> lifetimeTotals(AppDatabase db, {String? without}) async {
  final rows = await db
      .customSelect(
        'SELECT id, started_at, total_volume_kg FROM workouts '
        'WHERE ended_at IS NOT NULL ORDER BY started_at',
      )
      .get();
  final kept = [
    for (final row in rows)
      if (row.read<String>('id') != without) row,
  ];
  final records = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM personal_records pr '
        'JOIN workout_sets ws ON ws.id = pr.workout_set_id '
        'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
        'WHERE ? IS NULL OR we.workout_id != ?',
        variables: [Variable<String>(without), Variable<String>(without)],
      )
      .getSingle();
  final dates = [
    for (final row in kept)
      DateTime.fromMillisecondsSinceEpoch(row.read<int>('started_at')),
  ];
  return (
    workouts: kept.length,
    volumeKg: kept.fold(
      0.0,
      (sum, row) => sum + row.read<double>('total_volume_kg'),
    ),
    records: records.read<int>('n'),
    longestStreakWeeks: longestStreakWeeks(dates),
    first: dates.isEmpty ? null : dates.first,
  );
}

/// The milestone [workoutId] reached, if it reached one: the highest step
/// it passed, of the first kind that has one. Null for an ordinary workout.
Future<({MilestoneKind kind, double step})?> milestoneReachedBy(
  AppDatabase db,
  String workoutId,
) async {
  final now = await lifetimeTotals(db);
  final before = await lifetimeTotals(db, without: workoutId);
  List<Milestone> of(LifetimeTotals t) => milestonesFor(
    workouts: t.workouts,
    longestStreakWeeks: t.longestStreakWeeks,
    volumeKg: t.volumeKg,
    records: t.records,
  );
  final after = of(now);
  final earlier = of(before);
  for (var i = 0; i < after.length; i++) {
    if (after[i].reached > earlier[i].reached) {
      return (kind: after[i].kind, step: after[i].steps[after[i].reached - 1]);
    }
  }
  return null;
}

/// The weighings of the last twelve weeks, and the working sets of the same
/// weeks; null without a weighing.
Future<Map<String, Object?>?> _weighing(
  AppDatabase db, {
  required bool health,
  required DateTime now,
}) async {
  final from = now.subtract(const Duration(days: 84));
  final weights = [
    for (final row in (await db.recordsDao.measurements(
      type: MeasurementType.weight,
    )).reversed)
      if (row.measuredAt >= from.millisecondsSinceEpoch &&
          (health || row.source == null))
        row,
  ];
  if (weights.isEmpty) return null;
  final sets = await db
      .customSelect(
        'SELECT w.started_at AS at FROM workout_sets ws '
        'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
        'JOIN workouts w ON w.id = we.workout_id '
        'WHERE w.ended_at IS NOT NULL AND ws.is_completed = 1 '
        'AND ws.set_type != ? AND w.started_at >= ?',
        variables: [
          Variable.withString(SetType.warmup.wire),
          Variable.withInt(from.millisecondsSinceEpoch),
        ],
      )
      .get();
  final perWeek = List.filled(12, 0);
  for (final row in sets) {
    final at = DateTime.fromMillisecondsSinceEpoch(row.read<int>('at'));
    final week = at.difference(from).inDays ~/ 7;
    if (week >= 0 && week < 12) perWeek[week]++;
  }
  return {
    'weights': [
      for (final row in weights)
        {
          'date': MomentSubject.day(
            DateTime.fromMillisecondsSinceEpoch(row.measuredAt),
          ),
          'kg': (row.value * 10).round() / 10,
        },
    ],
    'sets_per_week': perWeek,
  };
}

/// The month of [subject] next to the month before it.
Future<Map<String, Object?>?> _month(
  AppDatabase db,
  String subject, {
  required bool health,
}) async {
  final start = MomentSubject.monthStart(subject);
  final end = DateTime(start.year, start.month + 1);
  final before = DateTime(start.year, start.month - 1);
  final facts = await monthNumbers(db, start, end, health: health);
  if (facts.workouts == 0) return null;
  final previous = await monthNumbers(db, before, start, health: health);
  return {'month': subject, ...facts.toJson(), 'previous': previous.toJson()};
}

/// What one month holds, as the month overview shows it.
class MonthNumbers {
  const MonthNumbers({
    required this.workouts,
    required this.sets,
    required this.volumeKg,
    required this.minutes,
    required this.records,
    required this.muscles,
    this.weightFirst,
    this.weightLast,
    this.sleepMinutes,
  });

  final int workouts;
  final int sets;
  final double volumeKg;
  final int minutes;
  final int records;

  /// Working sets per primary muscle, most first.
  final Map<String, int> muscles;
  final double? weightFirst;
  final double? weightLast;

  /// The average night, in minutes.
  final int? sleepMinutes;

  Map<String, Object?> toJson() => {
    'workouts': workouts,
    'working_sets': sets,
    'volume_kg': volumeKg.round(),
    'minutes': minutes,
    'records': records,
    'muscles': muscles,
    'weight_first_kg': ?weightFirst,
    'weight_last_kg': ?weightLast,
    'sleep_minutes_per_night': ?sleepMinutes,
  };
}

Future<MonthNumbers> monthNumbers(
  AppDatabase db,
  DateTime from,
  DateTime to, {
  required bool health,
}) async {
  int ms(DateTime d) => d.millisecondsSinceEpoch;
  final range = [Variable.withInt(ms(from)), Variable.withInt(ms(to))];
  final workouts = await db
      .customSelect(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total_volume_kg), 0) AS kg, '
        'COALESCE(SUM(total_sets), 0) AS sets, '
        'COALESCE(SUM(duration_seconds), 0) AS seconds FROM workouts '
        'WHERE ended_at IS NOT NULL AND started_at >= ? AND started_at < ?',
        variables: range,
      )
      .getSingle();
  final records = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM personal_records '
        'WHERE achieved_at >= ? AND achieved_at < ?',
        variables: range,
      )
      .getSingle();
  final muscles = await db
      .customSelect(
        'SELECT e.primary_muscle AS muscle, COUNT(*) AS n '
        'FROM workout_sets ws '
        'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
        'JOIN workouts w ON w.id = we.workout_id '
        'JOIN exercises e ON e.id = we.exercise_id '
        'WHERE w.ended_at IS NOT NULL AND ws.is_completed = 1 '
        'AND ws.set_type != ? AND w.started_at >= ? AND w.started_at < ? '
        'GROUP BY e.primary_muscle ORDER BY n DESC',
        variables: [Variable.withString(SetType.warmup.wire), ...range],
      )
      .get();
  final weights = [
    for (final row in (await db.recordsDao.measurements(
      type: MeasurementType.weight,
    )).reversed)
      if (row.measuredAt >= ms(from) &&
          row.measuredAt < ms(to) &&
          (health || row.source == null))
        row.value,
  ];
  final nights = await db
      .customSelect(
        'SELECT AVG((woke_at - fell_asleep_at) / 60000) AS minutes '
        'FROM sleep_entries WHERE woke_at >= ? AND woke_at < ? '
        '${health ? '' : 'AND source IS NULL'}',
        variables: range,
      )
      .getSingle();
  double one(double value) => (value * 10).round() / 10;

  return MonthNumbers(
    workouts: workouts.read<int>('n'),
    sets: workouts.read<int>('sets'),
    volumeKg: workouts.read<double>('kg'),
    minutes: workouts.read<int>('seconds') ~/ 60,
    records: records.read<int>('n'),
    muscles: {
      for (final row in muscles) row.read<String>('muscle'): row.read<int>('n'),
    },
    weightFirst: weights.isEmpty ? null : one(weights.first),
    weightLast: weights.isEmpty ? null : one(weights.last),
    sleepMinutes: nights.read<double?>('minutes')?.round(),
  );
}

/// How long since the last workout, the last three, and what is planned.
Future<Map<String, Object?>?> _idle(
  AppDatabase db, {
  required DateTime now,
}) async {
  final last = await db
      .customSelect(
        'SELECT name, started_at FROM workouts WHERE ended_at IS NOT NULL '
        'ORDER BY started_at DESC LIMIT 3',
      )
      .get();
  if (last.isEmpty) return null;
  final newest = DateTime.fromMillisecondsSinceEpoch(
    last.first.read<int>('started_at'),
  );
  final planned = await db
      .customSelect(
        'SELECT name FROM routines WHERE scheduled_days != 0 '
        'AND plan_id IS NULL ORDER BY sort_order',
      )
      .get();
  return {
    'days_since': DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(newest.year, newest.month, newest.day)).inDays,
    'last_workouts': [
      for (final row in last)
        {
          'name': row.read<String>('name'),
          'date': MomentSubject.day(
            DateTime.fromMillisecondsSinceEpoch(row.read<int>('started_at')),
          ),
        },
    ],
    if (planned.isNotEmpty)
      'planned_routines': [for (final row in planned) row.read<String>('name')],
  };
}

/// The last seven days up to [now], as the week overview reads a week.
Future<Map<String, Object?>?> _free(
  AppDatabase db, {
  required bool health,
  required DateTime now,
}) async {
  final facts = await buildWeekFacts(
    db,
    DateTime(now.year, now.month, now.day - 6),
    now: now,
    healthConnect: health,
  );
  return facts.forCoach();
}

/// A milestone's [subject] in words: `10 workouts`, `12 weken op rij`.
String milestoneLabel(String subject) {
  final parts = subject.split(':');
  final step = int.tryParse(parts.last) ?? 0;
  return switch (MilestoneKind.values.asNameMap()[parts.first]) {
    MilestoneKind.workouts when step == 1 => 'je eerste workout',
    MilestoneKind.workouts => '$step workouts',
    MilestoneKind.streak => '$step weken op rij',
    MilestoneKind.volume => '${(step / 1000).round()} ton getild',
    MilestoneKind.records when step == 1 => 'je eerste record',
    MilestoneKind.records => '$step records',
    null => 'een mijlpaal',
  };
}

/// What a prompt is tried on in the settings, and the line that says so;
/// no subject, and the reason, when there is nothing to try it on.
typedef TrySubject = ({String? subject, String note});

/// A try at [moment]: the newest thing it could be about. In the chat a try
/// is a conversation of its own, and does not count as the moment itself.
Future<TrySubject> trySubject(
  AppDatabase db,
  CoachMoment moment, {
  required bool health,
  required DateTime now,
}) async {
  final tryKey = 'proef-${now.millisecondsSinceEpoch}';
  switch (moment) {
    case CoachMoment.before:
      final running = await db.workoutsDao.getActiveWorkoutRow();
      return running == null
          ? (subject: null, note: 'Start een workout om dit uit te proberen.')
          : (
              subject: running.id,
              note: 'Op "${running.name}", je workout van nu.',
            );
    case CoachMoment.workout:
      final last = await db.workoutsDao.watchLastFinished().first;
      return last == null
          ? (
              subject: null,
              note: 'Na je eerste workout kan je dit uitproberen.',
            )
          : (subject: last.id, note: 'Op "${last.name}", je laatste workout.');
    case CoachMoment.month:
      final month = DateTime(now.year, now.month - 1);
      return (
        subject: MomentSubject.month(month),
        note: 'Op de maand die voorbij is.',
      );
    case CoachMoment.plateau:
      final found = await loadPlateaus(db, now: now, healthConnect: health);
      if (found.isEmpty) {
        return (subject: null, note: 'Er staat nu geen oefening stil.');
      }
      final first = found.first;
      return (
        subject: MomentSubject.plateau(first.exercise.id, first.plateau.since),
        note: 'Op ${first.exercise.name}, die stilstaat.',
      );
    case CoachMoment.wait:
      final today = await loadMorningFacts(db, now, healthConnect: health);
      final check = today.check;
      if (check?.verdict != CheckVerdict.wait) {
        return (
          subject: null,
          note: 'De check zegt vandaag niet dat je beter wacht.',
        );
      }
      // The session the check is about is the one Vandaag leads with.
      final lead = (await loadTodayPlan(db, now)).lead;
      return lead == null
          ? (subject: null, note: 'Er staat vandaag geen sessie klaar.')
          : (
              subject: MomentSubject.wait(now, lead.routine.id),
              note: 'Op de check van vandaag.',
            );
    case CoachMoment.planDone:
      TrainingPlanRow? last;
      for (final plan in await db.plansDao.watchPlans().first) {
        if (plan.state != PlanStatus.done || plan.startDay == null) continue;
        if ((plan.endedAt ?? 0) > (last?.endedAt ?? -1)) last = plan;
      }
      return last == null
          ? (subject: null, note: 'Je hebt nog geen schema afgerond.')
          : (subject: last.id, note: 'Op "${last.name}".');
    case CoachMoment.milestone:
      final totals = await lifetimeTotals(db);
      final reached = [
        for (final m in milestonesFor(
          workouts: totals.workouts,
          longestStreakWeeks: totals.longestStreakWeeks,
          volumeKg: totals.volumeKg,
          records: totals.records,
        ))
          if (m.reached > 0) m,
      ];
      if (reached.isEmpty) {
        return (
          subject: null,
          note: 'Na je eerste workout kan je dit uitproberen.',
        );
      }
      final m = reached.first;
      final subject = MomentSubject.milestone(m.kind, m.steps[m.reached - 1]);
      return (subject: subject, note: 'Op ${milestoneLabel(subject)}.');
    case CoachMoment.weighing:
      final newest = await db.recordsDao.measurements(
        type: MeasurementType.weight,
        limit: 1,
      );
      return newest.isEmpty
          ? (subject: null, note: 'Weeg je eerst een keer.')
          : (
              subject: MomentSubject.day(
                DateTime.fromMillisecondsSinceEpoch(newest.first.measuredAt),
              ),
              note: 'Op je laatste weging.',
            );
    case CoachMoment.idle:
      final last = await db.workoutsDao.watchLastFinished().first;
      return last == null
          ? (
              subject: null,
              note: 'Na je eerste workout kan je dit uitproberen.',
            )
          : (
              subject: tryKey,
              note:
                  'Nu, alsof je een tijd niet trainde. Het antwoord komt als '
                  'een gesprek in de chat.',
            );
    case CoachMoment.free:
      return (
        subject: tryKey,
        note:
            'Nu, op je laatste zeven dagen. Het antwoord komt als een '
            'gesprek in de chat.',
      );
    case CoachMoment.morning || CoachMoment.week:
      return (subject: null, note: '');
  }
}
