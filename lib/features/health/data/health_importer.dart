import '../../../core/db/database.dart';
import '../../../core/db/dao/recovery_dao.dart';
import 'health_source.dart';

/// What one import did, for the line under the button.
class ImportSummary {
  const ImportSummary({
    this.nights = 0,
    this.ownNightsKept = 0,
    this.weights = 0,
    this.ownWeightsKept = 0,
    this.vitalDays = 0,
    this.cardio = 0,
    this.heartRates = 0,
  });

  final int nights;

  /// Mornings you had filled in yourself, left as they were.
  final int ownNightsKept;
  final int weights;
  final int ownWeightsKept;
  final int vitalDays;
  final int cardio;

  /// Sessions that got the heart rate a watch measured during them.
  final int heartRates;

  bool get isEmpty =>
      nights == 0 &&
      weights == 0 &&
      vitalDays == 0 &&
      cardio == 0 &&
      heartRates == 0;

  ImportSummary withHeartRates(int count) => ImportSummary(
    nights: nights,
    ownNightsKept: ownNightsKept,
    weights: weights,
    ownWeightsKept: ownWeightsKept,
    vitalDays: vitalDays,
    cardio: cardio,
    heartRates: count,
  );
}

/// Writes a [HealthSnapshot] into FitLog's own database.
///
/// Into the database, and not read afresh from Health Connect every time the
/// recovery estimate is worked out: the estimate, the charts and the backup
/// all read FitLog's own tables, so they keep working - and keep what came
/// in - after Health Connect is disconnected or its data expires there.
class HealthImporter {
  HealthImporter(this.db);

  final AppDatabase db;

  Future<ImportSummary> apply(HealthSnapshot snapshot) =>
      db.transaction(() async {
        final dao = db.healthDao;

        var nights = 0;
        var ownNights = 0;
        for (final night in snapshot.nights) {
          final written = await dao.importNight(
            fellAsleepAt: night.fellAsleepAt,
            wokeAt: night.wokeAt,
            source: night.source,
            lightMinutes: night.lightMinutes,
            remMinutes: night.remMinutes,
            deepMinutes: night.deepMinutes,
          );
          written ? nights++ : ownNights++;
        }

        var weights = 0;
        var ownWeights = 0;
        for (final weight in snapshot.weights) {
          final written = await dao.importWeight(
            recordId: weight.id,
            at: weight.at,
            kg: weight.kg,
            source: weight.source,
          );
          written ? weights++ : ownWeights++;
        }

        // A watch reports HRV many times a night and a resting heart rate
        // once or twice a day. Both are meant to be read per day: the
        // average HRV, and the lowest resting heart rate.
        final hrv = <String, List<double>>{};
        final resting = <String, List<double>>{};
        final days = <String, DateTime>{};
        for (final reading in snapshot.hrv) {
          final key = RecoveryDao.dayKey(reading.at);
          days[key] = reading.at;
          (hrv[key] ??= []).add(reading.value);
        }
        for (final reading in snapshot.restingHr) {
          final key = RecoveryDao.dayKey(reading.at);
          days[key] = reading.at;
          (resting[key] ??= []).add(reading.value);
        }
        for (final MapEntry(:key, value: day) in days.entries) {
          final hrvs = hrv[key];
          final rests = resting[key];
          await dao.importVitals(
            day: day,
            hrvMs: hrvs == null
                ? null
                : hrvs.reduce((a, b) => a + b) / hrvs.length,
            restingHr: rests?.reduce((a, b) => a < b ? a : b),
          );
        }

        for (final session in snapshot.cardio) {
          await dao.importCardio(
            recordId: session.id,
            start: session.start,
            end: session.end,
            kind: session.kind.wire,
            source: session.source,
          );
        }

        return ImportSummary(
          nights: nights,
          ownNightsKept: ownNights,
          weights: weights,
          ownWeightsKept: ownWeights,
          vitalDays: days.length,
          cardio: snapshot.cardio.length,
        );
      });
}
