/// Working sets per muscle, and whether a muscle has fallen behind.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

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

  final during = <String, int>{};
  final earlier = <String, int>{};
  for (final set in sets) {
    if (set.startedAt.isAfter(now) || set.startedAt.isBefore(before)) continue;
    final into = set.startedAt.isBefore(start) ? earlier : during;
    into[set.primaryMuscle] = (into[set.primaryMuscle] ?? 0) + 1;
  }

  return [
    for (final muscle in {...during.keys, ...earlier.keys})
      MuscleSets(
        muscle: muscle,
        perWeek: (during[muscle] ?? 0) / weeks,
        usualPerWeek: (earlier[muscle] ?? 0) / weeks,
      ),
  ]..sort((a, b) {
    final more = b.perWeek.compareTo(a.perWeek);
    if (more != 0) return more;
    final usual = b.usualPerWeek.compareTo(a.usualPerWeek);
    return usual != 0 ? usual : a.muscle.compareTo(b.muscle);
  });
}
