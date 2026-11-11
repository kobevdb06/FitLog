/// Working sets per muscle, and whether a muscle has fallen behind.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

import 'dart:math' as math;

import 'deload.dart';
import 'plateau.dart';
import 'progress_period.dart';

/// Below this many sets a week as usual, a muscle is not called lagging.
const double kLaggingFrom = 4;

/// And it lags under this share of its usual.
const double kLaggingShare = 0.7;

/// Whether [sets] is clearly short of [usual], both per week: under seven
/// tenths of it, and only where the usual is enough to fall short of - a
/// muscle you trained once a month is not lagging the week you skip it.
bool laggingBehind(double sets, double usual) =>
    usual >= kLaggingFrom && sets < usual * kLaggingShare;

/// One muscle over a period, against the stretch as long right before it.
class MuscleSets {
  const MuscleSets({
    required this.muscle,
    required this.perWeek,
    required this.usualPerWeek,
  });

  final String muscle;

  /// Working sets per week in the period.
  final double perWeek;

  /// Working sets per week in the stretch before; 0 when there were none.
  final double usualPerWeek;

  bool get lagging => laggingBehind(perWeek, usualPerWeek);
}

/// The working sets in [sets] per primary muscle, per week of [period] up
/// to [now], the most first.
///
/// Every muscle trained in the period or in the stretch as long before it is
/// in the list: one you stopped training is the one to see, and it would
/// not be there if only the period counted. Both are divided by the weeks of
/// the period so far, so a period that began on Monday is not short of one
/// that is nearly over.
List<MuscleSets> muscleSetsPerWeek(
  Iterable<ProgressSet> sets, {
  required ProgressPeriod period,
  required DateTime now,
}) {
  final start = period.start(now);
  final before = start.subtract(now.difference(start));
  final weeks = period.weeksUpTo(now);
  if (weeks <= 0) return const [];

  // A deload week is lighter on purpose: nothing in it counts, on either
  // side, so it neither makes a muscle lag nor lowers what is usual. Not
  // its deload sessions, and not an ordinary one in the same week either -
  // that one counted while the week came off. One session made lighter on
  // its own is no rest: it counts (DECISIONS 269).
  final rested = <DateTime>{
    for (final set in sets)
      if (set.isDeload && !set.isLight) weekOf(set.startedAt),
  };

  final during = <String, int>{};
  final earlier = <String, int>{};
  for (final set in sets) {
    if (set.startedAt.isAfter(now) || set.startedAt.isBefore(before)) continue;
    if (rested.contains(weekOf(set.startedAt))) continue;
    final into = set.startedAt.isBefore(start) ? earlier : during;
    into[set.primaryMuscle] = (into[set.primaryMuscle] ?? 0) + 1;
  }

  // Only the part of a rested week inside the stretch comes off: a deload
  // that began yesterday took a whole week off the four, and the sets of
  // the three before were divided by too little (DECISIONS 269).
  double restedWeeks(DateTime from, DateTime until) {
    var minutes = 0;
    for (final week in rested) {
      final end = DateTime(week.year, week.month, week.day + 7);
      final a = week.isAfter(from) ? week : from;
      final b = end.isBefore(until) ? end : until;
      if (b.isAfter(a)) minutes += b.difference(a).inMinutes;
    }
    return minutes / Duration.minutesPerDay / 7;
  }

  final weeksDuring = math.max(1.0, weeks - restedWeeks(start, now));
  final weeksEarlier = math.max(1.0, weeks - restedWeeks(before, start));

  return [
    for (final muscle in {...during.keys, ...earlier.keys})
      MuscleSets(
        muscle: muscle,
        perWeek: (during[muscle] ?? 0) / weeksDuring,
        usualPerWeek: (earlier[muscle] ?? 0) / weeksEarlier,
      ),
  ]..sort((a, b) {
    final more = b.perWeek.compareTo(a.perWeek);
    if (more != 0) return more;
    final usual = b.usualPerWeek.compareTo(a.usualPerWeek);
    return usual != 0 ? usual : a.muscle.compareTo(b.muscle);
  });
}
