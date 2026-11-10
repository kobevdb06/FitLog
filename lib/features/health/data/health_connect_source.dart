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
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
  ];

  /// What [read] asks for in one go: everything but the heart rate. A watch
  /// can store a sample a second during a workout, and a month of those is
  /// not something to fetch when only the sessions matter.
  static final List<HealthDataType> _bulkTypes = [
    for (final type in readTypes)
      if (!const {
        HealthDataType.HEART_RATE,
        // Read per night and per day, like the heart rate.
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.STEPS,
      }.contains(type))
        type,
  ];

  /// How each permission is called on FitLog's own screen.
  static const Map<HealthDataType, String> _labels = {
    HealthDataType.SLEEP_SESSION: 'slaap',
    // Each its own permission; one name, as a night shows them together.
    HealthDataType.SLEEP_LIGHT: 'slaapfasen',
    HealthDataType.SLEEP_DEEP: 'slaapfasen',
    HealthDataType.SLEEP_REM: 'slaapfasen',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'HRV',
    HealthDataType.RESTING_HEART_RATE: 'rusthartslag',
    HealthDataType.WEIGHT: 'gewicht',
    HealthDataType.WORKOUT: 'loop- en fietssessies',
    HealthDataType.HEART_RATE: 'hartslag',
    HealthDataType.BLOOD_OXYGEN: 'zuurstofsaturatie',
    HealthDataType.STEPS: 'stappen',
  };

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

  /// The plugin says yes only when every type was granted, and the user
  /// chooses type by type: part of it granted counted as nothing, and the
  /// link was never made (DECISIONS 252). Now any type granted is access,
  /// and what is missing is said where it shows.
  @override
  Future<bool> requestAccess() async {
    await _ready();
    if (await _health.requestAuthorization(readTypes)) return true;
    for (final type in readTypes) {
      if (await _granted(type)) return true;
    }
    return false;
  }

  Future<bool> _granted(HealthDataType type) async {
    try {
      return await _health.hasPermissions([type]) ?? false;
    } on Object {
      return false;
    }
  }

  /// The name of [type] when a read of it failed though it is granted: then
  /// it is unread, not refused. A type that was refused found nothing, and
  /// says so on its own line of missing access.
  Future<String?> _unread(HealthDataType type) async =>
      await _granted(type) ? (_labels[type] ?? type.name) : null;

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
    final unread = <String>[];
    for (final type in _bulkTypes) {
      try {
        points.addAll(
          await _health.getHealthDataFromTypes(
            types: [type],
            startTime: from,
            endTime: to,
          ),
        );
      } on Object {
        if (await _unread(type) case final label?) {
          if (!unread.contains(label)) unread.add(label);
        }
      }
    }
    return snapshotFromPoints(points).withUnread(unread);
  }

  @override
  Future<List<ImportedReading>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async {
    await _ready();
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE],
        startTime: from,
        endTime: to,
      );
      return [
        for (final point in points)
          if (point.value case final NumericHealthValue value)
            ImportedReading(
              at: point.dateFrom,
              value: value.numericValue.toDouble(),
            ),
      ];
    } on Object {
      // Not granted: no heart rate, and nothing else lost. Granted and
      // still failing: asked again (DECISIONS 252).
      if (await _unread(HealthDataType.HEART_RATE) case final label?) {
        throw HealthUnreadable(label);
      }
      return const [];
    }
  }

  @override
  Future<List<ImportedReading>> oxygenSaturation({
    required DateTime from,
    required DateTime to,
  }) async {
    await _ready();
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.BLOOD_OXYGEN],
        startTime: from,
        endTime: to,
      );
      return [
        for (final point in points)
          if (point.value case final NumericHealthValue value)
            ImportedReading(
              at: point.dateFrom,
              value: value.numericValue.toDouble(),
            ),
      ];
    } on Object {
      if (await _unread(HealthDataType.BLOOD_OXYGEN) case final label?) {
        throw HealthUnreadable(label);
      }
      return const [];
    }
  }

  @override
  Future<int?> steps({required DateTime from, required DateTime to}) async {
    await _ready();
    try {
      // Health Connect's own total, which counts a walk two apps recorded
      // once - adding up the records would count it twice.
      final total = await _health.getTotalStepsInInterval(from, to);
      return total == null || total <= 0 ? null : total;
    } on Object {
      if (await _unread(HealthDataType.STEPS) case final label?) {
        throw HealthUnreadable(label);
      }
      return null;
    }
  }

  @override
  Future<List<String>> missingAccess() async {
    await _ready();
    final missing = <String>[];
    for (final MapEntry(key: type, value: label) in _labels.entries) {
      if (missing.contains(label)) continue;
      if (!await _granted(type)) missing.add(label);
    }
    return missing;
  }

  @override
  Future<bool> requestWriteAccess() async {
    await _ready();
    return _health.requestAuthorization(
      const [HealthDataType.WORKOUT],
      permissions: const [HealthDataAccess.WRITE],
    );
  }

  @override
  Future<String?> writeWorkout({
    required DateTime start,
    required DateTime end,
    required String title,
  }) async {
    await _ready();
    final id = await _health.writeWorkoutDataUUID(
      activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
      start: start,
      end: end,
      title: title,
      // Typed in set by set, not measured by a sensor.
      recordingMethod: RecordingMethod.manual,
    );
    // The plugin answers with an empty string, or "null", when nothing was
    // inserted.
    return id == null || id.isEmpty || id == 'null' ? null : id;
  }

  @override
  Future<String?> findOwnWorkout({
    required DateTime start,
    required DateTime end,
  }) async {
    await _ready();
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: start.subtract(const Duration(minutes: 1)),
        endTime: end.add(const Duration(minutes: 1)),
      );
      for (final point in points) {
        if (point.sourceName != ownPackage) continue;
        if (point.dateFrom.difference(start).inSeconds.abs() > 1) continue;
        if (point.dateTo.difference(end).inSeconds.abs() > 1) continue;
        if (point.uuid.isNotEmpty) return point.uuid;
      }
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> requestBackgroundAccess() async {
    await _ready();
    // Where the feature is missing, Health Connect has no such permission to
    // give - and nothing to hold back with it either.
    if (!await _health.isHealthDataInBackgroundAvailable()) return true;
    if (await _health.isHealthDataInBackgroundAuthorized()) return true;
    return _health.requestHealthDataInBackgroundAuthorization();
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await _ready();
    await _health.deleteByUUID(uuid: id, type: HealthDataType.WORKOUT);
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
/// How far apart two sleep sessions of one source may be and still be one
/// night: long enough to have been awake for a while, too short for a nap.
const Duration kNightPieceGap = Duration(minutes: 90);

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

  // The pieces of one night: a watch that saw you awake at two wrote two
  // sessions, and only the longer one was kept, without the stages of the
  // other (DECISIONS 255). Pieces of one source this close are one night.
  final pieces = [...sessions]
    ..sort((a, b) {
      final bySource = a.sourceName.compareTo(b.sourceName);
      return bySource != 0 ? bySource : a.dateFrom.compareTo(b.dateFrom);
    });
  final windows = <({DateTime from, DateTime to, String source})>[];
  for (final piece in pieces) {
    final last = windows.lastOrNull;
    if (last != null &&
        last.source == piece.sourceName &&
        !piece.dateFrom.isAfter(last.to.add(kNightPieceGap))) {
      windows[windows.length - 1] = (
        from: last.from,
        to: piece.dateTo.isAfter(last.to) ? piece.dateTo : last.to,
        source: last.source,
      );
    } else {
      windows.add((
        from: piece.dateFrom,
        to: piece.dateTo,
        source: piece.sourceName,
      ));
    }
  }

  final nights = <String, ImportedNight>{};
  for (final session in windows) {
    final length = session.to.difference(session.from);
    if (length < kShortestImportedNight) continue;

    int? minutesOf(HealthDataType type) {
      var total = 0;
      var any = false;
      for (final stage in stages) {
        if (stage.type != type) continue;
        // The stages of the source that wrote the night: a phone and a
        // watch that both write them counted the same sleep twice.
        if (stage.sourceName != session.source) continue;
        final middle = stage.dateFrom.add(
          stage.dateTo.difference(stage.dateFrom) ~/ 2,
        );
        if (middle.isBefore(session.from) || middle.isAfter(session.to)) {
          continue;
        }
        total += stage.dateTo.difference(stage.dateFrom).inMinutes;
        any = true;
      }
      return any ? total : null;
    }

    final night = ImportedNight(
      fellAsleepAt: session.from,
      wokeAt: session.to,
      source: session.source,
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
