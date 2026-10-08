import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/main_lifts.dart';
import '../../../core/calc/muscle_sets.dart';
import '../../../core/calc/plateau.dart';
import '../../../core/calc/progress_period.dart';
import '../../../core/calc/streak.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../history/presentation/history_providers.dart';
import '../data/plateau_loader.dart';

part 'progress_providers.g.dart';

/// One bar of a training chart: a week, or a month.
class TrainingBucket {
  const TrainingBucket({
    required this.start,
    required this.volumeKg,
    required this.workouts,
    required this.sets,
  });

  final DateTime start;
  final double volumeKg;
  final int workouts;
  final int sets;
}

/// The workouts summed per bar, one bar for each of [starts], oldest first.
List<TrainingBucket> _sumPerBucket(
  List<DateTime> starts,
  Iterable<WorkoutRow> workouts,
  DateTime Function(DateTime) bucketOf,
) {
  final sums = {
    for (final start in starts) start: (volume: 0.0, count: 0, sets: 0),
  };
  for (final w in workouts) {
    final key = bucketOf(DateTime.fromMillisecondsSinceEpoch(w.startedAt));
    final current = sums[key];
    if (current == null) continue;
    sums[key] = (
      volume: current.volume + w.totalVolumeKg,
      count: current.count + 1,
      sets: current.sets + w.totalSets,
    );
  }
  return [
    for (final start in starts)
      TrainingBucket(
        start: start,
        volumeKg: sums[start]!.volume,
        workouts: sums[start]!.count,
        sets: sums[start]!.sets,
      ),
  ];
}

/// Volume, workouts and sets per calendar week, oldest bucket first.
@riverpod
Stream<List<TrainingBucket>> weeklyBuckets(Ref ref, {int weeks = 8}) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final thisWeek = startOfWeek(now);
  final starts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i),
  ];

  return db.workoutsDao
      .watchWorkoutsBetween(starts.first, now.add(const Duration(days: 1)))
      .map((workouts) => _sumPerBucket(starts, workouts, startOfWeek));
}

/// What Voortgang looks back over.
///
/// A way of looking rather than a setting: it holds while the app is open,
/// across tabs, and starts at three months - long enough for a line to mean
/// something, short enough that last winter does not flatten it.
@Riverpod(keepAlive: true)
class ProgressPeriodChoice extends _$ProgressPeriodChoice {
  @override
  ProgressPeriod build() => ProgressPeriod.threeMonths;

  void choose(ProgressPeriod period) => state = period;
}

/// Volume, workouts and sets per bar of [period], oldest first.
@riverpod
Stream<List<TrainingBucket>> trainingBuckets(Ref ref, ProgressPeriod period) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final starts = period.bucketStarts(now);

  return db.workoutsDao
      .watchWorkoutsBetween(starts.first, now.add(const Duration(days: 1)))
      .map((workouts) => _sumPerBucket(starts, workouts, period.bucketOf));
}

/// An exercise Voortgang follows, with the row it belongs to.
class MainLift {
  const MainLift({required this.exercise, required this.trend});

  final ExerciseRow exercise;
  final LiftTrend trend;
}

/// The exercises you did most in [period], at most [kMainLifts].
///
/// A stream: the session you just finished is the newest point of the line.
@riverpod
Stream<List<MainLift>> mainLifts(Ref ref, ProgressPeriod period) {
  final db = ref.watch(databaseProvider);
  return db.workoutsDao
      .watchProgressSets(since: period.start(DateTime.now()))
      .asyncMap((sets) async {
        final trends = liftTrends(sets);
        if (trends.isEmpty) return const <MainLift>[];
        final exercises = {
          for (final row in await db.exercisesDao.getByIds([
            for (final trend in trends) trend.exerciseId,
          ]))
            row.id: row,
        };
        // An archived exercise is one you put away; the next one moves up.
        return [
          for (final trend in trends)
            if (exercises[trend.exerciseId] case final exercise?
                when !exercise.isArchived)
              MainLift(exercise: exercise, trend: trend),
        ].take(kMainLifts).toList();
      });
}

/// The working sets per muscle per week of [period], against the stretch
/// as long before it.
@riverpod
Stream<List<MuscleSets>> muscleSets(Ref ref, ProgressPeriod period) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final start = period.start(now);
  return db.workoutsDao
      .watchProgressSets(since: start.subtract(now.difference(start)))
      .map(
        (sets) => muscleSetsPerWeek(sets, period: period, now: DateTime.now()),
      );
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
        (rows) => rows.reversed
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
