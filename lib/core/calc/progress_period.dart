/// The stretch of time Voortgang looks back over, and how it is cut up.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

import 'streak.dart';

/// How far back Voortgang looks. Every chart on the tab follows the one
/// choice.
enum ProgressPeriod {
  fourWeeks('4 weken'),
  threeMonths('3 maanden'),
  year('1 jaar');

  const ProgressPeriod(this.label);

  final String label;

  /// Whether the bars are months rather than weeks. Fifty-two bars of a
  /// year do not fit on a phone, and twelve say the same.
  bool get byMonth => this == year;

  /// How many bars the period has, the newest holding today.
  int get bucketCount => switch (this) {
    fourWeeks => 4,
    threeMonths => 13,
    year => 12,
  };

  /// The start of every bar, oldest first; the last one holds [now].
  ///
  /// Built from calendar dates rather than by subtracting days, so a change
  /// to or from summer time cannot put a bar an hour off midnight.
  List<DateTime> bucketStarts(DateTime now) {
    if (byMonth) {
      return [
        for (var i = bucketCount - 1; i >= 0; i--)
          DateTime(now.year, now.month - i),
      ];
    }
    final week = startOfWeek(now);
    return [
      for (var i = bucketCount - 1; i >= 0; i--)
        DateTime(week.year, week.month, week.day - 7 * i),
    ];
  }

  /// Where the period begins: the start of its first bar.
  DateTime start(DateTime now) => bucketStarts(now).first;

  /// The start of the bar [at] falls in.
  DateTime bucketOf(DateTime at) =>
      byMonth ? DateTime(at.year, at.month) : startOfWeek(at);

  /// The weeks from [start] to [now], counting the part of this week that
  /// has gone: what a number per week is divided by.
  double weeksUpTo(DateTime now) =>
      now.difference(start(now)).inMinutes / Duration.minutesPerDay / 7;
}
