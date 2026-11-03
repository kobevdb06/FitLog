// dart format width=80
// ignore_for_file: type=lint
part of 'coach_prompts_dao.dart';

mixin _$CoachPromptsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CoachPromptsTableTable get coachPromptsTable =>
      attachedDatabase.coachPromptsTable;
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $WorkoutsTableTable get workoutsTable => attachedDatabase.workoutsTable;
  $WorkoutAnswersTableTable get workoutAnswersTable =>
      attachedDatabase.workoutAnswersTable;
  CoachPromptsDaoManager get managers => CoachPromptsDaoManager(this);
}

class CoachPromptsDaoManager {
  final _$CoachPromptsDaoMixin _db;
  CoachPromptsDaoManager(this._db);
  $$CoachPromptsTableTableTableManager get coachPromptsTable =>
      $$CoachPromptsTableTableTableManager(
        _db.attachedDatabase,
        _db.coachPromptsTable,
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
  $$WorkoutAnswersTableTableTableManager get workoutAnswersTable =>
      $$WorkoutAnswersTableTableTableManager(
        _db.attachedDatabase,
        _db.workoutAnswersTable,
      );
}
