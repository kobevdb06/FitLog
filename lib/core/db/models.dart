import 'package:collection/collection.dart';

import 'database.dart';

// Read-model types that join a few tables together. They are plain immutable
// value objects so that the presentation layer never has to run its own
// queries.

/// What an exercise is called, and how it is measured.
///
/// The eight built-in categories are not a list of names but a list of
/// behaviours: each decides which columns a set has, which records make sense,
/// and whether the plate calculator has anything to say. A category the user
/// adds cannot invent a behaviour, so it borrows one - a choice is always a
/// built-in category, and sometimes a name of your own on top of it.
class CategoryChoice {
  const CategoryChoice(this.base, [this.name]);

  /// What an exercise row says it is.
  factory CategoryChoice.of(String categoryWire, String? customName) =>
      CategoryChoice(ExerciseCategory.fromWire(categoryWire), customName);

  /// How it is logged. Always one of the built-in eight.
  final ExerciseCategory base;

  /// The user's name for it, or null when it simply is [base].
  final String? name;

  String get label => name ?? base.label;

  bool get isOwn => name != null;

  @override
  bool operator ==(Object other) =>
      other is CategoryChoice && other.base == base && other.name == name;

  @override
  int get hashCode => Object.hash(base, name);

  @override
  String toString() => 'CategoryChoice($label)';
}

extension ExerciseCategoryLabel on ExerciseRow {
  /// The category to show: your own name for it when there is one.
  CategoryChoice get categoryChoice =>
      CategoryChoice.of(category, customCategory);

  String get categoryLabel => categoryChoice.label;
}

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

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);
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

  int get skippedSets => sets.where((s) => s.isSkipped).length;

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

  int get skippedSets => exercises.fold(0, (s, e) => s + e.skippedSets);

  /// Sets that are neither done nor deliberately skipped.
  ///
  /// A skipped set is not pending: you already said what you wanted to happen
  /// to it, so finishing the session has nothing to ask about it.
  int get pendingSets => totalSets - completedSets - skippedSets;

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

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(workout.startedAt);
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

/// One exercise and, when it is done one hand at a time, which hand.
typedef PreviousKey = ({String exerciseId, SetSide? side});

/// What every exercise in a session looked like the last time round.
///
/// Loaded in one go and keyed by exercise, so the screen asks once instead of
/// twice per exercise per side.
class PreviousSession {
  const PreviousSession({required this.sets, required this.notes});

  static const PreviousSession empty = PreviousSession(sets: {}, notes: {});

  final Map<PreviousKey, List<WorkoutSetRow>> sets;

  /// Only the exercises you actually wrote something about last time.
  final Map<String, String> notes;

  /// Null rather than empty when that exercise has no history at all: the
  /// column shows a dash for the first, and nothing at all for the second.
  List<WorkoutSetRow>? setsFor(String exerciseId, SetSide? side) =>
      sets[(exerciseId: exerciseId, side: side)];

  String? noteFor(String exerciseId) => notes[exerciseId];
}
