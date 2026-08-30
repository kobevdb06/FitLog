import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../calc/recovery.dart';
import '../../calc/volume.dart';
import '../database.dart';
import '../models.dart';

part 'workouts_dao.drift.dart';

/// What [WorkoutsDao.deleteWorkoutCompletely] removed.
class DeletedWorkout {
  const DeletedWorkout({
    required this.existed,
    required this.wasRunning,
    required this.exerciseIds,
  });

  final bool existed;

  /// True when the deleted session was the one with `ended_at IS NULL`, so the
  /// caller knows to tear down the timer and the in-progress flag as well.
  final bool wasRunning;

  final Set<String> exerciseIds;
}

const _uuid = Uuid();

@DriftAccessor(
  tables: [
    WorkoutsTable,
    WorkoutExercisesTable,
    WorkoutSetsTable,
    ExercisesTable,
    RoutinesTable,
    RoutineExercisesTable,
    RoutineSetsTable,
    PersonalRecordsTable,
  ],
)
class WorkoutsDao extends DatabaseAccessor<AppDatabase> with _$WorkoutsDaoMixin {
  WorkoutsDao(super.db);

  // --- The running session --------------------------------------------------

  /// There can only ever be one workout with `ended_at IS NULL`.
  Future<WorkoutRow?> getActiveWorkoutRow() => (select(
    workoutsTable,
  )..where((t) => t.endedAt.isNull())).getSingleOrNull();

  Stream<WorkoutDetail?> watchActiveWorkout() {
    return customSelect(
      'SELECT id FROM workouts WHERE ended_at IS NULL LIMIT 1',
      readsFrom: {workoutsTable, workoutExercisesTable, workoutSetsTable},
    ).watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return getWorkoutDetail(rows.first.read<String>('id'));
    });
  }

  /// Starts a session, optionally pre-filled from a routine.
  ///
  /// Throws when a session is already running: the UI must resume that one.
  Future<String> startWorkout({
    String? routineId,
    String? name,
    required int defaultRestSeconds,
  }) async {
    final running = await getActiveWorkoutRow();
    if (running != null) {
      throw StateError('Er loopt al een workout (${running.id})');
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await transaction(() async {
      RoutineRow? routine;
      if (routineId != null) {
        routine = await (select(
          routinesTable,
        )..where((t) => t.id.equals(routineId))).getSingleOrNull();
      }

      await into(workoutsTable).insert(
        WorkoutsTableCompanion.insert(
          id: id,
          routineId: Value(routine?.id),
          name: name ?? routine?.name ?? 'Losse workout',
          startedAt: now,
          notes: const Value(null),
        ),
      );

      if (routine == null) return;

      final routineExercises =
          await (select(routineExercisesTable)
                ..where((t) => t.routineId.equals(routine!.id))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();

      for (var i = 0; i < routineExercises.length; i++) {
        final re = routineExercises[i];
        final weId = _uuid.v4();
        await into(workoutExercisesTable).insert(
          WorkoutExercisesTableCompanion.insert(
            id: weId,
            workoutId: id,
            exerciseId: re.exerciseId,
            sortOrder: i,
            restSeconds: Value(re.restSeconds ?? defaultRestSeconds),
            supersetGroup: Value(re.supersetGroup),
            notes: Value(re.notes),
          ),
        );

        final plannedSets =
            await (select(routineSetsTable)
                  ..where((t) => t.routineExerciseId.equals(re.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
                .get();

        await batch((b) {
          for (var j = 0; j < plannedSets.length; j++) {
            final s = plannedSets[j];
            b.insert(
              workoutSetsTable,
              WorkoutSetsTableCompanion.insert(
                id: _uuid.v4(),
                workoutExerciseId: weId,
                sortOrder: j,
                setType: Value(s.setType),
                weightKg: Value(s.targetWeightKg),
                reps: Value(s.targetReps),
                durationSeconds: Value(s.targetDurationSeconds),
              ),
            );
          }
        });
      }
    });

    return id;
  }

  // --- Reading --------------------------------------------------------------

  Future<WorkoutDetail?> getWorkoutDetail(String workoutId) async {
    final workout = await (select(
      workoutsTable,
    )..where((t) => t.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return null;
    return WorkoutDetail(
      workout: workout,
      exercises: await _loadWorkoutExercises(workoutId),
    );
  }

  Stream<WorkoutDetail?> watchWorkoutDetail(String workoutId) {
    return customSelect(
      'SELECT id FROM workouts WHERE id = ?',
      variables: [Variable.withString(workoutId)],
      readsFrom: {workoutsTable, workoutExercisesTable, workoutSetsTable},
    ).watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return getWorkoutDetail(workoutId);
    });
  }

  Future<List<WorkoutExerciseDetail>> _loadWorkoutExercises(
    String workoutId,
  ) async {
    final joined =
        await (select(workoutExercisesTable)
                  ..where((t) => t.workoutId.equals(workoutId))
                  ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
                .join([
                  innerJoin(
                    exercisesTable,
                    exercisesTable.id.equalsExp(
                      workoutExercisesTable.exerciseId,
                    ),
                  ),
                ])
                .get();
    if (joined.isEmpty) return const [];

    final ids = joined
        .map((r) => r.readTable(workoutExercisesTable).id)
        .toList();
    final sets =
        await (select(workoutSetsTable)
              ..where((t) => t.workoutExerciseId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    return joined.map((row) {
      final we = row.readTable(workoutExercisesTable);
      return WorkoutExerciseDetail(
        workoutExercise: we,
        exercise: row.readTable(exercisesTable),
        sets: sets
            .where((s) => s.workoutExerciseId == we.id)
            .toList(growable: false),
      );
    }).toList(growable: false);
  }

  // --- Editing the session --------------------------------------------------

  /// Adds exercises to a session.
  ///
  /// [warmupSets] comes from the user's preference: the exercise then starts
  /// with that many warm-up rows above its first working set.
  Future<List<String>> addExercises(
    String workoutId,
    List<String> exerciseIds, {
    required int defaultRestSeconds,
    int warmupSets = 0,
  }) async {
    final created = <String>[];
    await transaction(() async {
      final max = workoutExercisesTable.sortOrder.max();
      final row =
          await (selectOnly(workoutExercisesTable)
                ..addColumns([max])
                ..where(workoutExercisesTable.workoutId.equals(workoutId)))
              .getSingle();
      var next = (row.read(max) ?? -1) + 1;

      for (final exerciseId in exerciseIds) {
        final id = _uuid.v4();
        created.add(id);
        await into(workoutExercisesTable).insert(
          WorkoutExercisesTableCompanion.insert(
            id: id,
            workoutId: workoutId,
            exerciseId: exerciseId,
            sortOrder: next++,
            restSeconds: Value(defaultRestSeconds),
          ),
        );
        // A new exercise always ends up with at least one working set so
        // there is something to tap, preceded by the configured warm-ups.
        final rows = <WorkoutSetsTableCompanion>[
          for (var w = 0; w < warmupSets.clamp(0, 5); w++)
            WorkoutSetsTableCompanion.insert(
              id: _uuid.v4(),
              workoutExerciseId: id,
              sortOrder: w,
              setType: Value(SetType.warmup.wire),
            ),
          WorkoutSetsTableCompanion.insert(
            id: _uuid.v4(),
            workoutExerciseId: id,
            sortOrder: warmupSets.clamp(0, 5),
          ),
        ];
        await batch((b) => b.insertAll(workoutSetsTable, rows));
      }
    });
    return created;
  }

  Future<void> removeExercise(String workoutExerciseId) async {
    await (delete(workoutExercisesTable)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .go();
  }

  Future<void> replaceExercise(
    String workoutExerciseId,
    String newExerciseId,
  ) async {
    await (update(workoutExercisesTable)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .write(
          WorkoutExercisesTableCompanion(exerciseId: Value(newExerciseId)),
        );
  }

  Future<void> reorderExercises(List<String> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          workoutExercisesTable,
          WorkoutExercisesTableCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<void> updateWorkoutExercise(
    String workoutExerciseId, {
    Value<int> restSeconds = const Value.absent(),
    Value<int?> supersetGroup = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) async {
    await (update(workoutExercisesTable)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .write(
          WorkoutExercisesTableCompanion(
            restSeconds: restSeconds,
            supersetGroup: supersetGroup,
            notes: notes,
          ),
        );
  }

  // --- PR attempts ----------------------------------------------------------

  /// Turns a workout exercise into a one-rep-max attempt.
  ///
  /// The existing sets are replaced by the ladder: every rung is a warm-up
  /// except the attempt itself, so only the attempt can set a record or count
  /// towards the volume.
  Future<void> applyPrRamp({
    required String workoutExerciseId,
    required double targetKg,
    required List<({double weightKg, int reps, int restSeconds})> ladder,
  }) async {
    await transaction(() async {
      await (delete(workoutSetsTable)
            ..where((t) => t.workoutExerciseId.equals(workoutExerciseId)))
          .go();

      await batch((b) {
        for (var i = 0; i < ladder.length; i++) {
          final isAttempt = i == ladder.length - 1;
          b.insert(
            workoutSetsTable,
            WorkoutSetsTableCompanion.insert(
              id: _uuid.v4(),
              workoutExerciseId: workoutExerciseId,
              sortOrder: i,
              setType: Value(
                isAttempt ? SetType.normal.wire : SetType.warmup.wire,
              ),
              weightKg: Value(ladder[i].weightKg),
              reps: Value(ladder[i].reps),
            ),
          );
        }
      });

      await (update(workoutExercisesTable)
            ..where((t) => t.id.equals(workoutExerciseId)))
          .write(
            WorkoutExercisesTableCompanion(
              isPrAttempt: const Value(true),
              prTargetWeightKg: Value(targetKg),
              prResult: const Value(null),
              // The ladder carries its own rests; this is the fallback the
              // rest bar uses for the attempt.
              restSeconds: Value(ladder.last.restSeconds),
            ),
          );
    });
  }

  /// Records how an attempt ended.
  Future<void> setPrResult(
    String workoutExerciseId,
    PrAttemptResult? result,
  ) async {
    await (update(workoutExercisesTable)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .write(
          WorkoutExercisesTableCompanion(prResult: Value(result?.wire)),
        );
  }

  /// Drops the attempt back to an ordinary exercise, keeping its sets.
  Future<void> clearPrAttempt(String workoutExerciseId) async {
    await (update(workoutExercisesTable)
          ..where((t) => t.id.equals(workoutExerciseId)))
        .write(
          const WorkoutExercisesTableCompanion(
            isPrAttempt: Value(false),
            prTargetWeightKg: Value(null),
            prResult: Value(null),
          ),
        );
  }

  /// The heaviest single that has ever been completed for this exercise,
  /// together with when it happened. Used to prefill an attempt.
  Future<({double weightKg, int reps, DateTime at})?> bestOneRmSet(
    String exerciseId,
  ) async {
    final rows = await customSelect(
      'SELECT ws.weight_kg AS weight_kg, ws.reps AS reps, '
      'COALESCE(ws.completed_at, w.started_at) AS at, '
      'ws.weight_kg * (1 + ws.reps / 30.0) AS estimate '
      'FROM workout_sets ws '
      'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
      'JOIN workouts w ON w.id = we.workout_id '
      'WHERE we.exercise_id = ? AND ws.is_completed = 1 '
      "AND ws.set_type != 'warmup' "
      'AND ws.weight_kg IS NOT NULL AND ws.reps IS NOT NULL '
      'AND ws.weight_kg > 0 AND ws.reps > 0 AND w.ended_at IS NOT NULL '
      'ORDER BY estimate DESC LIMIT 1',
      variables: [Variable.withString(exerciseId)],
      readsFrom: {workoutSetsTable, workoutExercisesTable, workoutsTable},
    ).get();
    if (rows.isEmpty) return null;

    final row = rows.first;
    return (
      weightKg: row.read<double>('weight_kg'),
      reps: row.read<int>('reps'),
      at: DateTime.fromMillisecondsSinceEpoch(row.read<int>('at')),
    );
  }

  /// Total working volume for one exercise inside [window], used for the
  /// neutral fatigue remark before an attempt.
  Future<double> recentVolumeFor(
    String exerciseId, {
    required Duration window,
    String? excludingWorkoutId,
  }) async {
    final since = DateTime.now().subtract(window).millisecondsSinceEpoch;
    final rows = await customSelect(
      'SELECT COALESCE(SUM(ws.weight_kg * ws.reps), 0) AS volume '
      'FROM workout_sets ws '
      'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
      'JOIN workouts w ON w.id = we.workout_id '
      'WHERE we.exercise_id = ? AND ws.is_completed = 1 '
      "AND ws.set_type != 'warmup' AND w.started_at >= ? "
      'AND (? IS NULL OR w.id != ?)',
      variables: [
        Variable.withString(exerciseId),
        Variable.withInt(since),
        Variable<String>(excludingWorkoutId),
        Variable<String>(excludingWorkoutId),
      ],
      readsFrom: {workoutSetsTable, workoutExercisesTable, workoutsTable},
    ).get();
    return rows.first.read<double>('volume');
  }

  /// Every completed working set of every finished workout since [since],
  /// with the exercise and session facts the recovery estimate needs.
  ///
  /// The muscle attribution happens in `core/calc/recovery.dart` rather than
  /// here: secondary muscles are a JSON array in a text column, which SQL
  /// cannot split, and the arithmetic is worth testing without a database.
  Future<List<RecoverySet>> recoverySets({required DateTime since}) async =>
      _recoverySetsQuery(since).get().then(_toRecoverySets);

  /// The same, re-emitted whenever anything it reads changes.
  Stream<List<RecoverySet>> watchRecoverySets({required DateTime since}) =>
      _recoverySetsQuery(since).watch().map(_toRecoverySets);

  Selectable<QueryRow> _recoverySetsQuery(DateTime since) {
    return customSelect(
      'SELECT w.id AS workout_id, w.started_at AS started_at, '
      'w.perceived_effort AS perceived_effort, '
      'we.exercise_id AS exercise_id, we.is_pr_attempt AS is_pr_attempt, '
      'e.primary_muscle AS primary_muscle, '
      'e.secondary_muscles AS secondary_muscles, e.category AS category, '
      'ws.weight_kg AS weight_kg, ws.reps AS reps, ws.set_type AS set_type '
      'FROM workout_sets ws '
      'JOIN workout_exercises we ON we.id = ws.workout_exercise_id '
      'JOIN workouts w ON w.id = we.workout_id '
      'JOIN exercises e ON e.id = we.exercise_id '
      'WHERE ws.is_completed = 1 AND ws.set_type != ? '
      'AND w.ended_at IS NOT NULL AND w.started_at >= ? '
      'ORDER BY w.started_at',
      variables: [
        Variable.withString(SetType.warmup.wire),
        Variable.withInt(since.millisecondsSinceEpoch),
      ],
      readsFrom: {
        workoutSetsTable,
        workoutExercisesTable,
        workoutsTable,
        exercisesTable,
      },
    );
  }

  List<RecoverySet> _toRecoverySets(List<QueryRow> rows) {
    return [
      for (final row in rows)
        RecoverySet(
          workoutId: row.read<String>('workout_id'),
          startedAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('started_at'),
          ),
          exerciseId: row.read<String>('exercise_id'),
          primaryMuscle: row.read<String>('primary_muscle'),
          secondaryMuscles: decodeMuscleList(
            row.read<String>('secondary_muscles'),
          ),
          category: ExerciseCategory.fromWire(row.read<String>('category')),
          setType: SetType.fromWire(row.read<String>('set_type')),
          isPrAttempt: row.read<int>('is_pr_attempt') == 1,
          effort: PerceivedEffort.fromWire(
            row.readNullable<String>('perceived_effort'),
          ),
          weightKg: row.readNullable<double>('weight_kg'),
          reps: row.readNullable<int>('reps'),
        ),
    ];
  }

  /// Records how heavy the session felt. Null clears the rating again.
  Future<void> setPerceivedEffort(
    String workoutId,
    PerceivedEffort? effort,
  ) async {
    await (update(workoutsTable)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsTableCompanion(perceivedEffort: Value(effort?.wire)),
    );
  }

  Future<void> renameWorkout(String workoutId, String name) async {
    await (update(workoutsTable)..where((t) => t.id.equals(workoutId)))
        .write(WorkoutsTableCompanion(name: Value(name)));
  }

  Future<void> setWorkoutNotes(String workoutId, String? notes) async {
    await (update(workoutsTable)..where((t) => t.id.equals(workoutId)))
        .write(WorkoutsTableCompanion(notes: Value(notes)));
  }

  // --- Sets -----------------------------------------------------------------

  Future<String> addSet(
    String workoutExerciseId, {
    SetType setType = SetType.normal,
    double? weightKg,
    int? reps,
    int? durationSeconds,
  }) async {
    final id = _uuid.v4();
    final max = workoutSetsTable.sortOrder.max();
    final row =
        await (selectOnly(workoutSetsTable)
              ..addColumns([max])
              ..where(
                workoutSetsTable.workoutExerciseId.equals(workoutExerciseId),
              ))
            .getSingle();
    await into(workoutSetsTable).insert(
      WorkoutSetsTableCompanion.insert(
        id: id,
        workoutExerciseId: workoutExerciseId,
        sortOrder: (row.read(max) ?? -1) + 1,
        setType: Value(setType.wire),
        weightKg: Value(weightKg),
        reps: Value(reps),
        durationSeconds: Value(durationSeconds),
      ),
    );
    return id;
  }

  /// Inserts warm-up sets in front of the existing sets of an exercise.
  Future<void> prependWarmupSets(
    String workoutExerciseId,
    List<({double weightKg, int reps})> warmups,
  ) async {
    await transaction(() async {
      final existing =
          await (select(workoutSetsTable)
                ..where((t) => t.workoutExerciseId.equals(workoutExerciseId))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();

      await batch((b) {
        for (var i = 0; i < existing.length; i++) {
          b.update(
            workoutSetsTable,
            WorkoutSetsTableCompanion(sortOrder: Value(warmups.length + i)),
            where: (t) => t.id.equals(existing[i].id),
          );
        }
        for (var i = 0; i < warmups.length; i++) {
          b.insert(
            workoutSetsTable,
            WorkoutSetsTableCompanion.insert(
              id: _uuid.v4(),
              workoutExerciseId: workoutExerciseId,
              sortOrder: i,
              setType: Value(SetType.warmup.wire),
              weightKg: Value(warmups[i].weightKg),
              reps: Value(warmups[i].reps),
            ),
          );
        }
      });
    });
  }

  Future<WorkoutSetRow?> getSet(String setId) => (select(
    workoutSetsTable,
  )..where((t) => t.id.equals(setId))).getSingleOrNull();

  Future<void> updateSet(
    String setId, {
    Value<double?> weightKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<double?> distanceM = const Value.absent(),
    Value<double?> rpe = const Value.absent(),
    Value<String> setType = const Value.absent(),
    Value<bool> isCompleted = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
  }) async {
    await (update(workoutSetsTable)..where((t) => t.id.equals(setId))).write(
      WorkoutSetsTableCompanion(
        weightKg: weightKg,
        reps: reps,
        durationSeconds: durationSeconds,
        distanceM: distanceM,
        rpe: rpe,
        setType: setType,
        isCompleted: isCompleted,
        completedAt: completedAt,
      ),
    );
  }

  Future<void> deleteSet(String setId) async {
    final row = await getSet(setId);
    if (row == null) return;
    await transaction(() async {
      await (delete(workoutSetsTable)..where((t) => t.id.equals(setId))).go();
      final remaining =
          await (select(workoutSetsTable)
                ..where(
                  (t) => t.workoutExerciseId.equals(row.workoutExerciseId),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      await batch((b) {
        for (var i = 0; i < remaining.length; i++) {
          b.update(
            workoutSetsTable,
            WorkoutSetsTableCompanion(sortOrder: Value(i)),
            where: (t) => t.id.equals(remaining[i].id),
          );
        }
      });
    });
  }

  // --- Previous performance -------------------------------------------------

  /// The **working** sets of the most recent finished workout that contained
  /// [exerciseId], in order. Used for the `VORIGE` column.
  ///
  /// Warm-ups are left out on purpose: last week's 40 kg warm-up must never
  /// show up as the thing to beat next to working set 1.
  Future<List<WorkoutSetRow>> previousSetsFor(
    String exerciseId, {
    String? excludingWorkoutId,
  }) async {
    final rows = await customSelect(
      'SELECT we.id AS we_id FROM workout_exercises we '
      'JOIN workouts w ON w.id = we.workout_id '
      'WHERE we.exercise_id = ? AND w.ended_at IS NOT NULL '
      'AND (? IS NULL OR w.id != ?) '
      'ORDER BY w.started_at DESC LIMIT 1',
      variables: [
        Variable.withString(exerciseId),
        Variable<String>(excludingWorkoutId),
        Variable<String>(excludingWorkoutId),
      ],
      readsFrom: {workoutExercisesTable, workoutsTable},
    ).get();
    if (rows.isEmpty) return const [];

    final weId = rows.first.read<String>('we_id');
    return (select(workoutSetsTable)
          ..where(
            (t) =>
                t.workoutExerciseId.equals(weId) &
                t.setType.equals(SetType.warmup.wire).not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// The note the user wrote the last time they did this exercise.
  Future<String?> previousNoteFor(
    String exerciseId, {
    String? excludingWorkoutId,
  }) async {
    final rows = await customSelect(
      'SELECT we.notes AS notes FROM workout_exercises we '
      'JOIN workouts w ON w.id = we.workout_id '
      "WHERE we.exercise_id = ? AND w.ended_at IS NOT NULL "
      "AND we.notes IS NOT NULL AND we.notes != '' "
      'AND (? IS NULL OR w.id != ?) '
      'ORDER BY w.started_at DESC LIMIT 1',
      variables: [
        Variable.withString(exerciseId),
        Variable<String>(excludingWorkoutId),
        Variable<String>(excludingWorkoutId),
      ],
      readsFrom: {workoutExercisesTable, workoutsTable},
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<String?>('notes');
  }

  // --- Finishing ------------------------------------------------------------

  /// Recomputes the denormalised totals of a workout from its sets.
  Future<void> recalculateTotals(String workoutId) async {
    final exercises = await _loadWorkoutExercises(workoutId);
    final allSets = exercises.expand((e) => e.sets).toList();
    final volume = workoutVolumeKg(
      allSets.map(
        (s) => SetVolumeInput(
          weightKg: s.weightKg,
          reps: s.reps,
          isCompleted: s.isCompleted,
          setType: SetType.fromWire(s.setType),
        ),
      ),
    );
    final completed = allSets.where((s) => s.isCompleted).length;

    await (update(workoutsTable)..where((t) => t.id.equals(workoutId))).write(
      WorkoutsTableCompanion(
        totalVolumeKg: Value(volume),
        totalSets: Value(completed),
      ),
    );
  }

  /// Ends the running session.
  ///
  /// [discardPending] removes every set that was never checked off; keeping
  /// them stores them as incomplete.
  Future<void> finishWorkout(
    String workoutId, {
    required bool discardPending,
    String? notes,
  }) async {
    await transaction(() async {
      if (discardPending) {
        await customStatement(
          'DELETE FROM workout_sets WHERE is_completed = 0 AND '
          'workout_exercise_id IN '
          '(SELECT id FROM workout_exercises WHERE workout_id = ?)',
          [workoutId],
        );
        // An exercise without any set left is noise in the history.
        await customStatement(
          'DELETE FROM workout_exercises WHERE workout_id = ? AND id NOT IN '
          '(SELECT DISTINCT workout_exercise_id FROM workout_sets)',
          [workoutId],
        );
      }

      final workout = await (select(
        workoutsTable,
      )..where((t) => t.id.equals(workoutId))).getSingle();
      final endedAt = DateTime.now().millisecondsSinceEpoch;

      await recalculateTotals(workoutId);
      await (update(workoutsTable)..where((t) => t.id.equals(workoutId))).write(
        WorkoutsTableCompanion(
          endedAt: Value(endedAt),
          durationSeconds: Value(
            ((endedAt - workout.startedAt) / 1000).round(),
          ),
          notes: notes == null ? const Value.absent() : Value(notes),
        ),
      );

      if (workout.routineId != null) {
        await (update(routinesTable)
              ..where((t) => t.id.equals(workout.routineId!)))
            .write(
              RoutinesTableCompanion(lastPerformedAt: Value(workout.startedAt)),
            );
      }
    });
  }

  /// Removes a workout and everything that hangs off it, in one transaction.
  ///
  /// Four things have to happen together, or the app is left inconsistent:
  /// the rows go (children follow by cascade), the records of the exercises
  /// that were in it are recomputed from what remains, the routine's
  /// `last_performed_at` falls back to the newest session that is left, and
  /// the caller learns whether it just deleted the running session.
  ///
  /// Returns what was removed so the UI can react.
  Future<DeletedWorkout> deleteWorkoutCompletely(String workoutId) async {
    return transaction(() async {
      final workout = await (select(
        workoutsTable,
      )..where((t) => t.id.equals(workoutId))).getSingleOrNull();
      if (workout == null) {
        return const DeletedWorkout(
          existed: false,
          wasRunning: false,
          exerciseIds: {},
        );
      }

      final exerciseRows = await (selectOnly(workoutExercisesTable)
            ..addColumns([workoutExercisesTable.exerciseId])
            ..where(workoutExercisesTable.workoutId.equals(workoutId)))
          .get();
      final exerciseIds = exerciseRows
          .map((row) => row.read(workoutExercisesTable.exerciseId)!)
          .toSet();

      await (delete(workoutsTable)..where((t) => t.id.equals(workoutId))).go();

      await db.recordsDao.rebuildRecordsFor(exerciseIds);

      if (workout.routineId != null) {
        await refreshLastPerformed(workout.routineId!);
      }

      return DeletedWorkout(
        existed: true,
        wasRunning: workout.endedAt == null,
        exerciseIds: exerciseIds,
      );
    });
  }

  /// Points a routine at the newest finished session it still has, or clears
  /// the stamp when none are left.
  Future<void> refreshLastPerformed(String routineId) async {
    await customStatement(
      'UPDATE routines SET last_performed_at = '
      '(SELECT MAX(started_at) FROM workouts '
      ' WHERE routine_id = ? AND ended_at IS NOT NULL) '
      'WHERE id = ?',
      [routineId, routineId],
    );
  }

  /// The plain row delete, without any of the bookkeeping.
  ///
  /// Only for callers that do their own cleanup afterwards.
  Future<void> deleteWorkout(String workoutId) async {
    await (delete(workoutsTable)..where((t) => t.id.equals(workoutId))).go();
  }

  // --- History --------------------------------------------------------------

  Stream<List<WorkoutSummary>> watchFinishedWorkouts({int? limit}) {
    final sql = StringBuffer(
      'SELECT w.*, '
      '(SELECT COUNT(*) FROM workout_exercises we WHERE we.workout_id = w.id) '
      'AS exercise_count, '
      '(SELECT COUNT(*) FROM personal_records pr '
      ' JOIN workout_sets ws ON ws.id = pr.workout_set_id '
      ' JOIN workout_exercises we2 ON we2.id = ws.workout_exercise_id '
      ' WHERE we2.workout_id = w.id) AS pr_count '
      'FROM workouts w WHERE w.ended_at IS NOT NULL '
      'ORDER BY w.started_at DESC',
    );
    if (limit != null) sql.write(' LIMIT $limit');

    return customSelect(
      sql.toString(),
      readsFrom: {
        workoutsTable,
        workoutExercisesTable,
        workoutSetsTable,
        personalRecordsTable,
      },
    ).watch().map(
      (rows) => rows
          .map(
            (r) => WorkoutSummary(
              workout: workoutsTable.map(r.data),
              exerciseCount: r.read<int>('exercise_count'),
              prCount: r.read<int>('pr_count'),
            ),
          )
          .toList(),
    );
  }

  /// Every finished workout that started inside [from] .. [to).
  Stream<List<WorkoutRow>> watchWorkoutsBetween(DateTime from, DateTime to) {
    return (select(workoutsTable)
          ..where(
            (t) =>
                t.endedAt.isNotNull() &
                t.startedAt.isBiggerOrEqualValue(
                  from.millisecondsSinceEpoch,
                ) &
                t.startedAt.isSmallerThanValue(to.millisecondsSinceEpoch),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .watch();
  }

  Future<List<WorkoutRow>> getFinishedWorkouts() =>
      (select(workoutsTable)
            ..where((t) => t.endedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// All sessions in which [exerciseId] was performed, newest first.
  Future<List<ExerciseSession>> exerciseSessions(
    String exerciseId, {
    int limit = 200,
  }) async {
    final joined =
        await (select(workoutExercisesTable)
                  ..where((t) => t.exerciseId.equals(exerciseId))
                  ..limit(limit))
                .join([
                  innerJoin(
                    workoutsTable,
                    workoutsTable.id.equalsExp(
                      workoutExercisesTable.workoutId,
                    ),
                  ),
                ])
                .get();

    final finished = joined
        .where((r) => r.readTable(workoutsTable).endedAt != null)
        .toList()
      ..sort(
        (a, b) => b
            .readTable(workoutsTable)
            .startedAt
            .compareTo(a.readTable(workoutsTable).startedAt),
      );
    if (finished.isEmpty) return const [];

    final ids = finished
        .map((r) => r.readTable(workoutExercisesTable).id)
        .toList();
    final sets =
        await (select(workoutSetsTable)
              ..where((t) => t.workoutExerciseId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    return finished.map((r) {
      final we = r.readTable(workoutExercisesTable);
      return ExerciseSession(
        workout: r.readTable(workoutsTable),
        workoutExercise: we,
        sets: sets
            .where((s) => s.workoutExerciseId == we.id)
            .toList(growable: false),
      );
    }).toList(growable: false);
  }

  // --- Aggregates -----------------------------------------------------------

  Future<WeekStats> statsBetween(DateTime from, DateTime to) async {
    final rows = await customSelect(
      'SELECT COUNT(*) AS workouts, '
      'COALESCE(SUM(total_sets), 0) AS sets, '
      'COALESCE(SUM(total_volume_kg), 0) AS volume, '
      'COALESCE(SUM(duration_seconds), 0) AS duration '
      'FROM workouts WHERE ended_at IS NOT NULL '
      'AND started_at >= ? AND started_at < ?',
      variables: [
        Variable.withInt(from.millisecondsSinceEpoch),
        Variable.withInt(to.millisecondsSinceEpoch),
      ],
      readsFrom: {workoutsTable},
    ).get();

    final r = rows.first;
    return WeekStats(
      workouts: r.read<int>('workouts'),
      sets: r.read<int>('sets'),
      volumeKg: r.read<double>('volume'),
      durationSeconds: r.read<int>('duration'),
    );
  }

  Stream<WeekStats> watchStatsBetween(DateTime from, DateTime to) {
    return customSelect(
      'SELECT COUNT(*) AS workouts, '
      'COALESCE(SUM(total_sets), 0) AS sets, '
      'COALESCE(SUM(total_volume_kg), 0) AS volume, '
      'COALESCE(SUM(duration_seconds), 0) AS duration '
      'FROM workouts WHERE ended_at IS NOT NULL '
      'AND started_at >= ? AND started_at < ?',
      variables: [
        Variable.withInt(from.millisecondsSinceEpoch),
        Variable.withInt(to.millisecondsSinceEpoch),
      ],
      readsFrom: {workoutsTable},
    ).watch().map((rows) {
      final r = rows.first;
      return WeekStats(
        workouts: r.read<int>('workouts'),
        sets: r.read<int>('sets'),
        volumeKg: r.read<double>('volume'),
        durationSeconds: r.read<int>('duration'),
      );
    });
  }

  Future<LifetimeStats> lifetimeStats() async {
    final rows = await customSelect(
      'SELECT COUNT(*) AS workouts, '
      'COALESCE(SUM(total_sets), 0) AS sets, '
      'COALESCE(SUM(total_volume_kg), 0) AS volume, '
      'COALESCE(SUM(duration_seconds), 0) AS duration '
      'FROM workouts WHERE ended_at IS NOT NULL',
      readsFrom: {workoutsTable},
    ).get();
    final r = rows.first;

    final weekday = await customSelect(
      // strftime('%w') gives 0 = Sunday .. 6 = Saturday.
      "SELECT CAST(strftime('%w', started_at / 1000, 'unixepoch', 'localtime') "
      'AS INTEGER) AS wd, COUNT(*) AS n FROM workouts '
      'WHERE ended_at IS NOT NULL GROUP BY wd ORDER BY n DESC LIMIT 1',
      readsFrom: {workoutsTable},
    ).get();

    int? busiest;
    if (weekday.isNotEmpty) {
      final wd = weekday.first.read<int>('wd');
      busiest = wd == 0 ? 7 : wd;
    }

    return LifetimeStats(
      workouts: r.read<int>('workouts'),
      sets: r.read<int>('sets'),
      volumeKg: r.read<double>('volume'),
      durationSeconds: r.read<int>('duration'),
      busiestWeekday: busiest,
    );
  }

  /// The start timestamps of every finished workout, oldest first. The streak
  /// calculation works on this list.
  Future<List<DateTime>> finishedWorkoutDates() async {
    final rows = await customSelect(
      'SELECT started_at FROM workouts WHERE ended_at IS NOT NULL '
      'ORDER BY started_at ASC',
      readsFrom: {workoutsTable},
    ).get();
    return rows
        .map(
          (r) => DateTime.fromMillisecondsSinceEpoch(r.read<int>('started_at')),
        )
        .toList();
  }

  Stream<List<DateTime>> watchFinishedWorkoutDates() {
    return customSelect(
      'SELECT started_at FROM workouts WHERE ended_at IS NOT NULL '
      'ORDER BY started_at ASC',
      readsFrom: {workoutsTable},
    ).watch().map(
      (rows) => rows
          .map(
            (r) =>
                DateTime.fromMillisecondsSinceEpoch(r.read<int>('started_at')),
          )
          .toList(),
    );
  }
}
