import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/one_rm.dart';
import '../../../core/calc/volume.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';

part 'exercise_providers.g.dart';

const _uuid = Uuid();

/// The filter the exercise list is showing. Lives above the list so the search
/// field and the chips stay in sync.
@riverpod
class ExerciseFilterController extends _$ExerciseFilterController {
  @override
  ExerciseFilter build() => const ExerciseFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleMuscle(String muscle) {
    final next = Set<String>.from(state.muscles);
    next.contains(muscle) ? next.remove(muscle) : next.add(muscle);
    state = state.copyWith(muscles: next);
  }

  void toggleEquipment(String equipment) {
    final next = Set<String>.from(state.equipment);
    next.contains(equipment) ? next.remove(equipment) : next.add(equipment);
    state = state.copyWith(equipment: next);
  }

  void toggleCategory(String category) {
    final next = Set<String>.from(state.categories);
    next.contains(category) ? next.remove(category) : next.add(category);
    state = state.copyWith(categories: next);
  }

  void setCustomOnly(bool value) => state = state.copyWith(customOnly: value);

  void clear() => state = const ExerciseFilter();
}

@riverpod
Stream<List<ExerciseRow>> filteredExercises(Ref ref) {
  final filter = ref.watch(exerciseFilterControllerProvider);
  return ref.watch(databaseProvider).exercisesDao.watchExercises(filter);
}

@riverpod
Stream<ExerciseRow?> exerciseById(Ref ref, String id) =>
    ref.watch(databaseProvider).exercisesDao.watchById(id);

@riverpod
Future<List<String>> muscleOptions(Ref ref) =>
    ref.watch(databaseProvider).exercisesDao.distinctPrimaryMuscles();

@riverpod
Future<List<String>> equipmentOptions(Ref ref) =>
    ref.watch(databaseProvider).exercisesDao.distinctEquipment();

/// The exercises used most recently, shown at the top of the picker.
@riverpod
Future<List<ExerciseRow>> recentExercises(Ref ref) async {
  final dao = ref.watch(databaseProvider).exercisesDao;
  final ids = await dao.recentExerciseIds();
  if (ids.isEmpty) return const [];
  final rows = await dao.getByIds(ids);
  final byId = {for (final r in rows) r.id: r};
  return [
    for (final id in ids)
      if (byId[id] != null && !byId[id]!.isArchived) byId[id]!,
  ];
}

@riverpod
Future<List<ExerciseSession>> exerciseSessions(Ref ref, String exerciseId) =>
    ref.watch(databaseProvider).workoutsDao.exerciseSessions(exerciseId);

@riverpod
Stream<List<PersonalRecordRow>> exerciseRecords(Ref ref, String exerciseId) =>
    ref.watch(databaseProvider).recordsDao.watchRecordsForExercise(exerciseId);

@riverpod
Future<int> exerciseUsageCount(Ref ref, String exerciseId) =>
    ref.watch(databaseProvider).exercisesDao.timesUsed(exerciseId);

/// Which line the exercise chart is drawing.
enum ExerciseMetric {
  oneRm('Geschatte 1RM'),
  volume('Volume per sessie'),
  bestSet('Beste set'),
  totalReps('Totale reps');

  const ExerciseMetric(this.label);

  final String label;
}

/// The time span of the exercise chart.
enum ChartRange {
  month('1 maand', Duration(days: 31)),
  quarter('3 maanden', Duration(days: 92)),
  year('1 jaar', Duration(days: 366)),
  all('Alles', null);

  const ChartRange(this.label, this.window);

  final String label;
  final Duration? window;
}

/// Turns the sessions of one exercise into chart points.
List<ChartPoint> buildExerciseSeries({
  required List<ExerciseSession> sessions,
  required ExerciseMetric metric,
  required ChartRange range,
  DateTime? now,
}) {
  final cutoff = range.window == null
      ? null
      : (now ?? DateTime.now()).subtract(range.window!);

  final points = <ChartPoint>[];
  for (final session in sessions) {
    if (cutoff != null && session.date.isBefore(cutoff)) continue;

    final working = session.sets
        .where(
          (s) =>
              s.isCompleted &&
              SetType.fromWire(s.setType).countsTowardsVolume,
        )
        .toList();
    if (working.isEmpty) continue;

    double? value;
    switch (metric) {
      case ExerciseMetric.oneRm:
        for (final s in working) {
          final estimate = estimatedOneRm(weightKg: s.weightKg, reps: s.reps);
          if (estimate != null && (value == null || estimate > value)) {
            value = estimate;
          }
        }
      case ExerciseMetric.volume:
        value = working.fold<double>(
          0,
          (sum, s) => sum + setVolumeKg(weightKg: s.weightKg, reps: s.reps),
        );
      case ExerciseMetric.bestSet:
        for (final s in working) {
          final w = s.weightKg;
          if (w != null && (value == null || w > value)) value = w;
        }
      case ExerciseMetric.totalReps:
        value = working
            .fold<int>(0, (sum, s) => sum + (s.reps ?? 0))
            .toDouble();
    }

    if (value != null && value > 0) {
      points.add(ChartPoint(session.date, value));
    }
  }

  points.sort((a, b) => a.at.compareTo(b.at));
  return points;
}

/// Creating and editing exercises the user made themselves.
// Kept alive on purpose. These objects hold a `Ref` and every one of their
// callers uses them across an async gap: a confirmation dialog, the photo
// picker, the PR configuration screen. An auto-disposing provider is torn down
// while that gap is open, and the next call throws on a dead `Ref`.
@Riverpod(keepAlive: true)
ExerciseEditor exerciseEditor(Ref ref) => ExerciseEditor(ref);

class ExerciseEditor {
  const ExerciseEditor(this.ref);

  final Ref ref;

  Future<String> create({
    required String name,
    required String primaryMuscle,
    required List<String> secondaryMuscles,
    required ExerciseCategory category,
    String? equipment,
    String? instructions,
  }) async {
    final id = _uuid.v4();
    await ref
        .read(databaseProvider)
        .exercisesDao
        .insertExercise(
          ExercisesTableCompanion.insert(
            id: id,
            name: name.trim(),
            primaryMuscle: primaryMuscle,
            secondaryMuscles: Value(jsonEncode(secondaryMuscles)),
            equipment: Value(equipment),
            category: category.wire,
            instructions: Value(
              instructions == null || instructions.trim().isEmpty
                  ? null
                  : instructions.trim(),
            ),
            isCustom: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    return id;
  }

  Future<void> update({
    required String id,
    required String name,
    required String primaryMuscle,
    required List<String> secondaryMuscles,
    required ExerciseCategory category,
    String? equipment,
    String? instructions,
  }) {
    return ref
        .read(databaseProvider)
        .exercisesDao
        .updateExercise(
          id,
          ExercisesTableCompanion(
            name: Value(name.trim()),
            primaryMuscle: Value(primaryMuscle),
            secondaryMuscles: Value(jsonEncode(secondaryMuscles)),
            equipment: Value(equipment),
            category: Value(category.wire),
            instructions: Value(
              instructions == null || instructions.trim().isEmpty
                  ? null
                  : instructions.trim(),
            ),
          ),
        );
  }

  /// Removes a custom exercise, or archives it when it appears in history.
  ///
  /// Deleting a logged exercise would cascade into personal records and leave
  /// holes in old workouts, so those are hidden instead.
  Future<bool> removeOrArchive(String id) async {
    final dao = ref.read(databaseProvider).exercisesDao;
    final used = await dao.timesUsed(id);
    if (used == 0) {
      await dao.deleteExercise(id);
      return true;
    }
    await dao.setArchived(id, archived: true);
    return false;
  }
}

/// Reads the JSON array of secondary muscles off a row.
List<String> decodeSecondaryMuscles(String raw) {
  try {
    return (jsonDecode(raw) as List).cast<String>();
  } on FormatException {
    return const [];
  }
}
