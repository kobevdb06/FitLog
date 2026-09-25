import 'package:drift/drift.dart';

import '../database.dart';
import '../models.dart';

part 'exercises_dao.drift.dart';

/// A set of filters for the exercise picker.
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.muscles = const {},
    this.equipment = const {},
    this.categories = const {},
    this.customCategories = const {},
    this.customOnly = false,
    this.favouritesOnly = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<String> muscles;
  final Set<String> equipment;
  final Set<String> categories;

  /// Categories the user named themselves, matched on the exercise's own
  /// label rather than on the built-in category underneath it.
  final Set<String> customCategories;
  final bool customOnly;

  /// Only the exercises you starred.
  final bool favouritesOnly;
  final bool includeArchived;

  bool get isEmpty =>
      query.trim().isEmpty &&
      muscles.isEmpty &&
      equipment.isEmpty &&
      categories.isEmpty &&
      customCategories.isEmpty &&
      !customOnly &&
      !favouritesOnly;

  ExerciseFilter copyWith({
    String? query,
    Set<String>? muscles,
    Set<String>? equipment,
    Set<String>? categories,
    Set<String>? customCategories,
    bool? customOnly,
    bool? favouritesOnly,
    bool? includeArchived,
  }) {
    return ExerciseFilter(
      query: query ?? this.query,
      muscles: muscles ?? this.muscles,
      equipment: equipment ?? this.equipment,
      categories: categories ?? this.categories,
      customCategories: customCategories ?? this.customCategories,
      customOnly: customOnly ?? this.customOnly,
      favouritesOnly: favouritesOnly ?? this.favouritesOnly,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}

@DriftAccessor(
  tables: [
    ExercisesTable,
    WorkoutExercisesTable,
    WorkoutsTable,
    CustomMusclesTable,
    CustomEquipmentTable,
    CustomCategoriesTable,
  ],
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

      // Looking for the kit is looking for the exercise: "barbell" should
      // bring up everything you do with one, not only what happens to carry
      // the word in its name. The equipment is stored in Dutch and the type in
      // English, so the term is tried against the stored equipment, the stored
      // type, and the Dutch label the filter chips show for that type.
      final lower = term.toLowerCase();
      final categories = ExerciseCategory.values
          .where(
            (c) =>
                c.wire.contains(lower) || c.label.toLowerCase().contains(lower),
          )
          .map((c) => c.wire)
          .toSet();

      q.where((t) {
        final matches =
            t.name.like(pattern) |
            t.equipment.like(pattern) |
            t.customCategory.like(pattern);
        return categories.isEmpty
            ? matches
            : matches | t.category.isIn(categories);
      });
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
    if (filter.customCategories.isNotEmpty) {
      q.where((t) => t.customCategory.isIn(filter.customCategories));
    }
    if (filter.customOnly) {
      q.where((t) => t.isCustom.equals(true));
    }
    if (filter.favouritesOnly) {
      q.where((t) => t.isFavourite.equals(true));
    }

    q.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q;
  }

  Future<ExerciseRow?> getById(String id) =>
      (select(exercisesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<ExerciseRow?> watchById(String id) => (select(
    exercisesTable,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<List<ExerciseRow>> getByIds(Iterable<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(exercisesTable)..where((t) => t.id.isIn(ids))).get();
  }

  Future<int> countExercises() async {
    final count = exercisesTable.id.count();
    final row = await (selectOnly(
      exercisesTable,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Distinct values present in the catalogue, used to build the filter chips.
  /// Every muscle group you can pick: the ones the catalogue uses plus the
  /// ones you added yourself.
  ///
  /// The union, not one or the other. A group you added stays on the list
  /// before any exercise uses it and after the last one stops; a group the
  /// catalogue uses is there whether or not you ever wrote it down.
  Future<List<String>> distinctPrimaryMuscles() async {
    final rows = await customSelect(
      'SELECT m FROM ('
      '  SELECT DISTINCT primary_muscle AS m FROM exercises '
      '  WHERE is_archived = 0'
      '  UNION SELECT name AS m FROM custom_muscles'
      ') ORDER BY m',
      readsFrom: {exercisesTable, customMusclesTable},
    ).get();
    return rows.map((r) => r.read<String>('m')).toList();
  }

  /// The same for kit.
  Future<List<String>> distinctEquipment() async {
    final rows = await customSelect(
      'SELECT e FROM ('
      '  SELECT DISTINCT equipment AS e FROM exercises '
      '  WHERE is_archived = 0 AND equipment IS NOT NULL'
      '  UNION SELECT name AS e FROM custom_equipment'
      ') ORDER BY e',
      readsFrom: {exercisesTable, customEquipmentTable},
    ).get();
    return rows.map((r) => r.read<String>('e')).toList();
  }

  Stream<List<String>> watchPrimaryMuscles() => customSelect(
    'SELECT m FROM ('
    '  SELECT DISTINCT primary_muscle AS m FROM exercises '
    '  WHERE is_archived = 0'
    '  UNION SELECT name AS m FROM custom_muscles'
    ') ORDER BY m',
    readsFrom: {exercisesTable, customMusclesTable},
  ).watch().map((rows) => [for (final r in rows) r.read<String>('m')]);

  Stream<List<String>> watchEquipment() => customSelect(
    'SELECT e FROM ('
    '  SELECT DISTINCT equipment AS e FROM exercises '
    '  WHERE is_archived = 0 AND equipment IS NOT NULL'
    '  UNION SELECT name AS e FROM custom_equipment'
    ') ORDER BY e',
    readsFrom: {exercisesTable, customEquipmentTable},
  ).watch().map((rows) => [for (final r in rows) r.read<String>('e')]);

  /// Adds a muscle group of your own. Lower case, because that is the key the
  /// colours, the recovery estimate and every exercise row join on.
  Future<void> addCustomMuscle(String name) async {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    await into(customMusclesTable).insertOnConflictUpdate(
      CustomMusclesTableCompanion.insert(
        name: trimmed,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> addCustomEquipment(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await into(customEquipmentTable).insertOnConflictUpdate(
      CustomEquipmentTableCompanion.insert(
        name: trimmed,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// A category of the user's own, and the built-in one it counts as.
  Future<void> addCustomCategory(String name, String base) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await into(customCategoriesTable).insertOnConflictUpdate(
      CustomCategoriesTableCompanion.insert(
        name: trimmed,
        base: base,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> removeCustomCategory(String name) async {
    await (delete(
      customCategoriesTable,
    )..where((t) => t.name.equals(name))).go();
  }

  Future<void> removeCustomMuscle(String name) async {
    await (delete(customMusclesTable)..where((t) => t.name.equals(name))).go();
  }

  Future<void> removeCustomEquipment(String name) async {
    await (delete(
      customEquipmentTable,
    )..where((t) => t.name.equals(name))).go();
  }

  /// Which of your own entries are still only yours, and which the catalogue
  /// has since taken over.
  Stream<List<CustomMuscleRow>> watchCustomMuscles() => (select(
    customMusclesTable,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<CustomEquipmentRow>> watchCustomEquipment() => (select(
    customEquipmentTable,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<CustomCategoryRow>> watchCustomCategories() => (select(
    customCategoriesTable,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<CustomCategoryRow>> customCategories() => (select(
    customCategoriesTable,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  /// How many exercises use a muscle group, primary or secondary.
  ///
  /// Removing one that is in use would leave those exercises pointing at a
  /// name nothing else knows.
  Future<int> exercisesUsingMuscle(String name) async {
    final rows = await customSelect(
      'SELECT COUNT(*) AS n FROM exercises '
      'WHERE is_archived = 0 AND (primary_muscle = ? '
      "OR secondary_muscles LIKE '%\"' || ? || '\"%')",
      variables: [Variable.withString(name), Variable.withString(name)],
      readsFrom: {exercisesTable},
    ).getSingle();
    return rows.read<int>('n');
  }

  Future<int> exercisesUsingEquipment(String name) async {
    final rows = await customSelect(
      'SELECT COUNT(*) AS n FROM exercises '
      'WHERE is_archived = 0 AND equipment = ?',
      variables: [Variable.withString(name)],
      readsFrom: {exercisesTable},
    ).getSingle();
    return rows.read<int>('n');
  }

  Future<int> exercisesUsingCategory(String name) async {
    final rows = await customSelect(
      'SELECT COUNT(*) AS n FROM exercises '
      'WHERE is_archived = 0 AND custom_category = ?',
      variables: [Variable.withString(name)],
      readsFrom: {exercisesTable},
    ).getSingle();
    return rows.read<int>('n');
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
    await (update(exercisesTable)
          ..where((t) => t.endImageFile.equals(fileName)))
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
    await (update(
      exercisesTable,
    )..where((t) => t.id.equals(id))).write(changes);
  }

  /// Changes how an exercise is done, and remembers that you said so.
  ///
  /// Also for exercises from the catalogue, which is the point: when the
  /// bundled type is wrong there is no other way to put it right, and waiting
  /// for a new version of the app is not one. The mark keeps a later catalogue
  /// correction from quietly undoing the choice.
  Future<void> setCategory(String id, CategoryChoice category) async {
    await (update(exercisesTable)..where((t) => t.id.equals(id))).write(
      ExercisesTableCompanion(
        category: Value(category.base.wire),
        customCategory: Value(category.name),
        categoryOverridden: const Value(true),
      ),
    );
  }

  Future<void> setFavourite(String id, {required bool favourite}) async {
    await (update(exercisesTable)..where((t) => t.id.equals(id))).write(
      ExercisesTableCompanion(isFavourite: Value(favourite)),
    );
  }

  /// Whether any exercise that is still in use carries a star.
  ///
  /// What decides whether the filter for them is worth a place: a chip that
  /// can only ever show an empty list is clutter.
  Stream<bool> watchHasFavourites() {
    final count = exercisesTable.id.count();
    return (selectOnly(exercisesTable)
          ..addColumns([count])
          ..where(
            exercisesTable.isFavourite.equals(true) &
                exercisesTable.isArchived.equals(false),
          ))
        .watchSingle()
        .map((row) => (row.read(count) ?? 0) > 0);
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    await (update(exercisesTable)..where((t) => t.id.equals(id))).write(
      ExercisesTableCompanion(isArchived: Value(archived)),
    );
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
