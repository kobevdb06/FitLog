import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../calc/schedule.dart';
import '../database.dart';
import '../models.dart';

part 'routines_dao.drift.dart';

const _uuid = Uuid();

/// The shape the routine editor hands back when it saves.
class RoutineDraft {
  const RoutineDraft({
    required this.name,
    this.notes,
    this.folderId,
    this.colorIndex,
    required this.exercises,
  });

  final String name;
  final String? notes;
  final String? folderId;

  /// A position in `AppColors.routinePalette`, or null for no colour.
  final int? colorIndex;
  final List<RoutineExerciseDraft> exercises;
}

class RoutineExerciseDraft {
  const RoutineExerciseDraft({
    required this.exerciseId,
    this.restSeconds,
    this.supersetGroup,
    this.notes,
    required this.sets,
  });

  final String exerciseId;
  final int? restSeconds;
  final int? supersetGroup;
  final String? notes;
  final List<RoutineSetDraft> sets;
}

class RoutineSetDraft {
  const RoutineSetDraft({
    this.setType = SetType.normal,
    this.targetReps,
    this.targetWeightKg,
    this.targetDurationSeconds,
    this.targetDistanceM,
  });

  final SetType setType;
  final int? targetReps;
  final double? targetWeightKg;
  final int? targetDurationSeconds;
  final double? targetDistanceM;
}

@DriftAccessor(
  tables: [
    RoutineFoldersTable,
    RoutinesTable,
    RoutineExercisesTable,
    RoutineSetsTable,
    ExercisesTable,
    WorkoutsTable,
  ],
)
class RoutinesDao extends DatabaseAccessor<AppDatabase>
    with _$RoutinesDaoMixin {
  RoutinesDao(super.db);

  // --- Folders --------------------------------------------------------------

  Stream<List<RoutineFolderRow>> watchFolders() => (select(
    routineFoldersTable,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Future<List<RoutineFolderRow>> getFolders() => (select(
    routineFoldersTable,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Future<String> createFolder(String name) async {
    final id = _uuid.v4();
    final max = routineFoldersTable.sortOrder.max();
    final row = await (selectOnly(
      routineFoldersTable,
    )..addColumns([max])).getSingle();
    await into(routineFoldersTable).insert(
      RoutineFoldersTableCompanion.insert(
        id: id,
        name: name,
        sortOrder: (row.read(max) ?? -1) + 1,
      ),
    );
    return id;
  }

  Future<void> renameFolder(String id, String name) async {
    await (update(routineFoldersTable)..where((t) => t.id.equals(id))).write(
      RoutineFoldersTableCompanion(name: Value(name)),
    );
  }

  /// Deleting a folder does not delete its routines: the foreign key is
  /// `ON DELETE SET NULL`, so they move to the top level.
  Future<void> deleteFolder(String id) async {
    await (delete(routineFoldersTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorderFolders(List<String> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          routineFoldersTable,
          RoutineFoldersTableCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // --- Routines -------------------------------------------------------------

  Stream<List<RoutineSummary>> watchRoutines() {
    final query = customSelect(
      'SELECT r.*, '
      '(SELECT COUNT(*) FROM routine_exercises re WHERE re.routine_id = r.id) '
      'AS exercise_count, '
      '(SELECT COUNT(*) FROM routine_sets rs '
      ' JOIN routine_exercises re2 ON re2.id = rs.routine_exercise_id '
      ' WHERE re2.routine_id = r.id) AS set_count '
      'FROM routines r ORDER BY r.sort_order ASC',
      readsFrom: {routinesTable, routineExercisesTable, routineSetsTable},
    );
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => RoutineSummary(
              routine: routinesTable.map(r.data),
              exerciseCount: r.read<int>('exercise_count'),
              setCount: r.read<int>('set_count'),
            ),
          )
          .toList(),
    );
  }

  Future<RoutineRow?> getRoutine(String id) =>
      (select(routinesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<RoutineDetail?> watchRoutineDetail(String routineId) {
    final routine = (select(
      routinesTable,
    )..where((t) => t.id.equals(routineId))).watchSingleOrNull();
    return routine.asyncMap((r) async {
      if (r == null) return null;
      return RoutineDetail(
        routine: r,
        exercises: await _loadRoutineExercises(routineId),
      );
    });
  }

  Future<RoutineDetail?> getRoutineDetail(String routineId) async {
    final routine = await getRoutine(routineId);
    if (routine == null) return null;
    return RoutineDetail(
      routine: routine,
      exercises: await _loadRoutineExercises(routineId),
    );
  }

  Future<List<RoutineExerciseDetail>> _loadRoutineExercises(
    String routineId,
  ) async {
    final joined =
        await (select(routineExercisesTable)
              ..where((t) => t.routineId.equals(routineId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .join([
              innerJoin(
                exercisesTable,
                exercisesTable.id.equalsExp(routineExercisesTable.exerciseId),
              ),
            ])
            .get();

    if (joined.isEmpty) return const [];

    final ids = joined
        .map((r) => r.readTable(routineExercisesTable).id)
        .toList();
    final allSets =
        await (select(routineSetsTable)
              ..where((t) => t.routineExerciseId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    return joined
        .map((row) {
          final re = row.readTable(routineExercisesTable);
          return RoutineExerciseDetail(
            routineExercise: re,
            exercise: row.readTable(exercisesTable),
            sets: allSets
                .where((s) => s.routineExerciseId == re.id)
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  /// Creates a routine and everything under it in one transaction.
  Future<String> createRoutine(RoutineDraft draft) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      final max = routinesTable.sortOrder.max();
      final row = await (selectOnly(
        routinesTable,
      )..addColumns([max])).getSingle();
      await into(routinesTable).insert(
        RoutinesTableCompanion.insert(
          id: id,
          name: draft.name,
          notes: Value(draft.notes),
          folderId: Value(draft.folderId),
          colorIndex: Value(draft.colorIndex),
          sortOrder: (row.read(max) ?? -1) + 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _writeRoutineExercises(id, draft.exercises);
    });
    return id;
  }

  /// Replaces the full content of a routine. The editor always saves the whole
  /// routine, which keeps sort orders and superset groups consistent.
  Future<void> updateRoutine(String routineId, RoutineDraft draft) async {
    await transaction(() async {
      await (update(routinesTable)..where((t) => t.id.equals(routineId))).write(
        RoutinesTableCompanion(
          name: Value(draft.name),
          notes: Value(draft.notes),
          folderId: Value(draft.folderId),
          colorIndex: Value(draft.colorIndex),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      // Cascades to routine_sets.
      await (delete(
        routineExercisesTable,
      )..where((t) => t.routineId.equals(routineId))).go();
      await _writeRoutineExercises(routineId, draft.exercises);
    });
  }

  Future<void> _writeRoutineExercises(
    String routineId,
    List<RoutineExerciseDraft> exercises,
  ) async {
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      final reId = _uuid.v4();
      await into(routineExercisesTable).insert(
        RoutineExercisesTableCompanion.insert(
          id: reId,
          routineId: routineId,
          exerciseId: e.exerciseId,
          sortOrder: i,
          restSeconds: Value(e.restSeconds),
          supersetGroup: Value(e.supersetGroup),
          notes: Value(e.notes),
        ),
      );
      await batch((b) {
        for (var j = 0; j < e.sets.length; j++) {
          final s = e.sets[j];
          b.insert(
            routineSetsTable,
            RoutineSetsTableCompanion.insert(
              id: _uuid.v4(),
              routineExerciseId: reId,
              sortOrder: j,
              setType: Value(s.setType.wire),
              targetReps: Value(s.targetReps),
              targetWeightKg: Value(s.targetWeightKg),
              targetDurationSeconds: Value(s.targetDurationSeconds),
              targetDistanceM: Value(s.targetDistanceM),
            ),
          );
        }
      });
    }
  }

  Future<void> setRoutineFolder(String routineId, String? folderId) async {
    await (update(routinesTable)..where((t) => t.id.equals(routineId))).write(
      RoutinesTableCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteRoutine(String routineId) async {
    await (delete(routinesTable)..where((t) => t.id.equals(routineId))).go();
  }

  Future<String> duplicateRoutine(String routineId) async {
    final detail = await getRoutineDetail(routineId);
    if (detail == null) {
      throw StateError('Routine $routineId bestaat niet');
    }
    return createRoutine(
      RoutineDraft(
        name: '${detail.routine.name} (kopie)',
        notes: detail.routine.notes,
        folderId: detail.routine.folderId,
        exercises: detail.exercises
            .map(
              (e) => RoutineExerciseDraft(
                exerciseId: e.exercise.id,
                restSeconds: e.routineExercise.restSeconds,
                supersetGroup: e.routineExercise.supersetGroup,
                notes: e.routineExercise.notes,
                sets: e.sets
                    .map(
                      (s) => RoutineSetDraft(
                        setType: SetType.fromWire(s.setType),
                        targetReps: s.targetReps,
                        targetWeightKg: s.targetWeightKg,
                        targetDurationSeconds: s.targetDurationSeconds,
                        targetDistanceM: s.targetDistanceM,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> reorderRoutines(List<String> orderedIds) async {
    await batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          routinesTable,
          RoutinesTableCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<void> markPerformed(String routineId, int at) async {
    await (update(routinesTable)..where((t) => t.id.equals(routineId))).write(
      RoutinesTableCompanion(lastPerformedAt: Value(at)),
    );
  }

  /// Stars a routine, or takes the star away.
  Future<void> setFavourite(String routineId, {required bool favourite}) async {
    await (update(routinesTable)..where((t) => t.id.equals(routineId))).write(
      RoutinesTableCompanion(isFavourite: Value(favourite)),
    );
  }

  /// Plans a routine on a set of weekdays, or on none at all.
  ///
  /// Its own write rather than a field on [RoutineDraft], so that editing the
  /// exercises in a routine cannot quietly unplan it and so that a routine
  /// shared over QR arrives without a schedule attached.
  Future<void> setScheduledDays(String routineId, WeekdaySet days) async {
    await (update(routinesTable)..where((t) => t.id.equals(routineId))).write(
      RoutinesTableCompanion(scheduledDays: Value(days.mask)),
    );
  }

  /// Every routine that is planned on at least one day, in your own order.
  ///
  /// Which day is which is decided by the caller: the whole week is a handful
  /// of rows, and reading them all keeps "what is on tomorrow" a question the
  /// dashboard can answer without going back to the database.
  Stream<List<RoutineRow>> watchScheduledRoutines() =>
      (select(routinesTable)
            ..where((t) => t.scheduledDays.isBiggerThanValue(0))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  /// The starred routines, the ones you do most often first.
  ///
  /// You may star as many as you like, but the launcher only has room for a
  /// few, so they are ranked by how many sessions you have actually started
  /// from each - the honest measure of "my usual workout", and one the app
  /// already has without asking. Ties go to the one done most recently, and
  /// then to the order you put them in yourself.
  Future<List<RoutineRow>> favouritesByUse({int limit = 3}) async {
    final rows = await customSelect(
      'SELECT r.id AS id, COUNT(w.id) AS uses '
      'FROM routines r '
      'LEFT JOIN workouts w ON w.routine_id = r.id AND w.ended_at IS NOT NULL '
      'WHERE r.is_favourite = 1 '
      'GROUP BY r.id '
      'ORDER BY uses DESC, r.last_performed_at DESC, r.sort_order ASC '
      'LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {routinesTable, workoutsTable},
    ).get();
    if (rows.isEmpty) return const [];

    final ids = [for (final r in rows) r.read<String>('id')];
    final found = await (select(
      routinesTable,
    )..where((t) => t.id.isIn(ids))).get();
    // The IN query comes back in whatever order sqlite likes; the ranking is
    // the point, so put them back the way they were asked for.
    final byId = {for (final r in found) r.id: r};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// The same ranking, kept up to date.
  ///
  /// Watched rather than read once because both halves move on their own: you
  /// star a routine, and every finished session changes the order underneath.
  Stream<List<RoutineRow>> watchFavouritesByUse({int limit = 3}) {
    return customSelect(
      'SELECT COUNT(*) AS n FROM routines WHERE is_favourite = 1',
      readsFrom: {routinesTable, workoutsTable},
    ).watch().asyncMap((_) => favouritesByUse(limit: limit));
  }

  /// The routine to suggest on the dashboard: the one that has not been done
  /// for the longest time, falling back to the first routine in the list.
  Future<RoutineRow?> suggestedRoutine() async {
    final never =
        await (select(routinesTable)
              ..where((t) => t.lastPerformedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    if (never != null) return never;
    return (select(routinesTable)
          ..orderBy([(t) => OrderingTerm.asc(t.lastPerformedAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}
