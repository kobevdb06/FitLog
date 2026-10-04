/// Telling an exercise that has stopped moving from one that is still going.
///
/// Every session of an exercise is read down to one number - the estimated
/// one-rep max of its best set, the most repetitions, or the longest hold -
/// and the question is when that number last went up by something real.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

import '../db/enums.dart';
import 'one_rm.dart';
import 'recovery.dart';

/// How long without a step forward before an exercise counts as stalled.
///
/// Four weeks: long enough that one bad evening, or a week of holidays,
/// does not set it off.
const Duration kPlateauAfter = Duration(days: 28);

/// How many sessions there have to have been since the last step forward.
///
/// Four weeks of not doing an exercise is not being stuck on it.
const int kPlateauSessions = 3;

/// A break this long starts the exercise's history over.
///
/// Coming back after a month off you are rebuilding, not stuck: measured
/// against what you could do before the break, every exercise would be.
const Duration kPlateauBreak = Duration(days: 21);

/// What counts as a step forward: one percent above the last one.
///
/// Less is a matter of which set happened to be the best that day - 97.5 kg
/// for six against 100 for five. A percent is still one repetition more on
/// most sets, or the smallest plate on a heavy lift.
const double kProgressMargin = 0.01;

/// How far back the app looks for a step forward.
const Duration kPlateauLookback = Duration(days: 182);

/// The longest stretch the period before a plateau is compared over.
const Duration kPlateauCompareAtMost = Duration(days: 56);

/// One completed working set, as far as progress goes.
class ProgressSet {
  const ProgressSet({
    required this.workoutId,
    required this.startedAt,
    required this.exerciseId,
    required this.primaryMuscle,
    required this.category,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.side,
  });

  final String workoutId;
  final DateTime startedAt;
  final String exerciseId;
  final String primaryMuscle;
  final ExerciseCategory category;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;

  /// Set while the exercise was done one side at a time.
  final String? side;
}

/// What progress on an exercise is measured in.
enum ProgressMeasure {
  /// The estimated one-rep max of the best set.
  oneRm,

  /// The most repetitions in one set, for work without a weight.
  reps,

  /// The longest hold.
  hold;

  /// The measure that fits [category], or null where the app cannot say.
  ///
  /// Assisted work is left out: less assistance is the progress there, and a
  /// one-rep max read off the assistance would run backwards. Cardio has its
  /// own place, under Gezondheid.
  static ProgressMeasure? of(ExerciseCategory category) => switch (category) {
    ExerciseCategory.barbell ||
    ExerciseCategory.dumbbell ||
    ExerciseCategory.machine ||
    ExerciseCategory.cable => oneRm,
    ExerciseCategory.bodyweight => reps,
    ExerciseCategory.duration => hold,
    ExerciseCategory.assistedBodyweight || ExerciseCategory.cardio => null,
  };

  double? _of(ProgressSet set) => switch (this) {
    oneRm => estimatedOneRm(weightKg: set.weightKg, reps: set.reps),
    reps => set.reps == null || set.reps! <= 0 ? null : set.reps!.toDouble(),
    hold =>
      set.durationSeconds == null || set.durationSeconds! <= 0
          ? null
          : set.durationSeconds!.toDouble(),
  };
}

/// One session of one exercise, read down to a number.
class ProgressPoint {
  const ProgressPoint({
    required this.at,
    required this.workoutId,
    required this.value,
    this.sided = false,
  });

  final DateTime at;
  final String workoutId;
  final double value;

  /// Read off sets done one side at a time.
  final bool sided;
}

/// The sessions of one exercise in [sets], oldest first.
///
/// A session's number comes from its two-handed sets when it has any, and
/// from the one-sided ones otherwise. Only sessions done the same way as the
/// latest are kept: 15 kg in one hand is not a worse day than 30 in two, and
/// letting both in would read every switch as a plateau or a leap.
List<ProgressPoint> progressPoints(
  Iterable<ProgressSet> sets,
  ProgressMeasure measure,
) {
  final byWorkout = <String, List<ProgressSet>>{};
  for (final set in sets) {
    byWorkout.putIfAbsent(set.workoutId, () => []).add(set);
  }

  final points = <ProgressPoint>[];
  for (final entry in byWorkout.entries) {
    final both = [
      for (final s in entry.value)
        if (s.side == null) s,
    ];
    final sided = both.isEmpty;
    double? best;
    for (final set in sided ? entry.value : both) {
      final value = measure._of(set);
      if (value != null && (best == null || value > best)) best = value;
    }
    if (best == null) continue;
    points.add(
      ProgressPoint(
        at: entry.value.first.startedAt,
        workoutId: entry.key,
        value: best,
        sided: sided,
      ),
    );
  }

  points.sort((a, b) => a.at.compareTo(b.at));
  if (points.isEmpty) return points;
  final way = points.last.sided;
  return [
    for (final p in points)
      if (p.sided == way) p,
  ];
}

/// An exercise that has not gone forward for a while.
class Plateau {
  const Plateau({
    required this.measure,
    required this.since,
    required this.runStart,
    required this.best,
    required this.latest,
    required this.lastAt,
    required this.sessionsSince,
  });

  final ProgressMeasure measure;

  /// The session of the last step forward.
  final DateTime since;

  /// Where the exercise's current stretch began: the first session after the
  /// last long break, or the first one the app looked at.
  final DateTime runStart;

  /// The best number of the stretch.
  final double best;

  /// The number of the newest session.
  final double latest;

  /// When that newest session was.
  final DateTime lastAt;

  /// How many sessions came after [since] without a step forward.
  final int sessionsSince;

  /// Whole weeks since the last step forward.
  int weeksAt(DateTime now) => now.difference(since).inDays ~/ 7;
}

/// Whether the exercise behind [points] has stalled, as of [now].
///
/// Null when it is still going forward, when there is too little to go on,
/// and when it has not been done for [kPlateauBreak]: not doing an exercise
/// is not being stuck on it.
Plateau? detectPlateau(
  List<ProgressPoint> points, {
  required ProgressMeasure measure,
  required DateTime now,
}) {
  if (points.isEmpty) return null;
  if (now.difference(points.last.at) >= kPlateauBreak) return null;

  var start = 0;
  for (var i = 1; i < points.length; i++) {
    if (points[i].at.difference(points[i - 1].at) >= kPlateauBreak) start = i;
  }
  final run = points.sublist(start);

  // The level is where the last step forward landed, not the best so far:
  // creeping up by half a percent a week adds up to progress, and measured
  // against the best of the week before it never would.
  var level = run.first.value;
  var since = run.first.at;
  var best = level;
  var after = 0;
  for (final point in run.skip(1)) {
    if (point.value >= level * (1 + kProgressMargin)) {
      level = point.value;
      since = point.at;
      after = 0;
    } else {
      after++;
    }
    if (point.value > best) best = point.value;
  }

  if (now.difference(since) < kPlateauAfter || after < kPlateauSessions) {
    return null;
  }
  return Plateau(
    measure: measure,
    since: since,
    runStart: run.first.at,
    best: best,
    latest: run.last.value,
    lastAt: run.last.at,
    sessionsSince: after,
  );
}

/// What went on while an exercise stood still, and in the stretch before it
/// when there was one.
class PlateauContext {
  const PlateauContext({
    required this.sessions,
    required this.sessionsPerWeek,
    required this.setsPerSession,
    this.typicalReps,
    required this.muscleSetsPerWeek,
    this.muscleSetsPerWeekBefore,
    this.averageSleep,
    this.averageSleepBefore,
    required this.unrecovered,
  });

  /// Sessions of the exercise since the last step forward.
  final int sessions;

  final double sessionsPerWeek;

  /// Working sets of the exercise per session.
  final double setsPerSession;

  /// The median repetitions of those sets. Null for holds.
  final int? typicalReps;

  /// Working sets per week for the exercise's muscle, every exercise counted.
  final double muscleSetsPerWeek;
  final double? muscleSetsPerWeekBefore;

  /// The average night, when nights were filled in or came from a watch.
  final Duration? averageSleep;
  final Duration? averageSleepBefore;

  /// Of [sessions], how many began while the muscle was still recovering from
  /// the time before.
  final int unrecovered;
}

/// The facts around [plateau] of [exerciseId] up to [now].
///
/// [sets] holds every working set the app looked at, of every exercise: the
/// muscle's weekly sets need them all. [history] is the recovery estimate of
/// the exercise's muscle, session by session (see [recoveryHistory]).
///
/// The stretch before is as long as the plateau itself, at most
/// [kPlateauCompareAtMost], and never reaches back past [Plateau.runStart]:
/// before that there was a break, and a break says nothing about training.
PlateauContext plateauContext({
  required Plateau plateau,
  required String exerciseId,
  required String primaryMuscle,
  required Iterable<ProgressSet> sets,
  required DateTime now,
  Iterable<SleepNight> nights = const [],
  Iterable<RecoveryEstimate> history = const [],
}) {
  final since = plateau.since;
  final stalled = now.difference(since);
  final weeks = stalled.inMinutes / Duration.minutesPerDay / 7;

  final span = stalled > kPlateauCompareAtMost
      ? kPlateauCompareAtMost
      : stalled;
  var from = since.subtract(span);
  if (from.isBefore(plateau.runStart)) from = plateau.runStart;
  final before = since.difference(from);
  final weeksBefore = before.inMinutes / Duration.minutesPerDay / 7;
  // A week at least, or a rate per week means nothing.
  final compare = before >= const Duration(days: 7);

  bool during(DateTime at) => at.isAfter(since) && !at.isAfter(now);
  bool earlier(DateTime at) => !at.isBefore(from) && !at.isAfter(since);

  final mine = [
    for (final s in sets)
      if (s.exerciseId == exerciseId && during(s.startedAt)) s,
  ];
  final workouts = {for (final s in mine) s.workoutId};
  final reps = [
    for (final s in mine)
      if (s.reps != null && s.reps! > 0) s.reps!,
  ]..sort();

  var muscleSets = 0;
  var muscleSetsBefore = 0;
  for (final s in sets) {
    if (s.primaryMuscle != primaryMuscle) continue;
    if (during(s.startedAt)) muscleSets++;
    if (earlier(s.startedAt)) muscleSetsBefore++;
  }

  Duration? average(bool Function(DateTime) inside) {
    final slept = [
      for (final night in nights)
        if (inside(night.wokeAt)) night.duration,
    ];
    if (slept.isEmpty) return null;
    final total = slept.fold<int>(0, (sum, d) => sum + d.inMinutes);
    return Duration(minutes: (total / slept.length).round());
  }

  return PlateauContext(
    sessions: workouts.length,
    sessionsPerWeek: weeks <= 0 ? 0 : workouts.length / weeks,
    setsPerSession: workouts.isEmpty ? 0 : mine.length / workouts.length,
    typicalReps: plateau.measure == ProgressMeasure.hold || reps.isEmpty
        ? null
        : reps[reps.length ~/ 2],
    muscleSetsPerWeek: weeks <= 0 ? 0 : muscleSets / weeks,
    muscleSetsPerWeekBefore: compare ? muscleSetsBefore / weeksBefore : null,
    averageSleep: average(during),
    averageSleepBefore: compare ? average(earlier) : null,
    unrecovered: [
      for (final estimate in history)
        if (workouts.contains(estimate.workoutId) &&
            estimate.carryover > Duration.zero)
          estimate,
    ].length,
  );
}
