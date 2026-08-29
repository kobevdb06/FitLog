// dart format width=80
// ignore_for_file: type=lint
part of 'routines_dao.dart';

mixin _$RoutinesDaoMixin on DatabaseAccessor<AppDatabase> {
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $ExercisesTableTable get exercisesTable => attachedDatabase.exercisesTable;
  $RoutineExercisesTableTable get routineExercisesTable =>
      attachedDatabase.routineExercisesTable;
  $RoutineSetsTableTable get routineSetsTable =>
      attachedDatabase.routineSetsTable;
  RoutinesDaoManager get managers => RoutinesDaoManager(this);
}

class RoutinesDaoManager {
  final _$RoutinesDaoMixin _db;
  RoutinesDaoManager(this._db);
  $$RoutineFoldersTableTableTableManager get routineFoldersTable =>
      $$RoutineFoldersTableTableTableManager(
        _db.attachedDatabase,
        _db.routineFoldersTable,
      );
  $$RoutinesTableTableTableManager get routinesTable =>
      $$RoutinesTableTableTableManager(_db.attachedDatabase, _db.routinesTable);
  $$ExercisesTableTableTableManager get exercisesTable =>
      $$ExercisesTableTableTableManager(
        _db.attachedDatabase,
        _db.exercisesTable,
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
}
