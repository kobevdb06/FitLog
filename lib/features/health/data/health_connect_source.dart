import 'package:health/health.dart';

import '../../../core/db/enums.dart';
import 'health_source.dart';

/// [HealthSource] on top of the `health` plugin, which speaks to Android's
/// Health Connect.
class HealthConnectSource implements HealthSource {
  HealthConnectSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// FitLog's own package, so its own workouts, once written to Health
  /// Connect, are not read back as somebody else's session.
  static const String ownPackage = 'be.fitlog.app';

  /// What FitLog reads, and nothing else. Each of these is its own line on
  /// Health Connect's permission screen, and the user can grant or refuse
  /// them one by one.
  static const List<HealthDataType> readTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
  ];

  Future<void> _ready() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> availability() async {
    await _ready();
    return switch (await _health.getHealthConnectSdkStatus()) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthAvailability.needsUpdate,
      _ => HealthAvailability.unavailable,
    };
  }

  @override
  Future<void> openInstall() async {
    await _ready();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> hasAccess() async {
    await _ready();
    return await _health.hasPermissions(readTypes) ?? false;
  }

  @override
  Future<bool> requestAccess() async {
    await _ready();
    return _health.requestAuthorization(readTypes);
  }

  @override
  Future<void> revokeAccess() async {
    await _ready();
    await _health.revokePermissions();
  }

  @override
  Future<HealthSnapshot> read({
    required DateTime from,
    required DateTime to,
  }) async {
    await _ready();
    // One type at a time: a type the user refused answers with an error,
    // and that should cost that type, not the whole import.
    final points = <HealthDataPoint>[];
    for (final type in readTypes) {
      try {
        points.addAll(
          await _health.getHealthDataFromTypes(
            types: [type],
            startTime: from,
            endTime: to,
          ),
        );
      } on Object {
        continue;
      }
    }
    return snapshotFromPoints(points);
  }
}

/// Shortest session that counts as a night. A nap is sleep, but it is not
/// the night the recovery estimate is asking about.
const Duration kShortestImportedNight = Duration(hours: 3);

/// Shortest run or ride worth counting for the legs.
const Duration kShortestCardio = Duration(minutes: 10);

/// Turns the plugin's data points into what FitLog stores.
///
/// Pure, so it can be tested with points made by hand. The rules:
///
/// - **Nights:** each sleep session is a night; the light, REM and deep
///   stages that fall inside it are added up. One night per morning - the
///   longest - and nothing under [kShortestImportedNight].
/// - **HRV and resting heart rate:** every reading, as it came.
/// - **Weight:** every reading, with Health Connect's id.
/// - **Cardio:** runs and rides only, at least [kShortestCardio], and never
///   FitLog's own workouts coming back.
HealthSnapshot snapshotFromPoints(List<HealthDataPoint> points) {
  double numeric(HealthDataPoint point) =>
      (point.value as NumericHealthValue).numericValue.toDouble();

  final sessions = [
    for (final p in points)
      if (p.type == HealthDataType.SLEEP_SESSION) p,
  ];
  final stages = [
    for (final p in points)
      if (p.type == HealthDataType.SLEEP_LIGHT ||
          p.type == HealthDataType.SLEEP_REM ||
          p.type == HealthDataType.SLEEP_DEEP)
        p,
  ];

  final nights = <String, ImportedNight>{};
  for (final session in sessions) {
    final length = session.dateTo.difference(session.dateFrom);
    if (length < kShortestImportedNight) continue;

    int? minutesOf(HealthDataType type) {
      var total = 0;
      var any = false;
      for (final stage in stages) {
        if (stage.type != type) continue;
        final middle = stage.dateFrom.add(
          stage.dateTo.difference(stage.dateFrom) ~/ 2,
        );
        if (middle.isBefore(session.dateFrom) ||
            middle.isAfter(session.dateTo)) {
          continue;
        }
        total += stage.dateTo.difference(stage.dateFrom).inMinutes;
        any = true;
      }
      return any ? total : null;
    }

    final night = ImportedNight(
      fellAsleepAt: session.dateFrom,
      wokeAt: session.dateTo,
      source: session.sourceName,
      lightMinutes: minutesOf(HealthDataType.SLEEP_LIGHT),
      remMinutes: minutesOf(HealthDataType.SLEEP_REM),
      deepMinutes: minutesOf(HealthDataType.SLEEP_DEEP),
    );
    final morning =
        '${night.wokeAt.year}-${night.wokeAt.month}-${night.wokeAt.day}';
    final kept = nights[morning];
    if (kept == null || night.length > kept.length) nights[morning] = night;
  }

  final cardio = <ImportedCardio>[];
  for (final p in points) {
    if (p.type != HealthDataType.WORKOUT) continue;
    if (p.sourceName == HealthConnectSource.ownPackage) continue;
    final value = p.value;
    if (value is! WorkoutHealthValue) continue;
    final kind = switch (value.workoutActivityType) {
      HealthWorkoutActivityType.RUNNING ||
      HealthWorkoutActivityType.RUNNING_TREADMILL => CardioKind.running,
      HealthWorkoutActivityType.BIKING ||
      HealthWorkoutActivityType.BIKING_STATIONARY => CardioKind.cycling,
      _ => null,
    };
    if (kind == null) continue;
    if (p.dateTo.difference(p.dateFrom) < kShortestCardio) continue;
    cardio.add(
      ImportedCardio(
        id: p.uuid,
        start: p.dateFrom,
        end: p.dateTo,
        kind: kind,
        source: p.sourceName,
      ),
    );
  }

  return HealthSnapshot(
    nights: nights.values.toList()
      ..sort((a, b) => a.wokeAt.compareTo(b.wokeAt)),
    hrv: [
      for (final p in points)
        if (p.type == HealthDataType.HEART_RATE_VARIABILITY_RMSSD)
          ImportedReading(at: p.dateFrom, value: numeric(p)),
    ],
    restingHr: [
      for (final p in points)
        if (p.type == HealthDataType.RESTING_HEART_RATE)
          ImportedReading(at: p.dateFrom, value: numeric(p)),
    ],
    weights: [
      for (final p in points)
        if (p.type == HealthDataType.WEIGHT)
          ImportedWeight(
            id: p.uuid,
            at: p.dateFrom,
            kg: numeric(p),
            source: p.sourceName,
          ),
    ],
    cardio: cardio,
  );
}
