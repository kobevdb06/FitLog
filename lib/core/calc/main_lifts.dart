/// The exercises you do most, and whether they are going up.
///
/// Every session is read down to one number the way the plateau check reads
/// it (see [progressPoints]): the estimated one-rep max of the best set, the
/// most repetitions, or the longest hold.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

import 'plateau.dart';

/// How many exercises Voortgang follows.
const int kMainLifts = 4;

/// How many sessions an exercise needs in the period to be followed: one
/// session is a number, not a direction.
const int kMainLiftSessions = 2;

/// How many sessions at each end of the period are compared.
///
/// The best of two rather than one: a light day at the end, or a good one at
/// the start, would otherwise decide the whole period.
const int kTrendEnds = 2;

/// One exercise over the period.
class LiftTrend {
  const LiftTrend({
    required this.exerciseId,
    required this.measure,
    required this.points,
  });

  final String exerciseId;
  final ProgressMeasure measure;

  /// Its sessions in the period, oldest first. Never empty.
  final List<ProgressPoint> points;

  /// The best of the last sessions: where it stands now.
  double get latest => _best(points.sublist(_from(points.length)));

  /// The best of the first sessions, or null while there are too few for
  /// the two ends to be different sessions.
  double? get earliest =>
      points.length < 2 * kTrendEnds ? null : _best(points.take(kTrendEnds));

  /// How much [latest] is above [earliest]; null when there is no
  /// [earliest].
  double? get change => switch (earliest) {
    final from? => latest - from,
    null => null,
  };

  /// The first session of the period: what [change] is counted from.
  DateTime get since => points.first.at;

  /// The newest session.
  DateTime get lastAt => points.last.at;

  static int _from(int length) => length > kTrendEnds ? length - kTrendEnds : 0;

  static double _best(Iterable<ProgressPoint> points) =>
      points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
}

/// Every exercise in [sets] that can be followed, the most often done first.
///
/// An exercise needs [kMainLiftSessions] sessions and a measure (see
/// [ProgressMeasure.of]): assisted work and cardio are left out, as they are
/// for stalling. Between two done as often, the one done last goes first; the
/// id breaks what is left, so the order does not shuffle between rebuilds.
List<LiftTrend> liftTrends(Iterable<ProgressSet> sets) {
  final byExercise = <String, List<ProgressSet>>{};
  for (final set in sets) {
    byExercise.putIfAbsent(set.exerciseId, () => []).add(set);
  }

  final trends = <LiftTrend>[];
  for (final MapEntry(key: id, value: mine) in byExercise.entries) {
    final measure = ProgressMeasure.of(mine.last.category);
    if (measure == null) continue;
    final points = progressPoints(mine, measure);
    if (points.length < kMainLiftSessions) continue;
    trends.add(LiftTrend(exerciseId: id, measure: measure, points: points));
  }

  trends.sort((a, b) {
    final often = b.points.length.compareTo(a.points.length);
    if (often != 0) return often;
    final recent = b.lastAt.compareTo(a.lastAt);
    if (recent != 0) return recent;
    return a.exerciseId.compareTo(b.exerciseId);
  });
  return trends;
}
