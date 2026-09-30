import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/health/data/health_importer.dart';
import 'package:fitlog/features/health/data/health_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Writing what came in into FitLog's own database, by the two rules: what
/// you entered yourself wins, and importing twice changes nothing.
void main() {
  late AppDatabase db;
  late HealthImporter importer;

  setUp(() {
    db = createTestDatabase();
    importer = HealthImporter(db);
  });
  tearDown(() => db.close());

  final evening = DateTime(2026, 3, 2, 23, 30);
  final morning = DateTime(2026, 3, 3, 7);

  ImportedNight night({int? deep}) => ImportedNight(
    fellAsleepAt: evening,
    wokeAt: morning,
    source: 'com.example.watch',
    deepMinutes: deep,
  );

  group('nachten', () {
    test('komen binnen, met waar ze vandaan komen', () async {
      final summary = await importer.apply(
        HealthSnapshot(nights: [night(deep: 80)]),
      );

      final row = (await db.select(db.sleepEntriesTable).get()).single;
      expect(summary.nights, 1);
      expect(row.deepMinutes, 80);
      expect(row.source, 'com.example.watch');
    });

    test('opnieuw ophalen maakt er geen twee van', () async {
      await importer.apply(HealthSnapshot(nights: [night(deep: 80)]));
      await importer.apply(HealthSnapshot(nights: [night(deep: 85)]));

      final rows = await db.select(db.sleepEntriesTable).get();
      expect(rows, hasLength(1));
      // Wel bijgewerkt: een horloge verbetert zijn nacht soms achteraf.
      expect(rows.single.deepMinutes, 85);
    });

    test('maar een nacht die je zelf invulde, blijft zoals hij is', () async {
      await db.recoveryDao.setSleep(
        fellAsleepAt: DateTime(2026, 3, 3, 0, 30),
        wokeAt: DateTime(2026, 3, 3, 6, 30),
      );

      final summary = await importer.apply(HealthSnapshot(nights: [night()]));

      final row = (await db.select(db.sleepEntriesTable).get()).single;
      expect(row.source, isNull);
      expect(row.wokeAt, DateTime(2026, 3, 3, 6, 30).millisecondsSinceEpoch);
      expect(summary.nights, 0);
      expect(summary.ownNightsKept, 1);
    });

    test('en een geïmporteerde nacht die je aanpast, wordt de jouwe', () async {
      await importer.apply(HealthSnapshot(nights: [night()]));
      await db.recoveryDao.setSleep(
        fellAsleepAt: evening.add(const Duration(minutes: 30)),
        wokeAt: morning,
      );
      await importer.apply(HealthSnapshot(nights: [night()]));

      final row = (await db.select(db.sleepEntriesTable).get()).single;
      expect(row.source, isNull);
      expect(
        row.fellAsleepAt,
        evening.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );
    });
  });

  group('gewicht', () {
    ImportedWeight weight(String id, DateTime at, double kg) =>
        ImportedWeight(id: id, at: at, kg: kg, source: 'com.withings');

    test('komt binnen en niet dubbel', () async {
      await importer.apply(
        HealthSnapshot(weights: [weight('w1', morning, 81.4)]),
      );
      await importer.apply(
        HealthSnapshot(weights: [weight('w1', morning, 81.4)]),
      );

      final rows = await db.select(db.bodyMeasurementsTable).get();
      expect(rows.single.value, 81.4);
      expect(rows.single.type, MeasurementType.weight.wire);
      expect(rows.single.source, 'com.withings');
    });

    test('maar niet op een dag dat je je zelf woog in FitLog', () async {
      await db.recordsDao.addMeasurement(
        type: MeasurementType.weight,
        value: 81.0,
        measuredAt: DateTime(2026, 3, 3, 20),
      );

      final summary = await importer.apply(
        HealthSnapshot(weights: [weight('w1', morning, 81.4)]),
      );

      final rows = await db.select(db.bodyMeasurementsTable).get();
      expect(rows.single.value, 81.0);
      expect(summary.ownWeightsKept, 1);
    });
  });

  group('HRV en rusthartslag', () {
    test('per dag: HRV gemiddeld, rusthartslag de laagste', () async {
      final summary = await importer.apply(
        HealthSnapshot(
          hrv: [
            ImportedReading(at: DateTime(2026, 3, 3, 2), value: 40),
            ImportedReading(at: DateTime(2026, 3, 3, 4), value: 50),
          ],
          restingHr: [
            ImportedReading(at: DateTime(2026, 3, 3, 8), value: 55),
            ImportedReading(at: DateTime(2026, 3, 3, 18), value: 52),
          ],
        ),
      );

      final row = (await db.select(db.dailyVitalsTable).get()).single;
      expect(row.hrvMs, 45);
      expect(row.restingHr, 52);
      expect(summary.vitalDays, 1);
    });

    test('een dag met alleen de ene waarde laat de andere staan', () async {
      await importer.apply(
        HealthSnapshot(
          hrv: [ImportedReading(at: DateTime(2026, 3, 3, 2), value: 40)],
          restingHr: [ImportedReading(at: DateTime(2026, 3, 3, 8), value: 55)],
        ),
      );
      await importer.apply(
        HealthSnapshot(
          hrv: [ImportedReading(at: DateTime(2026, 3, 3, 3), value: 44)],
        ),
      );

      final row = (await db.select(db.dailyVitalsTable).get()).single;
      expect(row.hrvMs, 44);
      expect(row.restingHr, 55);
    });
  });

  test('cardio komt binnen en niet dubbel', () async {
    final run = ImportedCardio(
      id: 'r1',
      start: morning,
      end: morning.add(const Duration(minutes: 45)),
      kind: CardioKind.running,
      source: 'com.strava',
    );

    await importer.apply(HealthSnapshot(cardio: [run]));
    await importer.apply(HealthSnapshot(cardio: [run]));

    final rows = await db.select(db.cardioSessionsTable).get();
    expect(rows.single.kind, 'running');
    expect(rows.single.id, 'hc:r1');
  });

  test('vergeten wist alles wat binnenkwam, en niets van jezelf', () async {
    await db.recoveryDao.setSleep(
      fellAsleepAt: DateTime(2026, 3, 4, 0),
      wokeAt: DateTime(2026, 3, 4, 7),
    );
    await importer.apply(
      HealthSnapshot(
        nights: [night()],
        hrv: [ImportedReading(at: morning, value: 40)],
      ),
    );

    await db.healthDao.forgetImported();

    final nights = await db.select(db.sleepEntriesTable).get();
    expect(nights.single.source, isNull);
    expect(await db.select(db.dailyVitalsTable).get(), isEmpty);
  });
}
