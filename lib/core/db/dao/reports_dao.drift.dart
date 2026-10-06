// dart format width=80
// ignore_for_file: type=lint
part of 'reports_dao.dart';

mixin _$ReportsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MorningReportsTableTable get morningReportsTable =>
      attachedDatabase.morningReportsTable;
  $WeekReviewsTableTable get weekReviewsTable =>
      attachedDatabase.weekReviewsTable;
  ReportsDaoManager get managers => ReportsDaoManager(this);
}

class ReportsDaoManager {
  final _$ReportsDaoMixin _db;
  ReportsDaoManager(this._db);
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
}
