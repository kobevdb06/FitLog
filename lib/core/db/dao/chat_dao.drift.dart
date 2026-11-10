// dart format width=80
// ignore_for_file: type=lint
part of 'chat_dao.dart';

mixin _$ChatDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChatThreadsTableTable get chatThreadsTable =>
      attachedDatabase.chatThreadsTable;
  $ChatMessagesTableTable get chatMessagesTable =>
      attachedDatabase.chatMessagesTable;
  $ChatFoldersTableTable get chatFoldersTable =>
      attachedDatabase.chatFoldersTable;
  $MorningReportsTableTable get morningReportsTable =>
      attachedDatabase.morningReportsTable;
  $WeekReviewsTableTable get weekReviewsTable =>
      attachedDatabase.weekReviewsTable;
  $RoutineFoldersTableTable get routineFoldersTable =>
      attachedDatabase.routineFoldersTable;
  $RoutinesTableTable get routinesTable => attachedDatabase.routinesTable;
  $WorkoutsTableTable get workoutsTable => attachedDatabase.workoutsTable;
  $WorkoutAnswersTableTable get workoutAnswersTable =>
      attachedDatabase.workoutAnswersTable;
  $MomentAnswersTableTable get momentAnswersTable =>
      attachedDatabase.momentAnswersTable;
  $CoachRequestsTableTable get coachRequestsTable =>
      attachedDatabase.coachRequestsTable;
  ChatDaoManager get managers => ChatDaoManager(this);
}

class ChatDaoManager {
  final _$ChatDaoMixin _db;
  ChatDaoManager(this._db);
  $$ChatThreadsTableTableTableManager get chatThreadsTable =>
      $$ChatThreadsTableTableTableManager(
        _db.attachedDatabase,
        _db.chatThreadsTable,
      );
  $$ChatMessagesTableTableTableManager get chatMessagesTable =>
      $$ChatMessagesTableTableTableManager(
        _db.attachedDatabase,
        _db.chatMessagesTable,
      );
  $$ChatFoldersTableTableTableManager get chatFoldersTable =>
      $$ChatFoldersTableTableTableManager(
        _db.attachedDatabase,
        _db.chatFoldersTable,
      );
  $$MorningReportsTableTableTableManager get morningReportsTable =>
      $$MorningReportsTableTableTableManager(
        _db.attachedDatabase,
        _db.morningReportsTable,
      );
  $$WeekReviewsTableTableTableManager get weekReviewsTable =>
      $$WeekReviewsTableTableTableManager(
        _db.attachedDatabase,
        _db.weekReviewsTable,
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
  $$MomentAnswersTableTableTableManager get momentAnswersTable =>
      $$MomentAnswersTableTableTableManager(
        _db.attachedDatabase,
        _db.momentAnswersTable,
      );
  $$CoachRequestsTableTableTableManager get coachRequestsTable =>
      $$CoachRequestsTableTableTableManager(
        _db.attachedDatabase,
        _db.coachRequestsTable,
      );
}
