import 'package:drift/drift.dart';

import 'dao/exercises_dao.dart';
import 'dao/records_dao.dart';
import 'dao/routines_dao.dart';
import 'dao/settings_dao.dart';
import 'dao/workouts_dao.dart';
import 'tables.dart';

export 'dao/exercises_dao.dart' show ExerciseFilter;
export 'dao/routines_dao.dart'
    show RoutineDraft, RoutineExerciseDraft, RoutineSetDraft;
export 'dao/settings_dao.dart' show kSingletonId;
export 'enums.dart';
export 'tables.dart';

part 'database.drift.dart';

/// The single database of the app. Everything the user owns lives here, and
/// the file it is backed by is encrypted with SQLCipher.
@DriftDatabase(
  tables: [
    UserProfileTable,
    AppSettingsTable,
    ExercisesTable,
    RoutineFoldersTable,
    RoutinesTable,
    RoutineExercisesTable,
    RoutineSetsTable,
    WorkoutsTable,
    WorkoutExercisesTable,
    WorkoutSetsTable,
    PersonalRecordsTable,
    BodyMeasurementsTable,
    ProgressPhotosTable,
  ],
  daos: [
    SettingsDao,
    ExercisesDao,
    RoutinesDao,
    WorkoutsDao,
    RecordsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Schema version 1 is the first release, so there is nothing to upgrade
      // yet. Every future step added here must be additive: new tables, new
      // nullable columns, new indexes. Dropping or rewriting a column that
      // holds user data is not allowed - see docs/DATA_MODEL.md.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
