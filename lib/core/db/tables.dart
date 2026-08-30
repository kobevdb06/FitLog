import 'package:drift/drift.dart';

// All ids are UUID v4 stored as TEXT. All instants are stored as INTEGER
// (unix milliseconds, UTC). Nothing in this file ever stores a non-metric
// value: kilograms, centimetres, metres and seconds only.

@DataClassName('UserProfileRow')
class UserProfileTable extends Table {
  @override
  String get tableName => 'user_profile';

  TextColumn get id => text()();
  TextColumn get displayName => text().named('display_name').nullable()();

  /// Unix millis, UTC, midnight of the birth date.
  IntColumn get birthDate => integer().named('birth_date').nullable()();

  /// `male` | `female` | `other` | `undisclosed`.
  TextColumn get sex => text().nullable()();
  RealColumn get heightCm => real().named('height_cm').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get id => text()();

  /// `kg` | `lb`.
  TextColumn get unitWeight =>
      text().named('unit_weight').withDefault(const Constant('kg'))();

  /// `cm` | `in`.
  TextColumn get unitLength =>
      text().named('unit_length').withDefault(const Constant('cm'))();

  /// `km` | `mi`.
  TextColumn get unitDistance =>
      text().named('unit_distance').withDefault(const Constant('km'))();

  IntColumn get defaultRestSeconds =>
      integer().named('default_rest_seconds').withDefault(const Constant(90))();
  BoolColumn get restSoundEnabled =>
      boolean().named('rest_sound_enabled').withDefault(const Constant(true))();
  BoolColumn get setCheckSoundEnabled => boolean()
      .named('set_check_sound_enabled')
      .withDefault(const Constant(true))();
  BoolColumn get prAlertEnabled =>
      boolean().named('pr_alert_enabled').withDefault(const Constant(true))();

  /// `system` | `light` | `dark`. Defaults to dark: this app is dark first.
  TextColumn get themeMode =>
      text().named('theme_mode').withDefault(const Constant('dark'))();
  TextColumn get locale => text().withDefault(const Constant('nl'))();
  BoolColumn get onboardingDone =>
      boolean().named('onboarding_done').withDefault(const Constant(false))();

  /// Set once the bundled exercise catalogue has been imported.
  BoolColumn get exercisesSeeded =>
      boolean().named('exercises_seeded').withDefault(const Constant(false))();

  /// Barbell weight in kg used by the plate calculator.
  RealColumn get barWeightKg =>
      real().named('bar_weight_kg').withDefault(const Constant(20.0))();

  /// JSON array of available plate weights in kg, per side.
  TextColumn get availablePlatesKg => text()
      .named('available_plates_kg')
      .withDefault(const Constant('[25,20,15,10,5,2.5,1.25]'))();

  /// How many warm-up sets a newly added exercise starts with, 0 to 5.
  IntColumn get defaultWarmupSets =>
      integer().named('default_warmup_sets').withDefault(const Constant(0))();

  /// How many warm-up rungs a PR attempt is pre-filled with, 2 to 8.
  IntColumn get prDefaultWarmupSets => integer()
      .named('pr_default_warmup_sets')
      .withDefault(const Constant(4))();

  /// How many further attempts to offer after a successful one, 0 to 3.
  IntColumn get prDefaultExtraAttempts => integer()
      .named('pr_default_extra_attempts')
      .withDefault(const Constant(1))();

  /// Seconds of background time before the app locks. 0 = immediately,
  /// -1 = never.
  IntColumn get autoLockSeconds =>
      integer().named('auto_lock_seconds').withDefault(const Constant(60))();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExerciseRow')
class ExercisesTable extends Table {
  @override
  String get tableName => 'exercises';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text().named('primary_muscle')();

  /// JSON array of muscle names.
  TextColumn get secondaryMuscles => text()
      .named('secondary_muscles')
      .withDefault(const Constant('[]'))();
  TextColumn get equipment => text().nullable()();

  /// One of [ExerciseCategory].
  TextColumn get category => text()();
  TextColumn get instructions => text().nullable()();
  TextColumn get imageAsset => text().named('image_asset').nullable()();

  /// The two frames of a user-made exercise, as file names in the photo
  /// directory. Only the name is stored, for the same reason progress photos
  /// do it that way: the container path changes underneath an absolute one.
  TextColumn get startImageFile =>
      text().named('start_image_file').nullable()();
  TextColumn get endImageFile => text().named('end_image_file').nullable()();

  BoolColumn get isCustom =>
      boolean().named('is_custom').withDefault(const Constant(false))();
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoutineFolderRow')
class RoutineFoldersTable extends Table {
  @override
  String get tableName => 'routine_folders';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().named('sort_order')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoutineRow')
class RoutinesTable extends Table {
  @override
  String get tableName => 'routines';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get folderId => text()
      .named('folder_id')
      .nullable()
      .references(RoutineFoldersTable, #id, onDelete: KeyAction.setNull)();
  IntColumn get sortOrder => integer().named('sort_order')();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get lastPerformedAt =>
      integer().named('last_performed_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_routine_exercises_routine', columns: {#routineId})
@DataClassName('RoutineExerciseRow')
class RoutineExercisesTable extends Table {
  @override
  String get tableName => 'routine_exercises';

  TextColumn get id => text()();
  TextColumn get routineId => text()
      .named('routine_id')
      .references(RoutinesTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId =>
      text().named('exercise_id').references(ExercisesTable, #id)();
  IntColumn get sortOrder => integer().named('sort_order')();
  IntColumn get restSeconds => integer().named('rest_seconds').nullable()();
  IntColumn get supersetGroup =>
      integer().named('superset_group').nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_routine_sets_routine_exercise', columns: {#routineExerciseId})
@DataClassName('RoutineSetRow')
class RoutineSetsTable extends Table {
  @override
  String get tableName => 'routine_sets';

  TextColumn get id => text()();
  TextColumn get routineExerciseId => text()
      .named('routine_exercise_id')
      .references(RoutineExercisesTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().named('sort_order')();

  /// One of [SetType].
  TextColumn get setType =>
      text().named('set_type').withDefault(const Constant('normal'))();
  IntColumn get targetReps => integer().named('target_reps').nullable()();
  RealColumn get targetWeightKg =>
      real().named('target_weight_kg').nullable()();
  IntColumn get targetDurationSeconds =>
      integer().named('target_duration_seconds').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_workouts_started_at', columns: {#startedAt})
@DataClassName('WorkoutRow')
class WorkoutsTable extends Table {
  @override
  String get tableName => 'workouts';

  TextColumn get id => text()();
  TextColumn get routineId => text()
      .named('routine_id')
      .nullable()
      .references(RoutinesTable, #id, onDelete: KeyAction.setNull)();
  TextColumn get name => text()();
  IntColumn get startedAt => integer().named('started_at')();

  /// `NULL` marks the one and only running session.
  IntColumn get endedAt => integer().named('ended_at').nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get totalVolumeKg =>
      real().named('total_volume_kg').withDefault(const Constant(0))();
  IntColumn get totalSets =>
      integer().named('total_sets').withDefault(const Constant(0))();
  IntColumn get durationSeconds =>
      integer().named('duration_seconds').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_workout_exercises_workout', columns: {#workoutId})
@TableIndex(name: 'idx_workout_exercises_exercise', columns: {#exerciseId})
@DataClassName('WorkoutExerciseRow')
class WorkoutExercisesTable extends Table {
  @override
  String get tableName => 'workout_exercises';

  TextColumn get id => text()();
  TextColumn get workoutId => text()
      .named('workout_id')
      .references(WorkoutsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId =>
      text().named('exercise_id').references(ExercisesTable, #id)();
  IntColumn get sortOrder => integer().named('sort_order')();
  IntColumn get restSeconds =>
      integer().named('rest_seconds').withDefault(const Constant(90))();
  IntColumn get supersetGroup =>
      integer().named('superset_group').nullable()();
  TextColumn get notes => text().nullable()();

  /// Marks this exercise as a one-rep-max attempt with its own warm-up ladder.
  BoolColumn get isPrAttempt =>
      boolean().named('is_pr_attempt').withDefault(const Constant(false))();

  /// The weight the attempt was aiming for.
  RealColumn get prTargetWeightKg =>
      real().named('pr_target_weight_kg').nullable()();

  /// `success` | `failed` | `abandoned`, or null while it is still running.
  TextColumn get prResult => text().named('pr_result').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_workout_sets_workout_exercise', columns: {#workoutExerciseId})
@DataClassName('WorkoutSetRow')
class WorkoutSetsTable extends Table {
  @override
  String get tableName => 'workout_sets';

  TextColumn get id => text()();
  TextColumn get workoutExerciseId => text()
      .named('workout_exercise_id')
      .references(WorkoutExercisesTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().named('sort_order')();

  /// One of [SetType]: `warmup` | `normal` | `drop` | `failure`.
  TextColumn get setType =>
      text().named('set_type').withDefault(const Constant('normal'))();
  RealColumn get weightKg => real().named('weight_kg').nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get durationSeconds =>
      integer().named('duration_seconds').nullable()();
  RealColumn get distanceM => real().named('distance_m').nullable()();
  RealColumn get rpe => real().nullable()();
  BoolColumn get isCompleted =>
      boolean().named('is_completed').withDefault(const Constant(false))();
  IntColumn get completedAt => integer().named('completed_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_personal_records_exercise_type', columns: {#exerciseId, #recordType})
@DataClassName('PersonalRecordRow')
class PersonalRecordsTable extends Table {
  @override
  String get tableName => 'personal_records';

  TextColumn get id => text()();
  TextColumn get exerciseId => text()
      .named('exercise_id')
      .references(ExercisesTable, #id, onDelete: KeyAction.cascade)();

  /// One of [PrType]: `max_weight` | `est_1rm` | `max_set_volume` | `max_reps`.
  TextColumn get recordType => text().named('record_type')();
  RealColumn get value => real()();
  /// The set that produced this record.
  ///
  /// `ON DELETE SET NULL`: deleting a workout takes its sets with it, and a
  /// record that outlives its set must lose the reference rather than keep a
  /// dangling id. Without this constraint the row simply pointed at nothing.
  TextColumn get workoutSetId => text()
      .named('workout_set_id')
      .nullable()
      .references(WorkoutSetsTable, #id, onDelete: KeyAction.setNull)();
  IntColumn get achievedAt => integer().named('achieved_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_body_measurements_type_date', columns: {#type, #measuredAt})
@DataClassName('BodyMeasurementRow')
class BodyMeasurementsTable extends Table {
  @override
  String get tableName => 'body_measurements';

  TextColumn get id => text()();
  IntColumn get measuredAt => integer().named('measured_at')();

  /// One of [MeasurementType].
  TextColumn get type => text()();

  /// Always metric: kilograms for weight, percent for body fat, centimetres
  /// for every circumference.
  RealColumn get value => real()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_progress_photos_taken_at', columns: {#takenAt})
@DataClassName('ProgressPhotoRow')
class ProgressPhotosTable extends Table {
  @override
  String get tableName => 'progress_photos';

  TextColumn get id => text()();
  IntColumn get takenAt => integer().named('taken_at')();

  /// File name inside `<app documents>/photos/`. The bytes never live in the
  /// database.
  TextColumn get fileName => text().named('file_name')();

  /// `front` | `side` | `back`.
  TextColumn get pose => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
