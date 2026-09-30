/// One number for one night, 0 to 100, from what FitLog knows about it.
///
/// FitLog's own score, not a watch's: Health Connect hands over the night and
/// its stages, but no manufacturer's score. It is built from up to three
/// parts, and a part the app knows nothing about is left out rather than
/// guessed - the score is then made of the parts that are there:
///
/// - **Duration**, half of it. Nothing below four hours, everything from
///   eight: the band in which more sleep measurably helps.
/// - **Deep and REM sleep**, a quarter, only when the stages were recorded.
///   Together they are usually 35 to 45 percent of a night. Watches measure
///   them poorly, which is why they weigh a quarter here and nothing at all
///   in the recovery estimate.
/// - **Restoration**, a quarter, only with a watch that reports HRV or
///   resting heart rate: how that morning compares with your own usual.
///
/// Nothing here is advice. It is a reading of a night.
library;

import 'recovery.dart';

/// Below this nothing counts for duration; from the next one, everything.
const double kSleepScoreNoneBelowHours = 4;
const double kSleepScoreFullAtHours = 8;

/// Deep and REM together as a share of the night: nothing at the first,
/// everything from the second.
const double kSleepScoreStagesNone = 0.15;
const double kSleepScoreStagesFull = 0.40;

/// How much a part weighs when it is there.
const int kSleepScoreDurationWeight = 50;
const int kSleepScoreStagesWeight = 25;
const int kSleepScoreRestorationWeight = 25;

/// A night's score and the parts it was made of, each 0 to 1.
class SleepScore {
  const SleepScore({
    required this.value,
    required this.duration,
    this.stages,
    this.restoration,
  });

  /// 0 to 100.
  final int value;

  final double duration;

  /// Null when the night has no stages.
  final double? stages;

  /// Null without a watch's HRV or resting heart rate, or without enough
  /// mornings to know your usual.
  final double? restoration;
}

/// Scores a night that lasted [asleep].
///
/// [hrvDrop] and [restingHrRise] are that morning against your usual, as
/// [morningAgainstUsual] works them out.
SleepScore sleepScore({
  required Duration asleep,
  int? deepMinutes,
  int? remMinutes,
  double? hrvDrop,
  double? restingHrRise,
}) {
  double share(double value, double none, double full) =>
      ((value - none) / (full - none)).clamp(0.0, 1.0);

  final hours = asleep.inMinutes / 60;
  final duration = share(
    hours,
    kSleepScoreNoneBelowHours,
    kSleepScoreFullAtHours,
  );

  double? stages;
  if (deepMinutes != null && remMinutes != null && asleep.inMinutes > 0) {
    stages = share(
      (deepMinutes + remMinutes) / asleep.inMinutes,
      kSleepScoreStagesNone,
      kSleepScoreStagesFull,
    );
  }

  // The worse of the two: a good HRV does not make up for a racing heart.
  double? restoration;
  if (hrvDrop != null) {
    restoration = 1 - share(hrvDrop, 0, kHrvDropFullEffect);
  }
  if (restingHrRise != null) {
    final heart = 1 - share(restingHrRise, 0, kRestingHrRiseFullEffect);
    restoration = restoration == null || heart < restoration
        ? heart
        : restoration;
  }

  var points = duration * kSleepScoreDurationWeight;
  var weight = kSleepScoreDurationWeight;
  if (stages != null) {
    points += stages * kSleepScoreStagesWeight;
    weight += kSleepScoreStagesWeight;
  }
  if (restoration != null) {
    points += restoration * kSleepScoreRestorationWeight;
    weight += kSleepScoreRestorationWeight;
  }

  return SleepScore(
    value: (points / weight * 100).round(),
    duration: duration,
    stages: stages,
    restoration: restoration,
  );
}

/// How the morning of [day] compares with the four weeks before it: how far
/// HRV sat below your usual, as a share, and how far the resting heart rate
/// sat above it, in beats. Null where there is no reading that morning or
/// too few before it to know your usual.
({double? hrvDrop, double? restingHrRise}) morningAgainstUsual(
  DateTime day,
  Iterable<VitalsDay> days,
) {
  final morning = DateTime(day.year, day.month, day.day);
  final from = DateTime(
    morning.year,
    morning.month,
    morning.day - kVitalsBaselineWindow.inDays,
  );

  VitalsDay? that;
  final before = <VitalsDay>[];
  for (final entry in days) {
    final at = DateTime(entry.day.year, entry.day.month, entry.day.day);
    if (at == morning) {
      that = entry;
    } else if (!at.isBefore(from) && at.isBefore(morning)) {
      before.add(entry);
    }
  }
  if (that == null) return (hrvDrop: null, restingHrRise: null);

  double? usual(double? Function(VitalsDay) read) {
    final values = [for (final d in before) ?read(d)]..sort();
    if (values.length < kVitalsForBaseline) return null;
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }

  final hrvUsual = usual((d) => d.hrvMs);
  final heartUsual = usual((d) => d.restingHr);
  return (
    hrvDrop: that.hrvMs == null || hrvUsual == null || hrvUsual <= 0
        ? null
        : 1 - that.hrvMs! / hrvUsual,
    restingHrRise: that.restingHr == null || heartUsual == null
        ? null
        : that.restingHr! - heartUsual,
  );
}
