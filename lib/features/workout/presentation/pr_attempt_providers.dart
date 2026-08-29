import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/one_rm.dart';
import '../../../core/calc/plates.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/pr_ramp.dart';
import 'workout_providers.dart';

part 'pr_attempt_providers.g.dart';

/// What the app already knows about this exercise before an attempt starts.
class PrBaseline {
  const PrBaseline({
    required this.estimatedOneRmKg,
    required this.sourceWeightKg,
    required this.sourceReps,
    required this.sourceDate,
    required this.recentVolumeKg,
  });

  const PrBaseline.unknown()
    : estimatedOneRmKg = null,
      sourceWeightKg = null,
      sourceReps = null,
      sourceDate = null,
      recentVolumeKg = 0;

  /// Epley estimate from the best working set on record.
  final double? estimatedOneRmKg;

  final double? sourceWeightKg;
  final int? sourceReps;
  final DateTime? sourceDate;

  /// Working volume for this exercise in the last 48 hours.
  final double recentVolumeKg;

  bool get hasEstimate => estimatedOneRmKg != null;

  /// True when this exercise was worked hard recently enough to matter.
  bool get trainedRecently => recentVolumeKg > 0;
}

@riverpod
Future<PrBaseline> prBaseline(Ref ref, String exerciseId) async {
  final dao = ref.watch(databaseProvider).workoutsDao;
  final active = await dao.getActiveWorkoutRow();

  final best = await dao.bestOneRmSet(exerciseId);
  final recent = await dao.recentVolumeFor(
    exerciseId,
    window: kFatigueWindow,
    excludingWorkoutId: active?.id,
  );

  if (best == null) {
    return PrBaseline(
      estimatedOneRmKg: null,
      sourceWeightKg: null,
      sourceReps: null,
      sourceDate: null,
      recentVolumeKg: recent,
    );
  }

  return PrBaseline(
    estimatedOneRmKg: estimatedOneRm(
      weightKg: best.weightKg,
      reps: best.reps,
    ),
    sourceWeightKg: best.weightKg,
    sourceReps: best.reps,
    sourceDate: best.at,
    recentVolumeKg: recent,
  );
}

/// Everything the configuration screen holds while the user tweaks it.
class PrAttemptConfig {
  const PrAttemptConfig({
    required this.targetKg,
    required this.warmupSets,
    required this.extraAttempts,
    required this.barKg,
    required this.platesKg,
  });

  final double targetKg;
  final int warmupSets;
  final int extraAttempts;
  final double barKg;
  final List<double> platesKg;

  PrAttemptConfig copyWith({
    double? targetKg,
    int? warmupSets,
    int? extraAttempts,
    double? barKg,
    List<double>? platesKg,
  }) {
    return PrAttemptConfig(
      targetKg: targetKg ?? this.targetKg,
      warmupSets: warmupSets ?? this.warmupSets,
      extraAttempts: extraAttempts ?? this.extraAttempts,
      barKg: barKg ?? this.barKg,
      platesKg: platesKg ?? this.platesKg,
    );
  }

  /// Rebuilt on every change, which is what makes the preview live.
  PrRamp? get ramp => buildPrRamp(
    targetKg: targetKg,
    warmupSets: warmupSets,
    barKg: barKg,
    platesKg: platesKg,
  );
}

/// The starting point for the configuration screen.
///
/// The target is prefilled with the current estimate plus the smallest step
/// the available plates can make, so the default is a real, loadable attempt.
PrAttemptConfig initialPrConfig({
  required PrBaseline baseline,
  required AppSettingsRow settings,
  required BarbellSetup setup,
}) {
  final estimate = baseline.estimatedOneRmKg;
  final smallestStep = setup.platesKg.isEmpty
      ? 2.5
      : setup.platesKg.reduce((a, b) => a < b ? a : b) * 2;

  final proposed = estimate == null
      ? setup.barKg + smallestStep * 4
      : estimate + smallestStep;

  return PrAttemptConfig(
    targetKg: nearestAchievableWeightKg(
      targetKg: proposed,
      barKg: setup.barKg,
      availablePlatesKg: setup.platesKg,
    ),
    warmupSets: settings.prDefaultWarmupSets.clamp(
      kMinPrWarmupSets,
      kMaxPrWarmupSets,
    ),
    extraAttempts: settings.prDefaultExtraAttempts.clamp(0, 3),
    barKg: setup.barKg,
    platesKg: setup.platesKg,
  );
}

@riverpod
PrAttemptActions prAttemptActions(Ref ref) => PrAttemptActions(ref);

/// Starting, finishing and undoing a PR attempt.
class PrAttemptActions {
  const PrAttemptActions(this.ref);

  final Ref ref;

  AppDatabase get _db => ref.read(databaseProvider);

  /// Puts the ladder into the running session, starting one if needed.
  ///
  /// Returns the id of the workout exercise that now holds the attempt.
  Future<String> start({
    required String exerciseId,
    required PrAttemptConfig config,
    String? existingWorkoutExerciseId,
  }) async {
    final ramp = config.ramp;
    if (ramp == null) {
      throw ArgumentError('Dit doelgewicht past niet op de stang');
    }

    final controller = ref.read(workoutControllerProvider);

    var workoutExerciseId = existingWorkoutExerciseId;
    if (workoutExerciseId == null) {
      final running = await _db.workoutsDao.getActiveWorkoutRow();
      final workoutId = running?.id ?? await controller.startEmpty();

      final before = await _db.workoutsDao.getWorkoutDetail(workoutId);
      await controller.addExercises(workoutId, [exerciseId]);
      final after = await _db.workoutsDao.getWorkoutDetail(workoutId);

      final known = {
        for (final e in before?.exercises ?? const []) e.workoutExercise.id,
      };
      workoutExerciseId = after!.exercises
          .firstWhere((e) => !known.contains(e.workoutExercise.id))
          .workoutExercise
          .id;
    }

    await _db.workoutsDao.applyPrRamp(
      workoutExerciseId: workoutExerciseId,
      targetKg: ramp.achievedTargetKg,
      ladder: [
        for (final set in ramp.sets)
          (
            weightKg: set.weightKg,
            reps: set.reps,
            restSeconds: set.restSeconds,
          ),
      ],
    );

    return workoutExerciseId;
  }

  Future<void> finish(
    String workoutExerciseId,
    PrAttemptResult result,
  ) => _db.workoutsDao.setPrResult(workoutExerciseId, result);

  Future<void> revertToNormalExercise(String workoutExerciseId) =>
      _db.workoutsDao.clearPrAttempt(workoutExerciseId);

  /// Adds one more attempt on top of a successful one.
  Future<void> addFollowUpAttempt({
    required String workoutExerciseId,
    required double achievedKg,
    required List<double> platesKg,
    required double barKg,
  }) async {
    final next = nextTargetAfterSuccess(
      achievedKg: achievedKg,
      platesKg: platesKg,
    );
    final weight = nearestAchievableWeightKg(
      targetKg: next,
      barKg: barKg,
      availablePlatesKg: platesKg,
    );

    final setId = await _db.workoutsDao.addSet(workoutExerciseId);
    await _db.workoutsDao.updateSet(
      setId,
      weightKg: Value(weight),
      reps: const Value(1),
    );
    await _db.workoutsDao.setPrResult(workoutExerciseId, null);
    await (_db.update(_db.workoutExercisesTable)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .write(WorkoutExercisesTableCompanion(prTargetWeightKg: Value(weight)));
  }

  /// Adds the back-off single after a failed attempt.
  Future<void> addBackoffSingle({
    required String workoutExerciseId,
    required double previousBestKg,
    required List<double> platesKg,
    required double barKg,
  }) async {
    final weight = backoffAfterFailure(
      previousBestKg: previousBestKg,
      barKg: barKg,
      platesKg: platesKg,
    );
    final setId = await _db.workoutsDao.addSet(workoutExerciseId);
    await _db.workoutsDao.updateSet(
      setId,
      weightKg: Value(weight),
      reps: const Value(1),
    );
  }
}
