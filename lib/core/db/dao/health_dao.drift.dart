// dart format width=80
// ignore_for_file: type=lint
part of 'health_dao.dart';

mixin _$HealthDaoMixin on DatabaseAccessor<AppDatabase> {
  $SleepEntriesTableTable get sleepEntriesTable =>
      attachedDatabase.sleepEntriesTable;
  $BodyMeasurementsTableTable get bodyMeasurementsTable =>
      attachedDatabase.bodyMeasurementsTable;
  $DailyVitalsTableTable get dailyVitalsTable =>
      attachedDatabase.dailyVitalsTable;
  $CardioSessionsTableTable get cardioSessionsTable =>
      attachedDatabase.cardioSessionsTable;
  HealthDaoManager get managers => HealthDaoManager(this);
}

class HealthDaoManager {
  final _$HealthDaoMixin _db;
  HealthDaoManager(this._db);
  $$SleepEntriesTableTableTableManager get sleepEntriesTable =>
      $$SleepEntriesTableTableTableManager(
        _db.attachedDatabase,
        _db.sleepEntriesTable,
      );
  $$BodyMeasurementsTableTableTableManager get bodyMeasurementsTable =>
      $$BodyMeasurementsTableTableTableManager(
        _db.attachedDatabase,
        _db.bodyMeasurementsTable,
      );
  $$DailyVitalsTableTableTableManager get dailyVitalsTable =>
      $$DailyVitalsTableTableTableManager(
        _db.attachedDatabase,
        _db.dailyVitalsTable,
      );
  $$CardioSessionsTableTableTableManager get cardioSessionsTable =>
      $$CardioSessionsTableTableTableManager(
        _db.attachedDatabase,
        _db.cardioSessionsTable,
      );
}
