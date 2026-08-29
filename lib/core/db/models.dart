import 'package:collection/collection.dart';

import 'database.dart';

// Read-model types that join a few tables together. They are plain immutable
// value objects so that the presentation layer never has to run its own
// queries.

class RoutineSummary {
  const RoutineSummary({
    required this.routine,
    required this.exerciseCount,
    required this.setCount,
  });

  final RoutineRow routine;
  final int exerciseCount;
  final int setCount;
}

class RoutineExerciseDetail {
  const RoutineExerciseDetail({
    required this.routineExercise,
    required this.exercise,
    required this.sets,
  });

  final RoutineExerciseRow routineExercise;
  final ExerciseRow exercise;
  final List<RoutineSetRow> sets;

  ExerciseCategory get category => ExerciseCategory.fromWire(exercise.category);
}

class RoutineDetail {
  const RoutineDetail({required this.routine, required this.exercises});

  final RoutineRow routine;
  final List<RoutineExerciseDetail> exercises;

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);
}

class WorkoutExerciseDetail {
  const WorkoutExerciseDetail({
    required this.workoutExercise,
    required this.exercise,
    required this.sets,
  });

  final WorkoutExerciseRow workoutExercise;
  final ExerciseRow exercise;
  final List<WorkoutSetRow> sets;

  ExerciseCategory get category => ExerciseCategory.fromWire(exercise.category);

  int get completedSets => sets.where((s) => s.isCompleted).length;

  WorkoutExerciseDetail copyWith({List<WorkoutSetRow>? sets}) {
    return WorkoutExerciseDetail(
      workoutExercise: workoutExercise,
      exercise: exercise,
      sets: sets ?? this.sets,
    );
  }
}

class WorkoutDetail {
  const WorkoutDetail({required this.workout, required this.exercises});

  final WorkoutRow workout;
  final List<WorkoutExerciseDetail> exercises;

  bool get isActive => workout.endedAt == null;

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets.length);

  int get completedSets => exercises.fold(0, (s, e) => s + e.completedSets);

  int get pendingSets => totalSets - completedSets;

  /// All exercises that belong to the same superset group as [group],
  /// in display order.
  List<WorkoutExerciseDetail> supersetMembers(int group) => exercises
      .where((e) => e.workoutExercise.supersetGroup == group)
      .toList(growable: false);

  WorkoutExerciseDetail? exerciseById(String id) =>
      exercises.firstWhereOrNull((e) => e.workoutExercise.id == id);
}

/// One historical performance of a single exercise.
class ExerciseSession {
  const ExerciseSession({
    required this.workout,
    required this.workoutExercise,
    required this.sets,
  });

  final WorkoutRow workout;
  final WorkoutExerciseRow workoutExercise;
  final List<WorkoutSetRow> sets;

  DateTime get date =>
      DateTime.fromMillisecondsSinceEpoch(workout.startedAt);
}

/// A single entry in the history list.
class WorkoutSummary {
  const WorkoutSummary({
    required this.workout,
    required this.exerciseCount,
    required this.prCount,
  });

  final WorkoutRow workout;
  final int exerciseCount;
  final int prCount;
}

/// One point on a progress chart.
class ChartPoint {
  const ChartPoint(this.at, this.value);

  final DateTime at;
  final double value;
}

/// A personal record joined with the exercise it belongs to.
class RecordWithExercise {
  const RecordWithExercise({required this.record, required this.exercise});

  final PersonalRecordRow record;
  final ExerciseRow exercise;

  PrType get type => PrType.fromWire(record.recordType);
}

/// The aggregated numbers shown on the dashboard.
class WeekStats {
  const WeekStats({
    required this.workouts,
    required this.sets,
    required this.volumeKg,
    required this.durationSeconds,
  });

  const WeekStats.empty()
    : workouts = 0,
      sets = 0,
      volumeKg = 0,
      durationSeconds = 0;

  final int workouts;
  final int sets;
  final double volumeKg;
  final int durationSeconds;
}

/// Lifetime totals shown on the profile screen.
class LifetimeStats {
  const LifetimeStats({
    required this.workouts,
    required this.sets,
    required this.volumeKg,
    required this.durationSeconds,
    required this.busiestWeekday,
  });

  const LifetimeStats.empty()
    : workouts = 0,
      sets = 0,
      volumeKg = 0,
      durationSeconds = 0,
      busiestWeekday = null;

  final int workouts;
  final int sets;
  final double volumeKg;
  final int durationSeconds;

  /// 1 = Monday .. 7 = Sunday, or null when there is no data yet.
  final int? busiestWeekday;
}
