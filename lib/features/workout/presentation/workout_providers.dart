import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/pr.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/util/notification_service.dart';
import '../domain/pr_ramp.dart';
import '../domain/rest_timer.dart';

part 'workout_providers.g.dart';

/// The running session, or null. Everything on the active workout screen is
/// derived from this one stream, so a write to the database is the only way
/// the UI ever changes.
@Riverpod(keepAlive: true)
Stream<WorkoutDetail?> activeWorkout(Ref ref) =>
    ref.watch(databaseProvider).workoutsDao.watchActiveWorkout();

/// What the same exercise looked like last time, keyed by exercise id.
@riverpod
Future<List<WorkoutSetRow>> previousSets(Ref ref, String exerciseId) async {
  final db = ref.watch(databaseProvider);
  final active = await ref.watch(activeWorkoutProvider.future);
  return db.workoutsDao.previousSetsFor(
    exerciseId,
    excludingWorkoutId: active?.workout.id,
  );
}

/// The note from the previous session, shown as a grey placeholder.
@riverpod
Future<String?> previousNote(Ref ref, String exerciseId) async {
  final db = ref.watch(databaseProvider);
  final active = await ref.watch(activeWorkoutProvider.future);
  return db.workoutsDao.previousNoteFor(
    exerciseId,
    excludingWorkoutId: active?.workout.id,
  );
}

/// The set ids in this workout that produced a personal record.
@riverpod
Future<Set<String>> workoutRecordSetIds(Ref ref, String workoutId) =>
    ref.watch(databaseProvider).recordsDao.recordSetIds(workoutId);

/// The records achieved during one workout.
@riverpod
Future<List<RecordWithExercise>> workoutRecords(Ref ref, String workoutId) =>
    ref.watch(databaseProvider).recordsDao.recordsForWorkout(workoutId);

/// Drives the rest timer. Kept alive so it survives navigation between the
/// workout screen and the full screen countdown.
@Riverpod(keepAlive: true)
class RestTimer extends _$RestTimer {
  @override
  RestTimerState build() => const RestTimerState.idle();

  Future<void> start({
    required int seconds,
    String? exerciseName,
    bool withSound = true,
  }) async {
    if (seconds <= 0) return;
    state = RestTimerState.start(
      seconds: seconds,
      from: DateTime.now(),
      exerciseName: exerciseName,
    );
    await NotificationService.instance.scheduleRestFinished(
      endsAt: state.endsAt!,
      exerciseName: exerciseName ?? 'je volgende set',
      withSound: withSound,
    );
  }

  Future<void> adjust(int deltaSeconds, {bool withSound = true}) async {
    if (!state.isActive) return;
    state = state.adjust(deltaSeconds);
    await NotificationService.instance.scheduleRestFinished(
      endsAt: state.endsAt!,
      exerciseName: state.exerciseName ?? 'je volgende set',
      withSound: withSound,
    );
  }

  Future<void> skip() async {
    state = const RestTimerState.idle();
    await NotificationService.instance.cancelRestFinished();
  }

  /// Marks the "rest is over" feedback as played so it only fires once.
  void markFinishedHandled() {
    if (state.finishedHandled) return;
    state = state.copyWith(finishedHandled: true);
  }
}

/// The result of checking a set off, so the UI knows whether to celebrate.
class SetCompletionResult {
  const SetCompletionResult({
    required this.records,
    required this.restSeconds,
    required this.exerciseName,
    this.isPrAttemptSet = false,
  });

  final List<PrCandidate> records;

  /// 0 when no rest should start (a warm-up set, or mid-superset).
  final int restSeconds;
  final String exerciseName;

  /// True when the set just ticked was the attempt of a PR ladder, so the
  /// screen knows to ask how it went.
  final bool isPrAttemptSet;

  bool get hasRecord => records.isNotEmpty;
}

/// Every write the active workout screen performs.
///
/// There is no "save" button anywhere: each call lands in the database
/// immediately and the UI re-renders from [activeWorkoutProvider].
@Riverpod(keepAlive: true)
WorkoutController workoutController(Ref ref) => WorkoutController(ref);

class WorkoutController {
  const WorkoutController(this.ref);

  final Ref ref;

  AppDatabase get _db => ref.read(databaseProvider);

  Future<int> get _defaultRest async =>
      (await _db.settingsDao.getSettings()).defaultRestSeconds;

  Future<String> startFromRoutine(String routineId) async {
    return _db.workoutsDao.startWorkout(
      routineId: routineId,
      defaultRestSeconds: await _defaultRest,
    );
  }

  Future<String> startEmpty({String? name}) async {
    return _db.workoutsDao.startWorkout(
      name: name ?? 'Losse workout',
      defaultRestSeconds: await _defaultRest,
    );
  }

  /// Starts the same session again: same exercises, same sets, nothing
  /// filled in. Throws if a workout is already running.
  Future<String> repeat(String workoutId) async {
    return _db.workoutsDao.startFromWorkout(
      workoutId,
      defaultRestSeconds: await _defaultRest,
    );
  }

  Future<void> rename(String workoutId, String name) =>
      _db.workoutsDao.renameWorkout(workoutId, name);

  Future<void> addExercises(String workoutId, List<String> exerciseIds) async {
    final settings = await _db.settingsDao.getSettings();
    await _db.workoutsDao.addExercises(
      workoutId,
      exerciseIds,
      defaultRestSeconds: settings.defaultRestSeconds,
      warmupSets: settings.defaultWarmupSets,
    );
  }

  Future<void> removeExercise(String workoutExerciseId) =>
      _db.workoutsDao.removeExercise(workoutExerciseId);

  Future<void> replaceExercise(String workoutExerciseId, String exerciseId) =>
      _db.workoutsDao.replaceExercise(workoutExerciseId, exerciseId);

  Future<void> reorderExercises(List<String> orderedIds) =>
      _db.workoutsDao.reorderExercises(orderedIds);

  Future<void> setExerciseNote(String workoutExerciseId, String? note) =>
      _db.workoutsDao.updateWorkoutExercise(
        workoutExerciseId,
        notes: Value(note == null || note.trim().isEmpty ? null : note.trim()),
      );

  Future<void> setExerciseRest(String workoutExerciseId, int seconds) =>
      _db.workoutsDao.updateWorkoutExercise(
        workoutExerciseId,
        restSeconds: Value(seconds),
      );

  Future<void> setSupersetGroup(String workoutExerciseId, int? group) =>
      _db.workoutsDao.updateWorkoutExercise(
        workoutExerciseId,
        supersetGroup: Value(group),
      );

  /// Returns the id of the new set, so callers can act on it right away.
  Future<String> addSet(String workoutExerciseId, {SetType? setType}) =>
      _db.workoutsDao.addSet(
        workoutExerciseId,
        setType: setType ?? SetType.normal,
      );

  Future<void> deleteSet(String setId) async {
    await _db.workoutsDao.deleteSet(setId);
    await _recalculate();
  }

  Future<void> updateSetValues(
    String setId, {
    Value<double?> weightKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<double?> distanceM = const Value.absent(),
    Value<double?> rpe = const Value.absent(),
  }) async {
    await _db.workoutsDao.updateSet(
      setId,
      weightKg: weightKg,
      reps: reps,
      durationSeconds: durationSeconds,
      distanceM: distanceM,
      rpe: rpe,
    );
    await _recalculate();
  }

  Future<void> setSetType(String setId, SetType type) async {
    await _db.workoutsDao.updateSet(setId, setType: Value(type.wire));
    await _recalculate();
  }

  Future<void> insertWarmupSets(
    String workoutExerciseId,
    List<({double weightKg, int reps})> warmups,
  ) => _db.workoutsDao.prependWarmupSets(workoutExerciseId, warmups);

  /// Checks a set off: writes the values, runs the personal record check and
  /// reports how long the rest should be.
  Future<SetCompletionResult?> completeSet({
    required String setId,
    double? weightKg,
    int? reps,
    int? durationSeconds,
  }) async {
    // Read straight from the DAO rather than from activeWorkoutProvider: a
    // provider only starts once something listens to it, and this method must
    // work no matter which screen calls it.
    final running = await _db.workoutsDao.getActiveWorkoutRow();
    if (running == null) return null;
    final workout = await _db.workoutsDao.getWorkoutDetail(running.id);
    if (workout == null) return null;

    WorkoutExerciseDetail? owner;
    WorkoutSetRow? row;
    for (final exercise in workout.exercises) {
      for (final s in exercise.sets) {
        if (s.id == setId) {
          owner = exercise;
          row = s;
        }
      }
    }
    if (owner == null || row == null) return null;

    final now = DateTime.now();
    final finalWeight = weightKg ?? row.weightKg;
    final finalReps = reps ?? row.reps;
    final finalDuration = durationSeconds ?? row.durationSeconds;

    await _db.workoutsDao.updateSet(
      setId,
      weightKg: Value(finalWeight),
      reps: Value(finalReps),
      durationSeconds: Value(finalDuration),
      isCompleted: const Value(true),
      completedAt: Value(now.millisecondsSinceEpoch),
    );

    final setType = SetType.fromWire(row.setType);
    final records = await _db.recordsDao.registerSet(
      exerciseId: owner.exercise.id,
      workoutSetId: setId,
      setType: setType,
      isCompleted: true,
      weightKg: finalWeight,
      reps: finalReps,
      achievedAt: now.millisecondsSinceEpoch,
    );

    await _recalculate();

    return SetCompletionResult(
      records: records,
      restSeconds: _restFor(workout, owner, row, setType),
      exerciseName: _nextExerciseName(workout, owner),
      isPrAttemptSet:
          owner.workoutExercise.isPrAttempt && setType != SetType.warmup,
    );
  }

  Future<void> uncompleteSet(String setId) async {
    await _db.workoutsDao.updateSet(
      setId,
      isCompleted: const Value(false),
      completedAt: const Value(null),
    );
    await _recalculate();
    // A record may have come from this set, so the history is replayed.
    await _db.recordsDao.rebuildAllRecords();
  }

  /// Inside a superset the rest only starts after the last exercise of the
  /// group; between the members you move straight on.
  int _restFor(
    WorkoutDetail workout,
    WorkoutExerciseDetail exercise,
    WorkoutSetRow row,
    SetType setType,
  ) {
    // A PR ladder rests between its warm-ups too, and longer as the bar gets
    // heavier. Recomputing from the reps reproduces exactly what the ladder
    // proposed, without storing a rest per set.
    if (exercise.workoutExercise.isPrAttempt) {
      return setType == SetType.warmup
          ? restForReps(row.reps ?? 1)
          : kAttemptRestSeconds;
    }

    if (setType == SetType.warmup) return 0;

    final group = exercise.workoutExercise.supersetGroup;
    if (group != null) {
      final members = workout.supersetMembers(group);
      final isLast =
          members.isNotEmpty &&
          members.last.workoutExercise.id == exercise.workoutExercise.id;
      if (!isLast) return 0;
    }
    return exercise.workoutExercise.restSeconds;
  }

  /// The name shown on the rest screen: the next exercise in a superset, or
  /// the current one.
  String _nextExerciseName(
    WorkoutDetail workout,
    WorkoutExerciseDetail exercise,
  ) {
    final group = exercise.workoutExercise.supersetGroup;
    if (group != null) {
      final members = workout.supersetMembers(group);
      final index = members.indexWhere(
        (m) => m.workoutExercise.id == exercise.workoutExercise.id,
      );
      if (index >= 0 && index + 1 < members.length) {
        return members[index + 1].exercise.name;
      }
      if (members.isNotEmpty) return members.first.exercise.name;
    }
    return exercise.exercise.name;
  }

  Future<void> _recalculate() async {
    final workout = await _db.workoutsDao.getActiveWorkoutRow();
    if (workout != null) {
      await _db.workoutsDao.recalculateTotals(workout.id);
    }
  }

  Future<void> finish(
    String workoutId, {
    required bool discardPending,
    String? notes,
  }) async {
    await _db.workoutsDao.finishWorkout(
      workoutId,
      discardPending: discardPending,
      notes: notes,
    );
    await ref.read(restTimerProvider.notifier).skip();
  }

  Future<void> cancel(String workoutId) async {
    // Same single transaction as deleting from the history: children, records
    // and the routine stamp all go together.
    await _db.workoutsDao.deleteWorkoutCompletely(workoutId);
    await ref.read(restTimerProvider.notifier).skip();
  }

  /// Saves a finished session as a new routine.
  Future<String> saveAsRoutine(String workoutId, String name) async {
    final detail = await _db.workoutsDao.getWorkoutDetail(workoutId);
    if (detail == null) throw StateError('Workout $workoutId bestaat niet');

    return _db.routinesDao.createRoutine(
      RoutineDraft(
        name: name,
        exercises: detail.exercises
            .map(
              (e) => RoutineExerciseDraft(
                exerciseId: e.exercise.id,
                restSeconds: e.workoutExercise.restSeconds,
                supersetGroup: e.workoutExercise.supersetGroup,
                notes: e.workoutExercise.notes,
                sets: e.sets
                    .where((s) => SetType.fromWire(s.setType) != SetType.warmup)
                    .map(
                      (s) => RoutineSetDraft(
                        setType: SetType.fromWire(s.setType),
                        targetReps: s.reps,
                        targetWeightKg: s.weightKg,
                        targetDurationSeconds: s.durationSeconds,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  /// A plain-text summary for the system share sheet.
  Future<String> shareText(String workoutId) async {
    final detail = await _db.workoutsDao.getWorkoutDetail(workoutId);
    if (detail == null) return '';
    final formatters = ref.read(formattersProvider);
    final buffer = StringBuffer()
      ..writeln(detail.workout.name)
      ..writeln(
        '${detail.workout.durationSeconds ~/ 60} min - '
        '${formatters.volume(detail.workout.totalVolumeKg)} - '
        '${detail.workout.totalSets} sets',
      )
      ..writeln();

    for (final exercise in detail.exercises) {
      buffer.writeln(exercise.exercise.name);
      var index = 1;
      for (final s in exercise.sets.where((s) => s.isCompleted)) {
        final marker = SetType.fromWire(s.setType).marker ?? '${index++}';
        buffer.writeln(
          '  $marker  ${formatters.setSummary(
            weightKg: s.weightKg,
            reps: s.reps,
            durationSeconds: s.durationSeconds,
          )}',
        );
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}
