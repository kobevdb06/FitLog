import 'package:drift/drift.dart';

import '../database.dart';

part 'exercises_dao.drift.dart';

/// A set of filters for the exercise picker.
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.muscles = const {},
    this.equipment = const {},
    this.categories = const {},
    this.customOnly = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<String> muscles;
  final Set<String> equipment;
  final Set<String> categories;
  final bool customOnly;
  final bool includeArchived;

  bool get isEmpty =>
      query.trim().isEmpty &&
      muscles.isEmpty &&
      equipment.isEmpty &&
      categories.isEmpty &&
      !customOnly;

  ExerciseFilter copyWith({
    String? query,
    Set<String>? muscles,
    Set<String>? equipment,
    Set<String>? categories,
    bool? customOnly,
    bool? includeArchived,
  }) {
    return ExerciseFilter(
      query: query ?? this.query,
      muscles: muscles ?? this.muscles,
      equipment: equipment ?? this.equipment,
      categories: categories ?? this.categories,
      customOnly: customOnly ?? this.customOnly,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}

@DriftAccessor(
  tables: [ExercisesTable, WorkoutExercisesTable, WorkoutsTable],
)
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  Stream<List<ExerciseRow>> watchExercises([
    ExerciseFilter filter = const ExerciseFilter(),
  ]) {
    return _filtered(filter).watch();
  }

  Future<List<ExerciseRow>> getExercises([
    ExerciseFilter filter = const ExerciseFilter(),
  ]) {
    return _filtered(filter).get();
  }

  SimpleSelectStatement<$ExercisesTableTable, ExerciseRow> _filtered(
    ExerciseFilter filter,
  ) {
    final q = select(exercisesTable);

    if (!filter.includeArchived) {
      q.where((t) => t.isArchived.equals(false));
    }
    final term = filter.query.trim();
    if (term.isNotEmpty) {
      final pattern = '%${term.replaceAll('%', r'\%')}%';
      q.where((t) => t.name.like(pattern));
    }
    if (filter.muscles.isNotEmpty) {
      // The primary muscle is the one people filter on; secondary muscles are
      // stored as a JSON array and matched textually.
      q.where(
        (t) =>
            t.primaryMuscle.isIn(filter.muscles) |
            filter.muscles
                .map((m) => t.secondaryMuscles.like('%"$m"%'))
                .reduce((a, b) => a | b),
      );
    }
    if (filter.equipment.isNotEmpty) {
      q.where((t) => t.equipment.isIn(filter.equipment));
    }
    if (filter.categories.isNotEmpty) {
      q.where((t) => t.category.isIn(filter.categories));
    }
    if (filter.customOnly) {
      q.where((t) => t.isCustom.equals(true));
    }

    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q;
  }

  Future<ExerciseRow?> getById(String id) => (select(
    exercisesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<ExerciseRow?> watchById(String id) => (select(
    exercisesTable,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<List<ExerciseRow>> getByIds(Iterable<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(exercisesTable)..where((t) => t.id.isIn(ids))).get();
  }

  Future<int> countExercises() async {
    final count = exercisesTable.id.count();
    final row = await (selectOnly(exercisesTable)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Distinct values present in the catalogue, used to build the filter chips.
  Future<List<String>> distinctPrimaryMuscles() async {
    final rows = await customSelect(
      'SELECT DISTINCT primary_muscle AS m FROM exercises '
      'WHERE is_archived = 0 ORDER BY m',
      readsFrom: {exercisesTable},
    ).get();
    return rows.map((r) => r.read<String>('m')).toList();
  }

  Future<List<String>> distinctEquipment() async {
    final rows = await customSelect(
      'SELECT DISTINCT equipment AS e FROM exercises '
      'WHERE is_archived = 0 AND equipment IS NOT NULL ORDER BY e',
      readsFrom: {exercisesTable},
    ).get();
    return rows.map((r) => r.read<String>('e')).toList();
  }

  /// The exercises used most recently, newest first.
  Future<List<String>> recentExerciseIds({int limit = 12}) async {
    final rows = await customSelect(
      'SELECT we.exercise_id AS id, MAX(w.started_at) AS last_used '
      'FROM workout_exercises we '
      'JOIN workouts w ON w.id = we.workout_id '
      'GROUP BY we.exercise_id ORDER BY last_used DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {workoutExercisesTable, workoutsTable},
    ).get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  /// Every frame file a user-made exercise points at.
  ///
  /// The startup reconcile needs these: the frames live in the same directory
  /// as the progress photos, so without them they look like orphans and get
  /// deleted.
  Future<Set<String>> imageFileNames() async {
    final query = selectOnly(exercisesTable)
      ..addColumns([exercisesTable.startImageFile, exercisesTable.endImageFile])
      ..where(
        exercisesTable.startImageFile.isNotNull() |
            exercisesTable.endImageFile.isNotNull(),
      );
    final rows = await query.get();
    return {
      for (final row in rows) ...[
        row.read(exercisesTable.startImageFile),
        row.read(exercisesTable.endImageFile),
      ],
    }.whereType<String>().toSet();
  }

  /// Clears one frame that no longer has a file behind it.
  Future<void> clearImageFile(String fileName) async {
    await (update(exercisesTable)
          ..where((t) => t.startImageFile.equals(fileName)))
        .write(const ExercisesTableCompanion(startImageFile: Value(null)));
    await (update(exercisesTable)..where((t) => t.endImageFile.equals(fileName)))
        .write(const ExercisesTableCompanion(endImageFile: Value(null)));
  }

  Future<void> insertExercise(ExercisesTableCompanion exercise) =>
      into(exercisesTable).insert(exercise);

  /// Inserts the whole bundled catalogue in one transaction.
  Future<void> insertSeed(List<ExercisesTableCompanion> exercises) async {
    await batch((b) => b.insertAll(exercisesTable, exercises));
  }

  Future<void> updateExercise(
    String id,
    ExercisesTableCompanion changes,
  ) async {
    await (update(exercisesTable)..where((t) => t.id.equals(id)))
        .write(changes);
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    await (update(exercisesTable)..where((t) => t.id.equals(id)))
        .write(ExercisesTableCompanion(isArchived: Value(archived)));
  }

  /// Only ever used for exercises the user created that were never logged.
  Future<int> deleteExercise(String id) =>
      (delete(exercisesTable)..where((t) => t.id.equals(id))).go();

  Future<int> timesUsed(String exerciseId) async {
    final count = workoutExercisesTable.id.count();
    final row =
        await (selectOnly(workoutExercisesTable)
              ..addColumns([count])
              ..where(workoutExercisesTable.exerciseId.equals(exerciseId)))
            .getSingle();
    return row.read(count) ?? 0;
  }
}
