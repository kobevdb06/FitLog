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

  /// Everything FitLog uses, between [from] and [to].
  Future<HealthSnapshot> read({required DateTime from, required DateTime to});

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
