/// The weeks of a schema: which one it is, what a week asks on top of the
/// sessions as they stand, and how far this week is.
///
/// A schema runs in calendar weeks, Monday to Sunday, like the weekly
/// review: that is when the coach looks back. Its days are a guide, not an
/// appointment - a session counts in the week it was done, on whatever day.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

import 'dart:convert';

/// What a week of a schema is for.
enum PlanWeekKind {
  /// Building up: the sessions, with what the week adds.
  build('build'),

  /// The deload FitLog already has: every session lighter, by the deload
  /// settings.
  deload('deload');

  const PlanWeekKind(this.wire);

  final String wire;

  static PlanWeekKind fromWire(Object? value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => build);
}

/// How far a week may move the sessions: a few sets or repetitions either
/// way. More is a different session, and that is a change the coach
/// proposes, not a week.
const int kPlanWeekMaxStep = 3;

/// One week of a schema, as the coach laid it out.
///
/// The sessions are the same every week; a week says how much more or less
/// of them - a working set more per exercise, a repetition fewer per set.
class PlanWeek {
  const PlanWeek({
    this.kind = PlanWeekKind.build,
    this.sets = 0,
    this.reps = 0,
    this.note,
  });

  final PlanWeekKind kind;

  /// Working sets added to every exercise, or taken away: never below one.
  final int sets;

  /// Repetitions added to every working set's target, or taken away.
  final int reps;

  /// What the week is for, in a few words: "zwaarder, minder herhalingen".
  final String? note;

  bool get isDeload => kind == PlanWeekKind.deload;

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    if (sets != 0) 'sets': sets,
    if (reps != 0) 'reps': reps,
    if (note != null) 'note': note,
  };

  /// Whatever came in, inside the bounds: a week of ten extra sets is a
  /// mistake, not a plan.
  static PlanWeek fromJson(Map<String, Object?> json) {
    int step(Object? value) => value is num
        ? value.round().clamp(-kPlanWeekMaxStep, kPlanWeekMaxStep)
        : 0;
    final note = json['note'];
    return PlanWeek(
      kind: PlanWeekKind.fromWire(json['kind']),
      sets: step(json['sets']),
      reps: step(json['reps']),
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanWeek &&
      other.kind == kind &&
      other.sets == sets &&
      other.reps == reps &&
      other.note == note;

  @override
  int get hashCode => Object.hash(kind, sets, reps, note);
}

/// The weeks stored with a schema; none for a value that is missing or
/// damaged.
List<PlanWeek> decodePlanWeeks(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final week in decoded)
        if (week is Map) PlanWeek.fromJson(week.cast<String, Object?>()),
    ];
  } on FormatException {
    return const [];
  }
}

String encodePlanWeeks(List<PlanWeek> weeks) =>
    jsonEncode([for (final week in weeks) week.toJson()]);

/// The Monday a schema started at [now] begins on: this week's until
/// Wednesday, the next one from Thursday - a first week of three days would
/// count as a week of missed sessions.
DateTime firstPlanMonday(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return now.weekday <= DateTime.wednesday
      ? monday
      : DateTime(monday.year, monday.month, monday.day + 7);
}

/// The first day of [week] - counted from 1 - of a schema that began on
/// [start].
DateTime planWeekStart(DateTime start, int week) =>
    DateTime(start.year, start.month, start.day + 7 * (week - 1));

/// Which week of a schema that began on [start] it is at [at]: 0 before it
/// began, and past its last once it is over.
///
/// Counted on the calendar, in UTC, where every day has 24 hours.
int planWeekAt(DateTime start, DateTime at) {
  final days = DateTime.utc(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  return days < 0 ? 0 : days ~/ 7 + 1;
}

/// How a week of a schema stands.
///
/// [sessions] are the schema's sessions in its order, [done] the ones done
/// this week. The next is the first in that order not done yet: whoever
/// skips Wednesday's session does it on Thursday, not Friday's.
class PlanWeekStanding {
  const PlanWeekStanding({required this.sessions, required this.done});

  final List<String> sessions;
  final Set<String> done;

  String? get next {
    for (final id in sessions) {
      if (!done.contains(id)) return id;
    }
    return null;
  }

  int get doneCount => sessions.where(done.contains).length;

  bool get complete => next == null;

  /// The sessions not done, in order: what the coach looks at on Sunday.
  List<String> get missing => [
    for (final id in sessions)
      if (!done.contains(id)) id,
  ];
}
