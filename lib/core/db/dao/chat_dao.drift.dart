// dart format width=80
// ignore_for_file: type=lint
part of 'chat_dao.dart';

mixin _$ChatDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChatThreadsTableTable get chatThreadsTable =>
      attachedDatabase.chatThreadsTable;
  $ChatMessagesTableTable get chatMessagesTable =>
      attachedDatabase.chatMessagesTable;
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
}
