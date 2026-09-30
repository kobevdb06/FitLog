import 'package:fitlog/core/db/enums.dart';
import 'package:fitlog/features/health/data/health_connect_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

/// What the plugin hands over, turned into what FitLog keeps.
///
/// Built by hand from the plugin's own types: this is the one piece of the
/// Health Connect work that needs the plugin, and it can still be checked
/// without a phone.
void main() {
  var counter = 0;
  HealthDataPoint point(
    HealthDataType type,
    DateTime from,
    DateTime to, {
    num value = 0,
    HealthValue? healthValue,
    String source = 'com.example.watch',
    HealthDataUnit unit = HealthDataUnit.NO_UNIT,
  }) => HealthDataPoint(
    uuid: 'id-${counter++}',
    value: healthValue ?? NumericHealthValue(numericValue: value),
    type: type,
    unit: unit,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: '',
    sourceId: '',
    sourceName: source,
  );

  final evening = DateTime(2026, 3, 2, 23, 30);
  final morning = DateTime(2026, 3, 3, 7, 15);

  group('nachten', () {
    test('een slaapsessie is een nacht, met de fasen erin opgeteld', () {
      final snapshot = snapshotFromPoints([
        point(HealthDataType.SLEEP_SESSION, evening, morning),
        point(
          HealthDataType.SLEEP_DEEP,
          evening.add(const Duration(minutes: 20)),
          evening.add(const Duration(minutes: 80)),
        ),
        point(
          HealthDataType.SLEEP_DEEP,
          evening.add(const Duration(hours: 3)),
          evening.add(const Duration(hours: 3, minutes: 30)),
        ),
        point(
          HealthDataType.SLEEP_REM,
          evening.add(const Duration(hours: 5)),
          evening.add(const Duration(hours: 6)),
        ),
      ]);

      final night = snapshot.nights.single;
      expect(night.fellAsleepAt, evening);
      expect(night.wokeAt, morning);
      expect(night.deepMinutes, 90);
      expect(night.remMinutes, 60);
      // Geen lichte slaap gemeld: niet ingevuld, geen nul.
      expect(night.lightMinutes, isNull);
      expect(night.source, 'com.example.watch');
    });

    test('een dutje is geen nacht', () {
      final snapshot = snapshotFromPoints([
        point(
          HealthDataType.SLEEP_SESSION,
          DateTime(2026, 3, 3, 14),
          DateTime(2026, 3, 3, 15),
        ),
      ]);

      expect(snapshot.nights, isEmpty);
    });

    test('twee sessies op één ochtend: de langste telt', () {
      final snapshot = snapshotFromPoints([
        point(
          HealthDataType.SLEEP_SESSION,
          DateTime(2026, 3, 3, 3),
          DateTime(2026, 3, 3, 7),
        ),
        point(HealthDataType.SLEEP_SESSION, evening, morning),
      ]);

      expect(snapshot.nights.single.fellAsleepAt, evening);
    });
  });

  group('metingen', () {
    test('HRV, rusthartslag en gewicht komen zoals ze gemeten zijn', () {
      final snapshot = snapshotFromPoints([
        point(
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          morning,
          morning,
          value: 48.5,
        ),
        point(HealthDataType.RESTING_HEART_RATE, morning, morning, value: 52),
        point(HealthDataType.WEIGHT, morning, morning, value: 81.4),
      ]);

      expect(snapshot.hrv.single.value, 48.5);
      expect(snapshot.restingHr.single.value, 52);
      expect(snapshot.weights.single.kg, 81.4);
      expect(snapshot.weights.single.at, morning);
    });
  });

  group('cardio', () {
    HealthDataPoint workout(
      HealthWorkoutActivityType type, {
      Duration length = const Duration(minutes: 40),
      String source = 'com.strava',
    }) => point(
      HealthDataType.WORKOUT,
      morning,
      morning.add(length),
      healthValue: WorkoutHealthValue(workoutActivityType: type),
      source: source,
    );

    test('lopen en fietsen tellen', () {
      final snapshot = snapshotFromPoints([
        workout(HealthWorkoutActivityType.RUNNING),
        workout(HealthWorkoutActivityType.BIKING_STATIONARY),
      ]);

      expect(snapshot.cardio.map((c) => c.kind), [
        CardioKind.running,
        CardioKind.cycling,
      ]);
    });

    test('wandelen, zwemmen en krachttraining niet', () {
      final snapshot = snapshotFromPoints([
        workout(HealthWorkoutActivityType.WALKING),
        workout(HealthWorkoutActivityType.SWIMMING_POOL),
        workout(HealthWorkoutActivityType.STRENGTH_TRAINING),
      ]);

      expect(snapshot.cardio, isEmpty);
    });

    test('een ommetje van vijf minuten ook niet', () {
      final snapshot = snapshotFromPoints([
        workout(
          HealthWorkoutActivityType.RUNNING,
          length: const Duration(minutes: 5),
        ),
      ]);

      expect(snapshot.cardio, isEmpty);
    });

    test('en FitLogs eigen trainingen komen nooit terug', () {
      // Eenmaal naar Health Connect geschreven, zou een training anders als
      // andermans sessie teruggelezen worden.
      final snapshot = snapshotFromPoints([
        workout(
          HealthWorkoutActivityType.RUNNING,
          source: HealthConnectSource.ownPackage,
        ),
      ]);

      expect(snapshot.cardio, isEmpty);
    });
  });
}
