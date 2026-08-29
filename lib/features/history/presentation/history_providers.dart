import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';

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

  /// Deleting a workout can invalidate personal records, so they are replayed
  /// from what is left.
  Future<void> deleteWorkout(String workoutId) async {
    await _db.workoutsDao.deleteWorkout(workoutId);
    await _db.recordsDao.rebuildAllRecords();
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
