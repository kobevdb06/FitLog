import '../../../core/calc/plateau.dart';
import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';
import 'recovery_loader.dart';

/// A stalled exercise, and what went on while it stood still.
class ExercisePlateau {
  const ExercisePlateau({
    required this.exercise,
    required this.plateau,
    required this.context,
  });

  final ExerciseRow exercise;
  final Plateau plateau;
  final PlateauContext context;
}

/// Every exercise in [sets] that has stalled as of [now], the longest first.
///
/// [sets] is every working set since [kPlateauLookback]. Everything else -
/// the nights, and the recovery estimate session by session - is read once
/// here, and only when something has stalled.
Future<List<ExercisePlateau>> findPlateaus(
  AppDatabase db,
  List<ProgressSet> sets, {
  required DateTime now,
}) async {
  // Only what had happened by [now]: asked about a moment in the past - the
  // start of a week, for the weekly review - a later session must not count.
  final byExercise = <String, List<ProgressSet>>{};
  for (final set in sets) {
    if (set.startedAt.isAfter(now)) continue;
    byExercise.putIfAbsent(set.exerciseId, () => []).add(set);
  }

  final found = <String, Plateau>{};
  for (final entry in byExercise.entries) {
    final measure = ProgressMeasure.of(entry.value.last.category);
    if (measure == null) continue;
    final plateau = detectPlateau(
      progressPoints(entry.value, measure),
      measure: measure,
      now: now,
    );
    if (plateau != null) found[entry.key] = plateau;
  }
  if (found.isEmpty) return const [];

  final exercises = {
    for (final row in await db.exercisesDao.getByIds(found.keys))
      if (!row.isArchived) row.id: row,
  };
  if (exercises.isEmpty) return const [];

  // The same estimate the Herstel screen makes, kept session by session, so
  // "nog niet hersteld" here means what it meant there at the time.
  final since = now.subtract(kPlateauLookback);
  final weight = await db.recordsDao.weightNearest(now);
  final nights = [
    for (final row in await db.recoveryDao.sleepSince(since)) sleepNightOf(row),
  ];
  final history = recoveryHistory(
    muscleSessions(
      await db.workoutsDao.recoverySets(since: since),
      bodyWeightKg: weight?.value,
    ),
    checks: [
      for (final row in await db.recoveryDao.sorenessSince(since))
        ?sorenessCheckOf(row),
    ],
    nights: nights,
    drinks: [
      for (final row in await db.recoveryDao.drinksSince(since))
        drinkDayOf(row),
    ],
    vitals: [
      for (final row in await db.healthDao.vitalsSince(
        since.subtract(kVitalsBaselineWindow),
      ))
        vitalsDayOf(row),
    ],
    bodyWeightKg: weight?.value,
  );

  return [
    for (final MapEntry(key: id, value: plateau) in found.entries)
      if (exercises[id] case final exercise?)
        ExercisePlateau(
          exercise: exercise,
          plateau: plateau,
          context: plateauContext(
            plateau: plateau,
            exerciseId: id,
            primaryMuscle: exercise.primaryMuscle,
            sets: sets,
            now: now,
            nights: nights,
            history: history[exercise.primaryMuscle] ?? const [],
          ),
        ),
  ]..sort((a, b) => a.plateau.since.compareTo(b.plateau.since));
}

/// The stalled exercises as of [now], read once: for the coach, which asks
/// in the middle of a conversation and has no use for a stream.
Future<List<ExercisePlateau>> loadPlateaus(
  AppDatabase db, {
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  return findPlateaus(
    db,
    await db.workoutsDao.progressSets(since: at.subtract(kPlateauLookback)),
    now: at,
  );
}
