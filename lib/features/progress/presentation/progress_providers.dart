import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plateau.dart';
import '../../../core/calc/streak.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../history/presentation/history_providers.dart';
import '../data/plateau_loader.dart';

part 'progress_providers.g.dart';

/// One bucket of the weekly volume chart.
class WeekBucket {
  const WeekBucket({
    required this.weekStart,
    required this.volumeKg,
    required this.workouts,
    required this.sets,
  });

  final DateTime weekStart;
  final double volumeKg;
  final int workouts;
  final int sets;
}

/// Volume, workouts and sets per calendar week, oldest bucket first.
@riverpod
Stream<List<WeekBucket>> weeklyBuckets(Ref ref, {int weeks = 8}) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final firstWeek = startOfWeek(
    now.subtract(Duration(days: 7 * (weeks - 1))),
  );

  return db.workoutsDao
      .watchWorkoutsBetween(firstWeek, now.add(const Duration(days: 1)))
      .map((workouts) {
        final buckets = <DateTime, ({double volume, int count, int sets})>{};
        for (var i = 0; i < weeks; i++) {
          buckets[startOfWeek(firstWeek.add(Duration(days: 7 * i)))] = (
            volume: 0,
            count: 0,
            sets: 0,
          );
        }
        for (final w in workouts) {
          final week = startOfWeek(
            DateTime.fromMillisecondsSinceEpoch(w.startedAt),
          );
          final current = buckets[week];
          if (current == null) continue;
          buckets[week] = (
            volume: current.volume + w.totalVolumeKg,
            count: current.count + 1,
            sets: current.sets + w.totalSets,
          );
        }

        final keys = buckets.keys.toList()..sort();
        return [
          for (final key in keys)
            WeekBucket(
              weekStart: key,
              volumeKg: buckets[key]!.volume,
              workouts: buckets[key]!.count,
              sets: buckets[key]!.sets,
            ),
        ];
      });
}

/// The current training streak.
@riverpod
Future<StreakResult> streak(Ref ref) async {
  final dates = await ref.watch(finishedWorkoutDatesProvider.future);
  return computeStreak(dates);
}

/// This calendar week in numbers.
@riverpod
Stream<WeekStats> thisWeekStats(Ref ref) {
  final from = startOfWeek(DateTime.now());
  return ref
      .watch(databaseProvider)
      .workoutsDao
      .watchStatsBetween(from, from.add(const Duration(days: 7)));
}

@riverpod
Future<LifetimeStats> lifetimeStats(Ref ref) =>
    ref.watch(databaseProvider).workoutsDao.lifetimeStats();

/// Body weight over time, oldest first.
@riverpod
Stream<List<ChartPoint>> bodyWeightSeries(Ref ref) {
  return ref
      .watch(databaseProvider)
      .recordsDao
      .watchMeasurements(type: MeasurementType.weight)
      .map(
        (rows) =>
            rows.reversed
                .map(
                  (r) => ChartPoint(
                    DateTime.fromMillisecondsSinceEpoch(r.measuredAt),
                    r.value,
                  ),
                )
                .toList(),
      );
}

@riverpod
Stream<List<RecordWithExercise>> allRecords(Ref ref, {PrType? type}) =>
    ref.watch(databaseProvider).recordsDao.watchRecords(type: type);

@riverpod
Stream<List<RecordWithExercise>> latestRecords(Ref ref, {int limit = 3}) =>
    ref.watch(databaseProvider).recordsDao.watchRecords(limit: limit);

/// The exercises that have stalled, the longest first.
///
/// A stream: finishing a workout can end a plateau as easily as start one.
@riverpod
Stream<List<ExercisePlateau>> plateaus(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.workoutsDao
      .watchProgressSets(since: DateTime.now().subtract(kPlateauLookback))
      .asyncMap((sets) => findPlateaus(db, sets, now: DateTime.now()));
}

/// The plateau of [exerciseId], or null while it is still going forward.
@riverpod
ExercisePlateau? exercisePlateau(Ref ref, String exerciseId) {
  for (final found in ref.watch(plateausProvider).value ?? const []) {
    if (found.exercise.id == exerciseId) return found;
  }
  return null;
}
