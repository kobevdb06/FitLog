import 'package:drift/drift.dart' show Variable;

import '../../../core/calc/recovery.dart';
import '../../../core/calc/schedule.dart';
import '../../../core/calc/sleep_score.dart';
import '../../../core/db/database.dart';
import '../../progress/data/plateau_loader.dart';
import '../../progress/data/recovery_loader.dart';
import '../domain/week_facts.dart';

/// How many weeks before make up "usual".
const int kReviewUsualWeeks = 4;

/// Which record of an exercise a week mentions, when it got several: the one
/// that says most about getting stronger.
const List<String> _recordOrder = [
  'est_1rm',
  'max_weight',
  'max_reps',
  'max_set_volume',
  'max_duration',
  'max_distance',
];

/// The week from [start], a Monday at midnight, as of [now].
///
/// A week still running is read up to [now]: a planned day only counts as
/// missed once it is over, and today is not over yet.
Future<WeekFacts> buildWeekFacts(
  AppDatabase db,
  DateTime start, {
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final end = DateTime(start.year, start.month, start.day + 7);
  final upTo = at.isBefore(end) ? at : end;
  final today = DateTime(at.year, at.month, at.day);
  final before = DateTime(
    start.year,
    start.month,
    start.day - 7 * kReviewUsualWeeks,
  );
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  // --- Sessions, and the plan they were measured against -------------------

  final workouts = await db
      .customSelect(
        'SELECT routine_id, total_volume_kg FROM workouts '
        'WHERE ended_at IS NOT NULL AND started_at >= ? AND started_at < ?',
        variables: [Variable.withInt(ms(start)), Variable.withInt(ms(end))],
      )
      .get();
  final doneByRoutine = <String, int>{};
  for (final row in workouts) {
    final routine = row.read<String?>('routine_id');
    if (routine != null) {
      doneByRoutine[routine] = (doneByRoutine[routine] ?? 0) + 1;
    }
  }

  final scheduled = await db
      .customSelect(
        'SELECT id, name, scheduled_days FROM routines '
        'WHERE scheduled_days != 0 ORDER BY sort_order',
      )
      .get();
  int? planned;
  var plannedDone = 0;
  final missed = <MissedRoutine>[];
  for (final row in scheduled) {
    final days = WeekdaySet(row.read<int>('scheduled_days')).weekdays;
    if (days.isEmpty) continue;
    final done = doneByRoutine[row.read<String>('id')] ?? 0;
    planned = (planned ?? 0) + days.length;
    plannedDone += done < days.length ? done : days.length;

    // A day is only missed once it is over.
    final over = [
      for (final d in days)
        if (DateTime(
          start.year,
          start.month,
          start.day + d - 1,
        ).isBefore(today))
          d,
    ];
    final short = over.length - done;
    if (short > 0) {
      missed.add(
        MissedRoutine(
          name: row.read<String>('name'),
          times: short,
          weekdays: done == 0 ? over : const [],
        ),
      );
    }
  }

  // --- Sets, per muscle against the weeks before ---------------------------

  final perMuscle = await db
      .customSelect(
        'SELECT e.primary_muscle AS muscle, '
        'CASE WHEN w.started_at >= ? THEN 1 ELSE 0 END AS this_week, '
        'COUNT(*) AS sets '
        'FROM workout_sets ws '
        'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
        'JOIN workouts w ON w.id = we.workout_id '
        'JOIN exercises e ON e.id = we.exercise_id '
        "WHERE ws.is_completed = 1 AND ws.set_type != 'warmup' "
        'AND w.ended_at IS NOT NULL AND w.started_at >= ? '
        'AND w.started_at < ? '
        'GROUP BY e.primary_muscle, this_week',
        variables: [
          Variable.withInt(ms(start)),
          Variable.withInt(ms(before)),
          Variable.withInt(ms(end)),
        ],
      )
      .get();
  final thisWeek = <String, int>{};
  final earlier = <String, int>{};
  for (final row in perMuscle) {
    final target = row.read<int>('this_week') == 1 ? thisWeek : earlier;
    target[row.read<String>('muscle')] = row.read<int>('sets');
  }
  final muscles =
      [
        for (final muscle in {...thisWeek.keys, ...earlier.keys})
          MuscleWeek(
            muscle: muscle,
            sets: thisWeek[muscle] ?? 0,
            usual: (earlier[muscle] ?? 0) / kReviewUsualWeeks,
          ),
      ]..sort((a, b) {
        final bySets = b.sets.compareTo(a.sets);
        return bySets != 0 ? bySets : b.usual.compareTo(a.usual);
      });

  // --- Records -------------------------------------------------------------

  final recordRows = await db
      .customSelect(
        'SELECT e.name AS name, pr.record_type AS type, pr.value AS value '
        'FROM personal_records pr JOIN exercises e ON e.id = pr.exercise_id '
        'WHERE pr.achieved_at >= ? AND pr.achieved_at < ?',
        variables: [Variable.withInt(ms(start)), Variable.withInt(ms(end))],
      )
      .get();
  final best = <String, WeekRecord>{};
  int rank(String type) {
    final i = _recordOrder.indexOf(type);
    return i < 0 ? _recordOrder.length : i;
  }

  for (final row in recordRows) {
    final record = WeekRecord(
      exercise: row.read<String>('name'),
      type: row.read<String>('type'),
      value: row.read<double>('value'),
    );
    final known = best[record.exercise];
    if (known == null || rank(record.type) < rank(known.type)) {
      best[record.exercise] = record;
    }
  }

  // --- Standing still, and moving again ------------------------------------

  final atEnd = await loadPlateaus(db, now: upTo);
  final atStart = await loadPlateaus(db, now: start);
  final doneThisWeek = {
    for (final row
        in await db
            .customSelect(
              'SELECT DISTINCT we.exercise_id AS id FROM workout_sets ws '
              'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
              'JOIN workouts w ON w.id = we.workout_id '
              'WHERE ws.is_completed = 1 AND w.ended_at IS NOT NULL '
              'AND w.started_at >= ? AND w.started_at < ?',
              variables: [
                Variable.withInt(ms(start)),
                Variable.withInt(ms(end)),
              ],
            )
            .get())
      row.read<String>('id'),
  };
  final stillAtEnd = {for (final p in atEnd) p.exercise.id};

  // --- Nights and the watch ------------------------------------------------

  final nights = [
    for (final row in await db.recoveryDao.sleepSince(before)) row,
  ];
  final vitals = [
    for (final row in await db.healthDao.vitalsSince(
      before.subtract(kVitalsBaselineWindow),
    ))
      vitalsDayOf(row),
  ];
  bool inWeek(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  bool inUsual(DateTime d) => !d.isBefore(before) && d.isBefore(start);

  int? averageMinutes(Iterable<SleepEntryRow> rows) {
    final list = rows.toList();
    if (list.isEmpty) return null;
    final total = list.fold<int>(
      0,
      (sum, r) => sum + (r.wokeAt - r.fellAsleepAt),
    );
    return (total / list.length / 60000).round();
  }

  final weekNights = [
    for (final n in nights)
      if (inWeek(DateTime.fromMillisecondsSinceEpoch(n.wokeAt))) n,
  ];
  final scores = [
    for (final n in weekNights)
      () {
        final woke = DateTime.fromMillisecondsSinceEpoch(n.wokeAt);
        final morning = morningAgainstUsual(woke, vitals);
        return sleepScore(
          asleep: Duration(milliseconds: n.wokeAt - n.fellAsleepAt),
          deepMinutes: n.deepMinutes,
          remMinutes: n.remMinutes,
          hrvDrop: morning.hrvDrop,
          restingHrRise: morning.restingHrRise,
        ).value;
      }(),
  ];

  double? mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  double? median(Iterable<double> values) {
    final list = values.toList()..sort();
    if (list.length < kVitalsForBaseline) return null;
    final mid = list.length ~/ 2;
    return list.length.isOdd ? list[mid] : (list[mid - 1] + list[mid]) / 2;
  }

  double? oneDecimal(double? v) => v == null ? null : (v * 10).round() / 10;

  final weekVitals = [
    for (final v in vitals)
      if (inWeek(v.day)) v,
  ];
  final usualVitals = [
    for (final v in vitals)
      if (inUsual(v.day)) v,
  ];
  final steps = await db
      .customSelect(
        'SELECT AVG(steps) AS steps FROM daily_vitals '
        'WHERE steps IS NOT NULL AND day >= ? AND day < ?',
        variables: [Variable.withInt(ms(start)), Variable.withInt(ms(end))],
      )
      .getSingle();

  return WeekFacts(
    start: start,
    workouts: workouts.length,
    planned: planned,
    plannedDone: plannedDone,
    missed: missed,
    sets: thisWeek.values.fold(0, (a, b) => a + b),
    volumeKg: workouts.fold<double>(
      0,
      (sum, row) => sum + row.read<double>('total_volume_kg'),
    ),
    records: best.values.toList(),
    muscles: muscles.take(10).toList(),
    stalled: [
      for (final p in atEnd)
        StalledExercise(
          exercise: p.exercise.name,
          weeks: p.plateau.weeksAt(upTo),
        ),
    ],
    movingAgain: [
      for (final p in atStart)
        if (!stillAtEnd.contains(p.exercise.id) &&
            doneThisWeek.contains(p.exercise.id))
          p.exercise.name,
    ],
    sleepMinutes: averageMinutes(weekNights),
    usualSleepMinutes: averageMinutes([
      for (final n in nights)
        if (inUsual(DateTime.fromMillisecondsSinceEpoch(n.wokeAt))) n,
    ]),
    sleepScore: scores.isEmpty
        ? null
        : (scores.reduce((a, b) => a + b) / scores.length).round(),
    hrvMs: oneDecimal(mean([for (final v in weekVitals) ?v.hrvMs])),
    usualHrvMs: oneDecimal(median([for (final v in usualVitals) ?v.hrvMs])),
    restingHr: oneDecimal(mean([for (final v in weekVitals) ?v.restingHr])),
    usualRestingHr: oneDecimal(
      median([for (final v in usualVitals) ?v.restingHr]),
    ),
    steps: steps.read<double?>('steps')?.round(),
  );
}
