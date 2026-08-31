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
  int get schemaVersion => 9;

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
        if (from < 3) {
          // Purely additive: existing rows keep the default of 0, which is
          // the behaviour they had before the setting existed.
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.defaultWarmupSets,
          );
        }
        if (from < 4) {
          // PR attempts. Additive again: existing workout_exercises rows are
          // ordinary exercises, which is exactly what the defaults say.
          await m.addColumn(
            workoutExercisesTable,
            workoutExercisesTable.isPrAttempt,
          );
          await m.addColumn(
            workoutExercisesTable,
            workoutExercisesTable.prTargetWeightKg,
          );
          await m.addColumn(
            workoutExercisesTable,
            workoutExercisesTable.prResult,
          );
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.prDefaultWarmupSets,
          );
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.prDefaultExtraAttempts,
          );
        }
        if (from < 5) {
          // The two frames of a user-made exercise. Additive: every existing
          // exercise has no pictures of its own, which is what null says.
          await m.addColumn(exercisesTable, exercisesTable.startImageFile);
          await m.addColumn(exercisesTable, exercisesTable.endImageFile);
        }
        if (from < 6) {
          // How heavy a session felt. Additive: a session from before the
          // rating existed is simply unrated, which the estimate treats as
          // neutral.
          await m.addColumn(workoutsTable, workoutsTable.perceivedEffort);
        }
        if (from < 7) {
          // When the last backup was made. Null means never, which is exactly
          // what was true for every database before this column existed.
          await m.addColumn(appSettingsTable, appSettingsTable.lastBackupAt);
        }
        if (from < 8) {
          // The note that survives Android killing the app mid-pick. Null on
          // every existing row, which means nothing is pending - true, since
          // the app was not picking anything while it was closed.
          await m.addColumn(appSettingsTable, appSettingsTable.pendingPickKind);
          await m.addColumn(appSettingsTable, appSettingsTable.pendingPickRef);
        }
        if (from < 9) {
          // A colour for a routine, and the copy a session keeps of it.
          // Additive: everything that exists has no colour, which is what null
          // says and what the lists already draw.
          await m.addColumn(routinesTable, routinesTable.colorIndex);
          await m.addColumn(workoutsTable, workoutsTable.colorIndex);
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
