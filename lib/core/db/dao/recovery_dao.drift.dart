// dart format width=80
// ignore_for_file: type=lint
part of 'recovery_dao.dart';

mixin _$RecoveryDaoMixin on DatabaseAccessor<AppDatabase> {
  $SorenessChecksTableTable get sorenessChecksTable =>
      attachedDatabase.sorenessChecksTable;
  RecoveryDaoManager get managers => RecoveryDaoManager(this);
}

class RecoveryDaoManager {
  final _$RecoveryDaoMixin _db;
  RecoveryDaoManager(this._db);
  $$SorenessChecksTableTableTableManager get sorenessChecksTable =>
      $$SorenessChecksTableTableTableManager(
        _db.attachedDatabase,
        _db.sorenessChecksTable,
      );
}
