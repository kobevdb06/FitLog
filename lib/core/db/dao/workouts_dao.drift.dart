// dart format width=80
// ignore_for_file: type=lint
part of 'workouts_dao.dart';

mixin _$WorkoutsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $WorkoutsTableTable get workoutsTable => attachedDatabase.workoutsTable;
  $ExercisesTableTable get exercisesTable => attachedDatabase.exercisesTable;
  $WorkoutExercisesTableTable get workoutExercisesTable =>
      attachedDatabase.workoutExercisesTable;
  $WorkoutSetsTableTable get workoutSetsTable =>
      attachedDatabase.workoutSetsTable;
  $RoutineExercisesTableTable get routineExercisesTable =>
      attachedDatabase.routineExercisesTable;
  $RoutineSetsTableTable get routineSetsTable =>
      attachedDatabase.routineSetsTable;
  $PersonalRecordsTableTable get personalRecordsTable =>
      attachedDatabase.personalRecordsTable;
  WorkoutsDaoManager get managers => WorkoutsDaoManager(this);
}

class WorkoutsDaoManager {
  final _$WorkoutsDaoMixin _db;
  WorkoutsDaoManager(this._db);
  $$RoutineFoldersTableTableTableManager get routineFoldersTable =>
      $$RoutineFoldersTableTableTableManager(
        _db.attachedDatabase,
        _db.routineFoldersTable,
      );
  $$RoutinesTableTableTableManager get routinesTable =>
      $$RoutinesTableTableTableManager(_db.attachedDatabase, _db.routinesTable);
  $$WorkoutsTableTableTableManager get workoutsTable =>
      $$WorkoutsTableTableTableManager(_db.attachedDatabase, _db.workoutsTable);
  $$ExercisesTableTableTableManager get exercisesTable =>
      $$ExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.exercisesTable,
      );
  $$WorkoutExercisesTableTableTableManager get workoutExercisesTable =>
      $$WorkoutExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.workoutExercisesTable,
      );
  $$WorkoutSetsTableTableTableManager get workoutSetsTable =>
      $$WorkoutSetsTableTableTableManager(
        _db.attachedDatabase,
        _db.workoutSetsTable,
      );
  $$RoutineExercisesTableTableTableManager get routineExercisesTable =>
      $$RoutineExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.routineExercisesTable,
      );
  $$RoutineSetsTableTableTableManager get routineSetsTable =>
      $$RoutineSetsTableTableTableManager(
        _db.attachedDatabase,
        _db.routineSetsTable,
      );
  $$PersonalRecordsTableTableTableManager get personalRecordsTable =>
      $$PersonalRecordsTableTableTableManager(
        _db.attachedDatabase,
        _db.personalRecordsTable,
      );
}
