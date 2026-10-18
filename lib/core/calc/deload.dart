/// A deload: a stretch of lighter training, and when it is time for one.
///
/// Pure rules, worked out the same way wherever they are used - starting a
/// session, the start sheet's example, the coach's proposal.
library;

import 'dart:math' as math;

import '../db/enums.dart';

/// How much lighter a deload makes a routine.
class DeloadPlan {
  const DeloadPlan({
    this.setsPercent = 50,
    this.weightPercent = 10,
    this.repsPercent = 0,
    this.dropHardSets = true,
    this.prAttempts = false,
  });

  /// Fewer working sets, in percent.
  final int setsPercent;

  /// Less weight, in percent.
  final int weightPercent;

  /// Fewer reps - and fewer seconds for a hold - in percent.
  final int repsPercent;

  /// Drop sets and sets to failure left out.
  final bool dropHardSets;

  /// Whether a PR attempt may be started.
  final bool prAttempts;

  /// How many of [working] sets stay: never none, so every exercise of the
  /// routine is still there.
  int keptSets(int working) {
    if (working <= 0) return 0;
    return math.max(1, (working * (100 - setsPercent) / 100).ceil());
  }

  /// [kg] made lighter, on the nearest [stepKg] - what the bar can hold - and
  /// never heavier than it was.
  double? weight(double? kg, double stepKg) {
    if (kg == null || kg <= 0 || weightPercent <= 0) return kg;
    final lighter = kg * (100 - weightPercent) / 100;
    if (stepKg <= 0) return lighter;
    final stepped = (lighter / stepKg).round() * stepKg;
    return math.min(kg, math.max(0, stepped)).toDouble();
  }

  int? reps(int? reps) {
    if (reps == null || reps <= 0 || repsPercent <= 0) return reps;
    return math.max(1, (reps * (100 - repsPercent) / 100).round());
  }

  int? seconds(int? seconds) {
    if (seconds == null || seconds <= 0 || repsPercent <= 0) return seconds;
    return math.max(5, (seconds * (100 - repsPercent) / 100 / 5).round() * 5);
  }

  /// Whether a set of [type] is left out altogether.
  bool drops(SetType type) =>
      dropHardSets && (type == SetType.drop || type == SetType.failure);

  /// A plan that changes nothing, for an empty workout.
  bool get isEmpty =>
      setsPercent == 0 &&
      weightPercent == 0 &&
      repsPercent == 0 &&
      !dropHardSets;
}

/// One set of an exercise, as it stands when a deload session starts.
class DeloadInput {
  const DeloadInput({
    required this.type,
    this.side,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceM,
  });

  final SetType type;
  final SetSide? side;

  /// From the routine, or else last time's matching set.
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceM;
}

/// What becomes of it: kept with these values, or left out.
class DeloadOutput {
  const DeloadOutput.left()
    : kept = false,
      weightKg = null,
      reps = null,
      durationSeconds = null,
      distanceM = null;

  const DeloadOutput.kept({
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceM,
  }) : kept = true;

  final bool kept;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceM;
}

/// The sets of one exercise, made a deload: warm-ups as they are, drop sets
/// and failure sets out when the plan says so, and of the working sets the
/// first ones the plan keeps - per side for one side at a time - lighter.
List<DeloadOutput> deloadExercise(
  List<DeloadInput> sets, {
  required DeloadPlan plan,
  required double stepKg,
}) {
  final working = <SetSide?, int>{};
  for (final set in sets) {
    if (set.type == SetType.warmup || plan.drops(set.type)) continue;
    working[set.side] = (working[set.side] ?? 0) + 1;
  }
  final keep = {
    for (final MapEntry(:key, :value) in working.entries)
      key: plan.keptSets(value),
  };

  final seen = <SetSide?, int>{};
  return [
    for (final set in sets)
      if (set.type == SetType.warmup)
        DeloadOutput.kept(
          weightKg: set.weightKg,
          reps: set.reps,
          durationSeconds: set.durationSeconds,
          distanceM: set.distanceM,
        )
      else if (plan.drops(set.type) ||
          (seen[set.side] = (seen[set.side] ?? 0) + 1) > keep[set.side]!)
        const DeloadOutput.left()
      else
        DeloadOutput.kept(
          weightKg: plan.weight(set.weightKg, stepKg),
          reps: plan.reps(set.reps),
          durationSeconds: plan.seconds(set.durationSeconds),
          distanceM: set.distanceM,
        ),
  ];
}

/// Why a deload is proposed.
class DeloadReason {
  const DeloadReason({required this.weeks, required this.stalled});

  /// Weeks of training in a row without a deload or a week off.
  final int weeks;

  /// The exercises standing still.
  final List<String> stalled;
}

/// The Monday at midnight of the week [day] is in.
DateTime weekOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// Weeks of training in a row up to [now]: each Monday-to-Sunday week with a
/// session that was not a deload, counted back from this week - or last
/// week, when this one has none yet - until a week without one, or a week a
/// deload was in. A week off is a break too.
int weeksWithoutBreak({
  required DateTime now,
  required Iterable<DateTime> sessions,
  required Iterable<({DateTime from, DateTime until})> deloads,
}) {
  final trained = {for (final s in sessions) weekOf(s)};
  final rested = <DateTime>{};
  for (final deload in deloads) {
    for (
      var week = weekOf(deload.from);
      week.isBefore(deload.until);
      week = DateTime(week.year, week.month, week.day + 7)
    ) {
      rested.add(week);
    }
  }

  var week = weekOf(now);
  if (!trained.contains(week)) {
    week = DateTime(week.year, week.month, week.day - 7);
  }
  var count = 0;
  while (trained.contains(week) && !rested.contains(week)) {
    count++;
    week = DateTime(week.year, week.month, week.day - 7);
  }
  return count;
}

/// Whether to propose a deload: after [weeksLimit] weeks without a break, or
/// with [stalledLimit] exercises standing still. Null when it is not time.
DeloadReason? deloadDue({
  required int weeks,
  required List<String> stalled,
  required int weeksLimit,
  required int stalledLimit,
}) {
  final byWeeks = weeksLimit > 0 && weeks >= weeksLimit;
  final byStalled = stalledLimit > 0 && stalled.length >= stalledLimit;
  if (!byWeeks && !byStalled) return null;
  return DeloadReason(weeks: weeks, stalled: stalled);
}
