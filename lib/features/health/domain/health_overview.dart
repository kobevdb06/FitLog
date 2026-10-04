/// What the health screen shows, worked out from the rows: the nights with
/// their score, and the daily readings with where they usually sit.
///
/// Pure, so it can be tested without a database or a screen.
library;

import '../../../core/calc/recovery.dart';
import '../../../core/calc/sleep_score.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';

/// How far back the health screen looks.
const Duration kHealthWindow = Duration(days: 30);

/// One night, as the screen shows it.
class NightPoint {
  const NightPoint({
    required this.morning,
    required this.length,
    required this.score,
    required this.fromWatch,
    this.lightMinutes,
    this.remMinutes,
    this.deepMinutes,
  });

  final DateTime morning;
  final Duration length;
  final int score;
  final bool fromWatch;
  final int? lightMinutes;
  final int? remMinutes;
  final int? deepMinutes;
}

class SleepOverview {
  const SleepOverview({this.last, this.average, this.nights = const []});

  /// The newest night in the window.
  final NightPoint? last;

  /// How long the nights in the window were on average.
  final Duration? average;

  /// Every night in the window, oldest first.
  final List<NightPoint> nights;
}

SleepOverview sleepOverview(
  List<SleepEntryRow> rows,
  List<VitalsDay> vitals, {
  required DateTime now,
}) {
  final since = now.subtract(kHealthWindow);
  final nights = <NightPoint>[];
  for (final row in rows) {
    final woke = DateTime.fromMillisecondsSinceEpoch(row.wokeAt);
    if (woke.isBefore(since) || woke.isAfter(now)) continue;
    final length = Duration(milliseconds: row.wokeAt - row.fellAsleepAt);
    final morning = morningAgainstUsual(woke, vitals);
    nights.add(
      NightPoint(
        morning: DateTime(woke.year, woke.month, woke.day),
        length: length,
        score: sleepScore(
          asleep: length,
          deepMinutes: row.deepMinutes,
          remMinutes: row.remMinutes,
          hrvDrop: morning.hrvDrop,
          restingHrRise: morning.restingHrRise,
        ).value,
        fromWatch: row.source != null,
        lightMinutes: row.lightMinutes,
        remMinutes: row.remMinutes,
        deepMinutes: row.deepMinutes,
      ),
    );
  }
  nights.sort((a, b) => a.morning.compareTo(b.morning));
  if (nights.isEmpty) return const SleepOverview();

  final minutes = nights.fold<int>(0, (sum, n) => sum + n.length.inMinutes);
  return SleepOverview(
    last: nights.last,
    average: Duration(minutes: minutes ~/ nights.length),
    nights: nights,
  );
}

/// One daily reading - HRV or resting heart rate - over the window.
class ReadingOverview {
  const ReadingOverview({
    this.latest,
    this.latestDay,
    this.usual,
    this.series = const [],
  });

  final double? latest;
  final DateTime? latestDay;

  /// The middle of the window: where it usually sits for you.
  final double? usual;

  /// Oldest first, for the chart.
  final List<ChartPoint> series;
}

ReadingOverview readingOverview(
  List<VitalsDay> days,
  double? Function(VitalsDay day) read, {
  required DateTime now,
}) {
  final since = now.subtract(kHealthWindow);
  final series = <ChartPoint>[
    for (final day in days)
      if (!day.day.isBefore(DateTime(since.year, since.month, since.day)) &&
          !day.day.isAfter(now))
        if (read(day) case final value?) ChartPoint(day.day, value),
  ]..sort((a, b) => a.at.compareTo(b.at));
  if (series.isEmpty) return const ReadingOverview();

  final sorted = [for (final p in series) p.value]..sort();
  final mid = sorted.length ~/ 2;
  return ReadingOverview(
    latest: series.last.value,
    latestDay: series.last.at,
    usual: sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2,
    series: series,
  );
}
