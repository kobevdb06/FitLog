import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../workout/presentation/workout_providers.dart';

part 'history_providers.g.dart';

@riverpod
Stream<List<WorkoutSummary>> workoutHistory(Ref ref, {int? limit}) =>
    ref.watch(databaseProvider).workoutsDao.watchFinishedWorkouts(limit: limit);

@riverpod
Stream<WorkoutDetail?> workoutDetail(Ref ref, String workoutId) =>
    ref.watch(databaseProvider).workoutsDao.watchWorkoutDetail(workoutId);

/// Every finished workout inside one month, for the calendar.
@riverpod
Stream<List<WorkoutRow>> workoutsInMonth(Ref ref, int year, int month) {
  final from = DateTime(year, month);
  final to = DateTime(year, month + 1);
  return ref.watch(databaseProvider).workoutsDao.watchWorkoutsBetween(from, to);
}

/// The dates of every finished workout, used by the streak.
@riverpod
Stream<List<DateTime>> finishedWorkoutDates(Ref ref) =>
    ref.watch(databaseProvider).workoutsDao.watchFinishedWorkoutDates();

@riverpod
HistoryActions historyActions(Ref ref) => HistoryActions(ref);

/// Editing a session after the fact.
class HistoryActions {
  const HistoryActions(this.ref);

  final Ref ref;

  AppDatabase get _db => ref.read(databaseProvider);

  /// Removes a workout, its children, the records it set and the routine stamp
  /// it left behind, all in one transaction.
  ///
  /// When the deleted session was the running one, the in-memory session state
  /// is torn down too; otherwise the rest timer keeps ticking for a workout
  /// that no longer exists.
  Future<void> deleteWorkout(String workoutId) async {
    final deleted = await _db.workoutsDao.deleteWorkoutCompletely(workoutId);
    if (!deleted.existed) return;

    if (deleted.wasRunning) {
      await ref.read(restTimerProvider.notifier).skip();
      ref.read(appControllerProvider.notifier).workoutInProgress = false;
    }
  }

  /// Changing a logged set recomputes the workout totals and the records.
  Future<void> updateSet(
    String workoutId,
    String setId, {
    double? weightKg,
    int? reps,
    bool? isCompleted,
  }) async {
    await _db.workoutsDao.updateSet(
      setId,
      weightKg: weightKg == null ? const Value.absent() : Value(weightKg),
      reps: reps == null ? const Value.absent() : Value(reps),
      isCompleted: isCompleted == null
          ? const Value.absent()
          : Value(isCompleted),
    );
    await _db.workoutsDao.recalculateTotals(workoutId);
    await _db.recordsDao.rebuildAllRecords();
  }

  Future<void> deleteSet(String workoutId, String setId) async {
    await _db.workoutsDao.deleteSet(setId);
    await _db.workoutsDao.recalculateTotals(workoutId);
    await _db.recordsDao.rebuildAllRecords();
  }

  Future<void> rename(String workoutId, String name) =>
      _db.workoutsDao.renameWorkout(workoutId, name);

  Future<void> setNotes(String workoutId, String? notes) =>
      _db.workoutsDao.setWorkoutNotes(workoutId, notes);
}


/// Workouts that are on their way out but can still be brought back.
///
/// Undo is implemented by delaying the delete, not by restoring a copy
/// afterwards: for five seconds the row is only hidden from the list, and
/// nothing has happened in the database yet.
@Riverpod(keepAlive: true)
class PendingWorkoutDeletions extends _$PendingWorkoutDeletions {
  static const Duration grace = Duration(seconds: 5);

  final Map<String, Timer> _timers = {};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  bool isPending(String workoutId) => state.contains(workoutId);

  /// Hides [workoutId] and deletes it once the grace period runs out.
  void schedule(String workoutId) {
    _timers.remove(workoutId)?.cancel();
    state = {...state, workoutId};
    _timers[workoutId] = Timer(grace, () => _commit(workoutId));
  }

  /// Brings the workout back. Nothing was ever removed.
  void undo(String workoutId) {
    _timers.remove(workoutId)?.cancel();
    state = {...state}..remove(workoutId);
  }

  /// Deletes right away instead of waiting out the grace period.
  Future<void> commitNow(String workoutId) async {
    if (!state.contains(workoutId)) return;
    _timers.remove(workoutId)?.cancel();
    await _commit(workoutId);
  }

  Future<void> _commit(String workoutId) async {
    _timers.remove(workoutId);
    await ref.read(historyActionsProvider).deleteWorkout(workoutId);
    state = {...state}..remove(workoutId);
  }
}
