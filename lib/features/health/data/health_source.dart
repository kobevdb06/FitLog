import '../../../core/db/enums.dart';

/// What FitLog asks of Health Connect, in its own words.
///
/// The app never talks to the Health Connect plugin directly: everything goes
/// through this, so a test can hand over a phone's worth of nights and
/// readings without a phone, and the plugin's own types stay out of the rest
/// of the code.
///
/// Nothing here touches the network. Health Connect is a store on the phone
/// itself; reading from it or writing to it is a question to another app on
/// the same device.
abstract class HealthSource {
  /// Whether Health Connect is on this phone and up to date.
  Future<HealthAvailability> availability();

  /// Opens the Play Store on Health Connect, to install or update it.
  Future<void> openInstall();

  /// Whether FitLog may read everything it asks for.
  Future<bool> hasAccess();

  /// Shows Health Connect's own permission screen. True when the user
  /// granted at least something.
  Future<bool> requestAccess();

  /// Gives back every permission FitLog was granted.
  Future<void> revokeAccess();

  /// Everything FitLog uses, between [from] and [to] - except the heart
  /// rate, which is asked for one session at a time with [heartRate].
  Future<HealthSnapshot> read({required DateTime from, required DateTime to});

  /// Every heart rate sample between [from] and [to]. Empty without a watch,
  /// or without permission to read it.
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  });

  /// Every blood oxygen reading between [from] and [to], in percent.
  Future<List<ImportedReading>> oxygenSaturation({
    required DateTime from,
    required DateTime to,
  });

  /// The steps between [from] and [to], counted once across every app that
  /// wrote any. Null when there are none or they may not be read.
  Future<int?> steps({required DateTime from, required DateTime to});

  /// What FitLog asks for but may not read, in the words of its screen:
  /// "slaap", "hartslag". Empty when it may read everything.
  Future<List<String>> missingAccess();

  /// Shows Health Connect's permission screen for writing sessions. True
  /// when the user allowed it.
  Future<bool> requestWriteAccess();

  /// Writes one finished session as strength training, and returns the id
  /// Health Connect gave it - or null when it was not written.
  Future<String?> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  });

  /// Takes a session FitLog wrote out of Health Connect again.
  Future<void> deleteWorkout(String id);

  /// Asks to read while FitLog is not on screen, which the morning report
  /// needs: Health Connect otherwise only answers an app you are looking at.
  /// True when allowed, or when this phone does not ask for it.
  Future<bool> requestBackgroundAccess();
}

enum HealthAvailability {
  available,

  /// Installed, but too old for what FitLog asks.
  needsUpdate,

  /// Not on this phone.
  unavailable,
}

/// One night, as Health Connect had it.
class ImportedNight {
  const ImportedNight({
    required this.fellAsleepAt,
    required this.wokeAt,
    required this.source,
    this.lightMinutes,
    this.remMinutes,
    this.deepMinutes,
  });

  final DateTime fellAsleepAt;
  final DateTime wokeAt;

  /// The app that wrote it, as a package name.
  final String source;

  final int? lightMinutes;
  final int? remMinutes;
  final int? deepMinutes;

  Duration get length => wokeAt.difference(fellAsleepAt);
}

/// One measurement of a single number at a moment: an HRV or a resting heart
/// rate reading.
class ImportedReading {
  const ImportedReading({required this.at, required this.value});

  final DateTime at;
  final double value;
}

class ImportedWeight {
  const ImportedWeight({
    required this.id,
    required this.at,
    required this.kg,
    required this.source,
  });

  /// Health Connect's own id for the record.
  final String id;
  final DateTime at;
  final double kg;
  final String source;
}

class ImportedCardio {
  const ImportedCardio({
    required this.id,
    required this.start,
    required this.end,
    required this.kind,
    required this.source,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final CardioKind kind;
  final String source;
}

/// What one read brought in.
class HealthSnapshot {
  const HealthSnapshot({
    this.nights = const [],
    this.hrv = const [],
    this.restingHr = const [],
    this.weights = const [],
    this.cardio = const [],
  });

  final List<ImportedNight> nights;

  /// RMSSD in milliseconds.
  final List<ImportedReading> hrv;

  /// Beats per minute.
  final List<ImportedReading> restingHr;
  final List<ImportedWeight> weights;
  final List<ImportedCardio> cardio;

  bool get isEmpty =>
      nights.isEmpty &&
      hrv.isEmpty &&
      restingHr.isEmpty &&
      weights.isEmpty &&
      cardio.isEmpty;
}

/// The heart rate during one session: the average and the highest.
class HeartRateSummary {
  const HeartRateSummary({
    required this.average,
    required this.highest,
    required this.samples,
  });

  final int average;
  final int highest;
  final int samples;
}

/// Works out [HeartRateSummary] from the samples between [from] and [to].
///
/// Only samples inside the session: Health Connect hands over whole records,
/// and a watch's record can run on well past the last set. Null when none
/// fall inside it.
HeartRateSummary? summarizeHeartRate(
  Iterable<ImportedReading> samples, {
  required DateTime from,
  required DateTime to,
}) {
  final inside = [
    for (final sample in samples)
      if (!sample.at.isBefore(from) &&
          !sample.at.isAfter(to) &&
          sample.value > 0)
        sample.value,
  ];
  if (inside.isEmpty) return null;
  final total = inside.fold<double>(0, (sum, v) => sum + v);
  return HeartRateSummary(
    average: (total / inside.length).round(),
    highest: inside.reduce((a, b) => a > b ? a : b).round(),
    samples: inside.length,
  );
}

/// How long the stretch is that a resting heart rate is the lowest average
/// of, and how many samples it needs before its average means anything.
const Duration kRestingWindow = Duration(minutes: 30);
const int kRestingWindowSamples = 3;

/// A resting heart rate worked out from the heart rate during one night:
/// the lowest half hour while asleep, by the middle reading of each half
/// hour.
///
/// For a watch that measures the heart rate all night but does not hand
/// Health Connect a resting heart rate of its own - most do the same sum
/// internally. A stretch rather than one sample, and its middle reading
/// rather than its average: with a reading every ten minutes, one reading
/// of 38 between two of 56 is the watch slipping, not the heart, and an
/// average would still make it 50. Null when no half hour of the night had
/// [kRestingWindowSamples] samples.
double? restingHeartRateFromNight(
  Iterable<ImportedReading> samples, {
  required DateTime from,
  required DateTime to,
}) {
  final night = [
    for (final s in samples)
      if (!s.at.isBefore(from) && !s.at.isAfter(to) && s.value > 0) s,
  ]..sort((a, b) => a.at.compareTo(b.at));

  double? lowest;
  for (var start = 0; start < night.length; start++) {
    final until = night[start].at.add(kRestingWindow);
    final window = [
      for (var i = start; i < night.length && night[i].at.isBefore(until); i++)
        night[i].value,
    ];
    if (window.length < kRestingWindowSamples) continue;
    window.sort();
    final mid = window.length ~/ 2;
    final middle = window.length.isOdd
        ? window[mid]
        : (window[mid - 1] + window[mid]) / 2;
    if (lowest == null || middle < lowest) lowest = middle;
  }
  return lowest == null ? null : (lowest * 10).round() / 10;
}

/// The blood oxygen during one night: the average and the lowest reading.
/// Null with fewer than three readings inside it - one spot check is not a
/// night.
({double average, double lowest})? oxygenFromNight(
  Iterable<ImportedReading> samples, {
  required DateTime from,
  required DateTime to,
}) {
  final night = [
    for (final s in samples)
      if (!s.at.isBefore(from) && !s.at.isAfter(to) && s.value > 0) s.value,
  ];
  if (night.length < 3) return null;
  final total = night.fold<double>(0, (sum, v) => sum + v);
  return (
    average: (total / night.length * 10).round() / 10,
    lowest: night.reduce((a, b) => a < b ? a : b),
  );
}
