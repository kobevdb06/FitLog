// dart format width=80
// ignore_for_file: type=lint
part of 'plans_dao.dart';

mixin _$PlansDaoMixin on DatabaseAccessor<AppDatabase> {
  $TrainingPlansTableTable get trainingPlansTable =>
      attachedDatabase.trainingPlansTable;
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $WorkoutsTableTable get workoutsTable => attachedDatabase.workoutsTable;
  PlansDaoManager get managers => PlansDaoManager(this);
}

class PlansDaoManager {
  final _$PlansDaoMixin _db;
  PlansDaoManager(this._db);
  $$TrainingPlansTableTableTableManager get trainingPlansTable =>
      $$TrainingPlansTableTableTableManager(
        _db.attachedDatabase,
        _db.trainingPlansTable,
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
}
