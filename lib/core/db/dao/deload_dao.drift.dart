// dart format width=80
// ignore_for_file: type=lint
part of 'deload_dao.dart';

mixin _$DeloadDaoMixin on DatabaseAccessor<AppDatabase> {
  $DeloadWeeksTableTable get deloadWeeksTable =>
      attachedDatabase.deloadWeeksTable;
  DeloadDaoManager get managers => DeloadDaoManager(this);
}

class DeloadDaoManager {
  final _$DeloadDaoMixin _db;
  DeloadDaoManager(this._db);
  $$DeloadWeeksTableTableTableManager get deloadWeeksTable =>
      $$DeloadWeeksTableTableTableManager(
        _db.attachedDatabase,
        _db.deloadWeeksTable,
      );
}
