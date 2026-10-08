/// One week, Monday to Sunday, in the numbers the weekly review shows: what
/// was planned and done, the sets per muscle against the weeks before, the
/// records, what stalled or moved again, and how you slept and recovered.
///
/// Worked out from the logbook whenever it is shown, so a session logged on
/// Sunday night is in it. What the coach was shown is kept with its text.
library;

import '../../../core/calc/muscle_sets.dart';

/// A routine that was planned on days of the week and not done as often.
class MissedRoutine {
  const MissedRoutine({
    required this.name,
    required this.times,
    this.weekdays = const [],
  });

  final String name;

  /// How many of its planned days went without it.
  final int times;

  /// Which days, when it was not done at all; empty when it was done on
  /// other days than planned and only the count is known.
  final List<int> weekdays;

  Map<String, Object?> toJson() => {
    'name': name,
    'times': times,
    'weekdays': weekdays,
  };

  static MissedRoutine fromJson(Map<String, Object?> json) => MissedRoutine(
    name: '${json['name']}',
    times: (json['times'] as num?)?.toInt() ?? 1,
    weekdays: [
      for (final d in json['weekdays'] as List? ?? const []) (d as num).toInt(),
    ],
  );
}

/// The best record an exercise got that week.
class WeekRecord {
  const WeekRecord({
    required this.exercise,
    required this.type,
    required this.value,
  });

  final String exercise;

  /// The wire value of a `PrType`.
  final String type;
  final double value;

  Map<String, Object?> toJson() => {
    'exercise': exercise,
    'type': type,
    'value': value,
  };

  static WeekRecord fromJson(Map<String, Object?> json) => WeekRecord(
    exercise: '${json['exercise']}',
    type: '${json['type']}',
    value: (json['value'] as num).toDouble(),
  );
}

/// The working sets of one muscle that week, against the four weeks before.
class MuscleWeek {
  const MuscleWeek({
    required this.muscle,
    required this.sets,
    required this.usual,
  });

  final String muscle;
  final int sets;

  /// The average per week over the four weeks before.
  final double usual;

  /// Clearly less than usual: under seven tenths of it, and only where the
  /// usual is enough to fall short of - a muscle you trained once a month is
  /// not lagging the week you skip it.
  bool get lagging => laggingBehind(sets.toDouble(), usual);

  Map<String, Object?> toJson() => {
    'muscle': muscle,
    'sets': sets,
    'usual_per_week': (usual * 10).round() / 10,
  };

  static MuscleWeek fromJson(Map<String, Object?> json) => MuscleWeek(
    muscle: '${json['muscle']}',
    sets: (json['sets'] as num).toInt(),
    usual: (json['usual_per_week'] as num).toDouble(),
  );
}

/// An exercise that stood still at the end of the week.
class StalledExercise {
  const StalledExercise({required this.exercise, required this.weeks});

  final String exercise;
  final int weeks;

  Map<String, Object?> toJson() => {'exercise': exercise, 'weeks': weeks};

  static StalledExercise fromJson(Map<String, Object?> json) => StalledExercise(
    exercise: '${json['exercise']}',
    weeks: (json['weeks'] as num).toInt(),
  );
}

class WeekFacts {
  const WeekFacts({
    required this.start,
    required this.workouts,
    this.planned,
    this.plannedDone = 0,
    this.missed = const [],
    required this.sets,
    required this.volumeKg,
    this.records = const [],
    this.muscles = const [],
    this.stalled = const [],
    this.movingAgain = const [],
    this.sleepMinutes,
    this.usualSleepMinutes,
    this.sleepScore,
    this.hrvMs,
    this.usualHrvMs,
    this.restingHr,
    this.usualRestingHr,
    this.steps,
  });

  /// Monday at midnight.
  final DateTime start;

  /// Finished sessions, planned or not.
  final int workouts;

  /// How many sessions the routines on a schedule asked for that week, or
  /// null when nothing was planned.
  final int? planned;

  /// How many of those were done.
  final int plannedDone;

  /// Planned days that went by without the routine.
  final List<MissedRoutine> missed;

  /// Completed working sets, warm-ups left out.
  final int sets;
  final double volumeKg;

  final List<WeekRecord> records;

  /// Most sets first.
  final List<MuscleWeek> muscles;

  final List<StalledExercise> stalled;

  /// Exercises that stood still when the week began, were done that week,
  /// and no longer do.
  final List<String> movingAgain;

  /// The average night, and the four weeks before; null without nights.
  final int? sleepMinutes;
  final int? usualSleepMinutes;

  /// The average of FitLog's sleep score over the nights of the week.
  final int? sleepScore;

  /// The week's average, and the usual: the median of the four weeks
  /// before. Null without a watch.
  final double? hrvMs;
  final double? usualHrvMs;
  final double? restingHr;
  final double? usualRestingHr;

  /// Steps per day, over the days that have a count.
  final int? steps;

  /// Workouts beyond the planned ones.
  int get extra => workouts - plannedDone;

  Map<String, Object?> toJson() => {
    'start': start.millisecondsSinceEpoch,
    'workouts': workouts,
    'planned': planned,
    'planned_done': plannedDone,
    'missed': [for (final m in missed) m.toJson()],
    'sets': sets,
    'volume_kg': volumeKg.round(),
    'records': [for (final r in records) r.toJson()],
    'muscles': [for (final m in muscles) m.toJson()],
    'stalled': [for (final s in stalled) s.toJson()],
    'moving_again': movingAgain,
    'sleep_minutes': sleepMinutes,
    'usual_sleep_minutes': usualSleepMinutes,
    'sleep_score': sleepScore,
    'hrv_ms': hrvMs,
    'usual_hrv_ms': usualHrvMs,
    'resting_hr': restingHr,
    'usual_resting_hr': usualRestingHr,
    'steps_per_day': steps,
  };

  static WeekFacts fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> list(String key) => [
      for (final e in json[key] as List? ?? const [])
        (e as Map).cast<String, Object?>(),
    ];
    double? real(String key) => (json[key] as num?)?.toDouble();
    int? whole(String key) => (json[key] as num?)?.toInt();

    return WeekFacts(
      start: DateTime.fromMillisecondsSinceEpoch(whole('start')!),
      workouts: whole('workouts') ?? 0,
      planned: whole('planned'),
      plannedDone: whole('planned_done') ?? 0,
      missed: [for (final m in list('missed')) MissedRoutine.fromJson(m)],
      sets: whole('sets') ?? 0,
      volumeKg: real('volume_kg') ?? 0,
      records: [for (final r in list('records')) WeekRecord.fromJson(r)],
      muscles: [for (final m in list('muscles')) MuscleWeek.fromJson(m)],
      stalled: [for (final s in list('stalled')) StalledExercise.fromJson(s)],
      movingAgain: [for (final e in json['moving_again'] as List? ?? []) '$e'],
      sleepMinutes: whole('sleep_minutes'),
      usualSleepMinutes: whole('usual_sleep_minutes'),
      sleepScore: whole('sleep_score'),
      hrvMs: real('hrv_ms'),
      usualHrvMs: real('usual_hrv_ms'),
      restingHr: real('resting_hr'),
      usualRestingHr: real('usual_resting_hr'),
      steps: whole('steps_per_day'),
    );
  }

  /// What the coach is given: the same, with the lagging muscles named and
  /// the week as dates rather than a number.
  Map<String, Object?> forCoach() {
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return {
      ...toJson(),
      'start': day(start),
      'end': day(DateTime(start.year, start.month, start.day + 6)),
      'lagging_muscles': [
        for (final m in muscles)
          if (m.lagging) m.muscle,
      ],
    };
  }
}
