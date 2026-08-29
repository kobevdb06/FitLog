// dart format width=80
// ignore_for_file: type=lint
part of 'records_dao.dart';

mixin _$RecordsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExercisesTableTable get exercisesTable => attachedDatabase.exercisesTable;
  $PersonalRecordsTableTable get personalRecordsTable =>
      attachedDatabase.personalRecordsTable;
  $BodyMeasurementsTableTable get bodyMeasurementsTable =>
      attachedDatabase.bodyMeasurementsTable;
  $ProgressPhotosTableTable get progressPhotosTable =>
      attachedDatabase.progressPhotosTable;
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $WorkoutsTableTable get workoutsTable => attachedDatabase.workoutsTable;
  $WorkoutExercisesTableTable get workoutExercisesTable =>
      attachedDatabase.workoutExercisesTable;
  $WorkoutSetsTableTable get workoutSetsTable =>
      attachedDatabase.workoutSetsTable;
  RecordsDaoManager get managers => RecordsDaoManager(this);
}

class RecordsDaoManager {
  final _$RecordsDaoMixin _db;
  RecordsDaoManager(this._db);
  $$ExercisesTableTableTableManager get exercisesTable =>
      $$ExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.exercisesTable,
      );
  $$PersonalRecordsTableTableTableManager get personalRecordsTable =>
      $$PersonalRecordsTableTableTableManager(
        _db.attachedDatabase,
        _db.personalRecordsTable,
      );
  $$BodyMeasurementsTableTableTableManager get bodyMeasurementsTable =>
      $$BodyMeasurementsTableTableTableManager(
        _db.attachedDatabase,
        _db.bodyMeasurementsTable,
      );
  $$ProgressPhotosTableTableTableManager get progressPhotosTable =>
      $$ProgressPhotosTableTableTableManager(
        _db.attachedDatabase,
        _db.progressPhotosTable,
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
  $$WorkoutSetsTableTableTableManager get workoutSetsTable =>
      $$WorkoutSetsTableTableTableManager(
        _db.attachedDatabase,
        _db.workoutSetsTable,
      );
}
