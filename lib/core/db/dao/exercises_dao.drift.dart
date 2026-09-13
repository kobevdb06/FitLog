// dart format width=80
// ignore_for_file: type=lint
part of 'exercises_dao.dart';

mixin _$ExercisesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExercisesTableTable get exercisesTable => attachedDatabase.exercisesTable;
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $WorkoutsTableTable get workoutsTable => attachedDatabase.workoutsTable;
  $WorkoutExercisesTableTable get workoutExercisesTable =>
      attachedDatabase.workoutExercisesTable;
  $CustomMusclesTableTable get customMusclesTable =>
      attachedDatabase.customMusclesTable;
  $CustomEquipmentTableTable get customEquipmentTable =>
      attachedDatabase.customEquipmentTable;
  $CustomCategoriesTableTable get customCategoriesTable =>
      attachedDatabase.customCategoriesTable;
  ExercisesDaoManager get managers => ExercisesDaoManager(this);
}

class ExercisesDaoManager {
  final _$ExercisesDaoMixin _db;
  ExercisesDaoManager(this._db);
  $$ExercisesTableTableTableManager get exercisesTable =>
      $$ExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.exercisesTable,
      );
  $$RoutineFoldersTableTableTableManager get routineFoldersTable =>
      $$RoutineFoldersTableTableTableManager(
        _db.attachedDatabase,
        _db.routineFoldersTable,
      );
  $$RoutinesTableTableTableManager get routinesTable =>
      $$RoutinesTableTableTableManager(_db.attachedDatabase, _db.routinesTable);
  $$WorkoutsTableTableTableManager get workoutsTable =>
      $$WorkoutsTableTableTableManager(_db.attachedDatabase, _db.workoutsTable);
  $$WorkoutExercisesTableTableTableManager get workoutExercisesTable =>
      $$WorkoutExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.workoutExercisesTable,
      );
  $$CustomMusclesTableTableTableManager get customMusclesTable =>
      $$CustomMusclesTableTableTableManager(
        _db.attachedDatabase,
        _db.customMusclesTable,
      );
  $$CustomEquipmentTableTableTableManager get customEquipmentTable =>
      $$CustomEquipmentTableTableTableManager(
        _db.attachedDatabase,
        _db.customEquipmentTable,
      );
  $$CustomCategoriesTableTableTableManager get customCategoriesTable =>
      $$CustomCategoriesTableTableTableManager(
        _db.attachedDatabase,
        _db.customCategoriesTable,
      );
}
