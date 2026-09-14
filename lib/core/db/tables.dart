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

  /// When the last encrypted backup was written, in unix millis.
  ///
  /// It is written before the database snapshot is taken, so the value inside
  /// a backup is that backup's own moment: after a restore the reminder is
  /// right without any extra bookkeeping.
  IntColumn get lastBackupAt => integer().named('last_backup_at').nullable()();

  /// One of [PickKind] while a photo is being picked, null otherwise.
  ///
  /// Android may kill the app while the camera is in front of it. The note
  /// survives that, and is what tells the next launch where the picture it
  /// gets handed back belongs.
  TextColumn get pendingPickKind =>
      text().named('pending_pick_kind').nullable()();

  /// What the pending pick was for: a pose, or an exercise and a slot.
  TextColumn get pendingPickRef =>
      text().named('pending_pick_ref').nullable()();

  /// `system` | `light` | `dark`. Defaults to dark: this app is dark first.
  TextColumn get themeMode =>
      text().named('theme_mode').withDefault(const Constant('dark'))();
  TextColumn get locale => text().withDefault(const Constant('nl'))();
  BoolColumn get onboardingDone =>
      boolean().named('onboarding_done').withDefault(const Constant(false))();

  /// Set once the bundled exercise catalogue has been imported.
  BoolColumn get exercisesSeeded =>
      boolean().named('exercises_seeded').withDefault(const Constant(false))();

  /// Which build of the bundled catalogue this database has been brought up
  /// to, so a correction to it can reach a database that was seeded long ago.
  ///
  /// The catalogue is only imported once, on the very first start. Without
  /// this, fixing a wrong exercise type in the asset would reach new installs
  /// and no one else.
  IntColumn get seedVersion =>
      integer().named('seed_version').withDefault(const Constant(0))();

  /// Barbell weight in kg used by the plate calculator.
  RealColumn get barWeightKg =>
      real().named('bar_weight_kg').withDefault(const Constant(20.0))();

  /// JSON array of available plate weights in kg, per side.
  TextColumn get availablePlatesKg => text()
      .named('available_plates_kg')
      .withDefault(const Constant('[25,20,15,10,5,2.5,1.25]'))();

  /// Whether every set asks for an RPE as well.
  ///
  /// Off by default: it is one more number per set, and most people do not
  /// want to score every set they do. Turn it on and the estimate of how long
  /// a muscle needs starts listening to it.
  BoolColumn get trackRpe =>
      boolean().named('track_rpe').withDefault(const Constant(false))();

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

  /// Which blocks the Start tab shows and in what order, as the JSON that
  /// `parseHomeLayout` reads.
  ///
  /// Null means it has never been changed, which is what the default layout
  /// answers. A damaged value answers the same rather than throwing: the first
  /// screen of the app is the worst place to fail.
  TextColumn get homeLayout => text().named('home_layout').nullable()();

  /// The user's own Anthropic API key, or null when there is none.
  ///
  /// Null is the normal state and the one the app ships in: without a key the
  /// coach does not exist and nothing in the app opens a socket. It lives here
  /// rather than in the Keystore because here it is already behind the
  /// database key, and because a key that survives a restore is a key the user
  /// does not have to find again.
  TextColumn get anthropicApiKey =>
      text().named('anthropic_api_key').nullable()();

  /// Which model the coach talks to. Null means the app's own default.
  TextColumn get chatModel => text().named('chat_model').nullable()();

  /// Seconds of background time before the app locks. 0 = immediately,
  /// -1 = never.
  IntColumn get autoLockSeconds =>
      integer().named('auto_lock_seconds').withDefault(const Constant(60))();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

/// A muscle group the user added themselves.
///
/// Kept apart from the exercises because it has to survive without one: you
/// add "serratus" to be able to pick it, and the exercise that uses it comes
/// after. Deriving the list from the catalogue alone - which is what the
/// pickers used to do - means a group vanishes the moment nothing uses it.
@DataClassName('CustomMuscleRow')
class CustomMusclesTable extends Table {
  @override
  String get tableName => 'custom_muscles';

  /// Lower case, because that is the key every other table joins on.
  TextColumn get name => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {name};
}

/// Kit the user added themselves, for the same reason.
@DataClassName('CustomEquipmentRow')
class CustomEquipmentTable extends Table {
  @override
  String get tableName => 'custom_equipment';

  TextColumn get name => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {name};
}

/// A name of your own for a way of training.
///
/// The eight built-in categories are not a list of names, they are a list of
/// behaviours: each one decides which columns a set has. So an added category
/// cannot invent a new one - it borrows one. [base] is the built-in category
/// it counts as; the name is yours.
@DataClassName('CustomCategoryRow')
class CustomCategoriesTable extends Table {
  @override
  String get tableName => 'custom_categories';

  TextColumn get name => text()();

  /// The wire value of the [ExerciseCategory] this one is measured as.
  TextColumn get base => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {name};
}

/// One conversation with the coach.
///
/// Threads rather than one endless log: a question about your bench in March
/// and a question about your knee in June have nothing to say to each other,
/// and every message of a thread is sent again with the next one.
@DataClassName('ChatThreadRow')
class ChatThreadsTable extends Table {
  @override
  String get tableName => 'chat_threads';

  TextColumn get id => text()();

  /// The first thing you asked, shortened. Named by you, never by the model.
  TextColumn get title => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatMessageRow')
class ChatMessagesTable extends Table {
  @override
  String get tableName => 'chat_messages';

  TextColumn get id => text()();
  TextColumn get threadId => text()
      .named('thread_id')
      .references(ChatThreadsTable, #id, onDelete: KeyAction.cascade)();

  /// `user` or `assistant`.
  TextColumn get role => text()();
  TextColumn get content => text()();

  /// What the coach looked up in your database while answering, as a JSON
  /// array of readable lines.
  ///
  /// Kept with the message because "what did it get to see about me" is a
  /// question you should be able to answer later, not only in the second the
  /// answer arrives.
  TextColumn get lookups => text().nullable()();

  IntColumn get inputTokens => integer().named('input_tokens').nullable()();
  IntColumn get outputTokens => integer().named('output_tokens').nullable()();
  IntColumn get createdAt => integer().named('created_at')();

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
  TextColumn get secondaryMuscles =>
      text().named('secondary_muscles').withDefault(const Constant('[]'))();
  TextColumn get equipment => text().nullable()();

  /// One of [ExerciseCategory]. Always set, also for an exercise that carries
  /// a category of the user's own: that name is a label on top of one of
  /// these, and everything that reasons about sets reads this column.
  TextColumn get category => text()();

  /// The name of the user's own category, if they picked one.
  ///
  /// Null means the exercise simply is its [category]. A name here changes
  /// nothing about how the exercise is logged - only what it is called.
  TextColumn get customCategory => text().named('custom_category').nullable()();
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

  /// Set once the user has picked the type of this exercise themselves.
  ///
  /// The bundled catalogue can be wrong about how something is done - it had
  /// the plank down as a body-weight exercise, counted in repetitions - and
  /// correcting it in the app is faster than waiting for a new version. This
  /// marks that choice as the user's, so a later correction to the catalogue
  /// leaves it alone rather than quietly undoing it.
  BoolColumn get categoryOverridden => boolean()
      .named('category_overridden')
      .withDefault(const Constant(false))();
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

  /// A position in `AppColors.routinePalette`, or null for no colour.
  IntColumn get colorIndex => integer().named('color_index').nullable()();

  /// Starred by the user as one of the routines they actually do.
  ///
  /// What the home-screen shortcuts are picked from. You may star as many as
  /// you like; the launcher only has room for a few, so the ones you use most
  /// get those places.
  BoolColumn get isFavourite =>
      boolean().named('is_favourite').withDefault(const Constant(false))();

  /// The weekdays this routine is planned on, as a `WeekdaySet` mask.
  ///
  /// Zero means unplanned, which is what every routine was before a schedule
  /// existed and what the dashboard falls back from. Deliberately not part of
  /// `RoutineDraft`: a routine you receive over QR must not bring someone
  /// else's Monday with it.
  IntColumn get scheduledDays =>
      integer().named('scheduled_days').withDefault(const Constant(0))();

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
  IntColumn get supersetGroup => integer().named('superset_group').nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_routine_sets_routine_exercise',
  columns: {#routineExerciseId},
)
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

  /// Always metres, like everywhere else.
  RealColumn get targetDistanceM =>
      real().named('target_distance_m').nullable()();

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

  /// One of [PerceivedEffort], or null while the session has not been rated.
  TextColumn get perceivedEffort =>
      text().named('perceived_effort').nullable()();

  /// Copied from the routine when the session starts, the way the name is. A
  /// session keeps the colour it was done in, even if the routine is
  /// recoloured or deleted afterwards.
  IntColumn get colorIndex => integer().named('color_index').nullable()();
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
  IntColumn get supersetGroup => integer().named('superset_group').nullable()();
  TextColumn get notes => text().nullable()();

  /// Marks this exercise as being done one arm or leg at a time.
  ///
  /// Lives on the session, not on the routine: it goes back to both hands
  /// every time you start the routine again, and you turn it on when you feel
  /// like doing it that way.
  BoolColumn get isUnilateral =>
      boolean().named('is_unilateral').withDefault(const Constant(false))();

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

@TableIndex(
  name: 'idx_workout_sets_workout_exercise',
  columns: {#workoutExerciseId},
)
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

  /// One of [SetSide] while the exercise is done one side at a time, null
  /// otherwise. A left set and a right set are two separate sets: each carries
  /// its own weight and its own reps, because the two sides rarely match.
  TextColumn get side => text().nullable()();

  BoolColumn get isCompleted =>
      boolean().named('is_completed').withDefault(const Constant(false))();
  IntColumn get completedAt => integer().named('completed_at').nullable()();

  /// A set you deliberately did not do.
  ///
  /// Separate from [isCompleted] because those are two different answers: an
  /// empty set is one you have not got to yet, a skipped set is one you chose
  /// to leave out. Only the second is worth carrying into the next session,
  /// where the previous column says so instead of showing a dash.
  ///
  /// Separate from [setType] as well: skipping is not a kind of set. A
  /// warm-up you skip is still a warm-up, and folding the two together would
  /// lose the type and renumber everything below it.
  BoolColumn get isSkipped =>
      boolean().named('is_skipped').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_personal_records_exercise_type',
  columns: {#exerciseId, #recordType},
)
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

@TableIndex(
  name: 'idx_body_measurements_type_date',
  columns: {#type, #measuredAt},
)
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

  /// The session this picture belongs to, if you said so.
  ///
  /// `SET NULL` rather than a cascade: clearing out your history should not
  /// take your photographs with it. The picture outlives the session; it just
  /// stops saying which one it was.
  TextColumn get workoutId => text()
      .named('workout_id')
      .nullable()
      .references(WorkoutsTable, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column> get primaryKey => {id};
}
