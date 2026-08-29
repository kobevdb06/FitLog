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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Foreign keys are enabled on every connection, and sqlite's twelve step
      // table rebuild needs them off. This has to happen outside a
      // transaction, which is why the pragmas sit around it rather than in it.
      await customStatement('PRAGMA foreign_keys = OFF');
      await transaction(() async {
        if (from < 2) {
          // v1 stored personal_records.workout_set_id without any constraint,
          // so deleting a workout left records pointing at sets that no longer
          // existed. Rebuilding the table adds ON DELETE SET NULL; the rows
          // themselves are copied over untouched.
          await m.alterTable(TableMigration(personalRecordsTable));

          // Anything already dangling from before the constraint existed is
          // cleared here, once.
          await customStatement(
            'UPDATE personal_records SET workout_set_id = NULL '
            'WHERE workout_set_id IS NOT NULL AND workout_set_id NOT IN '
            '(SELECT id FROM workout_sets)',
          );
        }
      });

      final broken = await customSelect('PRAGMA foreign_key_check').get();
      if (broken.isNotEmpty) {
        throw StateError(
          'Migratie liet ${broken.length} kapotte verwijzing(en) achter: '
          '${broken.map((row) => row.data).toList()}',
        );
      }
      await customStatement('PRAGMA foreign_keys = ON');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
