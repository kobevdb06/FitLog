import 'dart:io';

// Only for NativeDatabase; the drift query builder exports an `isNull` that
// collides with the matcher of the same name.
import 'package:drift/native.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a real schema-version-1 database file, fills it with the kind of
/// data a user would already have, and checks that opening it with the current
/// code migrates it without losing anything.
File writeV1Database(Directory dir) {
  final sql = File('test/db/fixtures/schema_v1.sql').readAsStringSync();
  final path = '${dir.path}/fitlog_v1.db';
  final db = sqlite3.open(path);

  for (final statement in sql.split(';')) {
    final trimmed = statement
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n')
        .trim();
    if (trimmed.isEmpty) continue;
    db.execute('$trimmed;');
  }

  db
    ..execute('PRAGMA user_version = 1;')
    ..execute(
      "INSERT INTO app_settings (id, updated_at) VALUES ('singleton', 1000);",
    )
    ..execute(
      "INSERT INTO exercises (id, name, primary_muscle, category, created_at) "
      "VALUES ('ex-1', 'Barbell Squat', 'quadriceps', 'barbell', 1000);",
    )
    ..execute(
      "INSERT INTO routines (id, name, sort_order, created_at, updated_at, "
      "last_performed_at) VALUES ('r-1', 'Been', 0, 1000, 1000, 5000);",
    )
    ..execute(
      "INSERT INTO workouts (id, routine_id, name, started_at, ended_at, "
      "total_volume_kg, total_sets, duration_seconds) "
      "VALUES ('w-1', 'r-1', 'Been A', 5000, 9000, 500.0, 1, 4);",
    )
    ..execute(
      "INSERT INTO workout_exercises (id, workout_id, exercise_id, sort_order, "
      "rest_seconds) VALUES ('we-1', 'w-1', 'ex-1', 0, 90);",
    )
    ..execute(
      "INSERT INTO workout_sets (id, workout_exercise_id, sort_order, set_type, "
      "weight_kg, reps, is_completed, completed_at) "
      "VALUES ('ws-1', 'we-1', 0, 'normal', 100.0, 5, 1, 9000);",
    )
    // One healthy record, and one that already dangles because v1 had no
    // constraint on workout_set_id.
    ..execute(
      "INSERT INTO personal_records (id, exercise_id, record_type, value, "
      "workout_set_id, achieved_at) "
      "VALUES ('pr-1', 'ex-1', 'max_weight', 100.0, 'ws-1', 9000);",
    )
    ..execute(
      "INSERT INTO personal_records (id, exercise_id, record_type, value, "
      "workout_set_id, achieved_at) "
      "VALUES ('pr-2', 'ex-1', 'max_reps', 5.0, 'ws-verdwenen', 9000);",
    )
    ..execute(
      "INSERT INTO body_measurements (id, measured_at, type, value) "
      "VALUES ('bm-1', 4000, 'weight', 82.5);",
    )
    ..execute(
      "INSERT INTO progress_photos (id, taken_at, file_name, pose) "
      "VALUES ('ph-1', 4000, 'foto.jpg', 'front');",
    );

  db.close();
  return File(path);
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fitlog_migration');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('the fixture really is a version 1 database', () {
    final file = writeV1Database(dir);
    final raw = sqlite3.open(file.path);
    expect(raw.select('PRAGMA user_version').first.values.first, 1);

    // v1 has no foreign key on workout_set_id; that is the whole point of the
    // migration under test.
    final keys = raw.select('PRAGMA foreign_key_list(personal_records)');
    expect(keys.map((row) => row['from']), isNot(contains('workout_set_id')));
    raw.close();
  });

  test('opening a v1 database migrates it to the current version', () async {
    final file = writeV1Database(dir);
    final db = AppDatabase(NativeDatabase(file));

    // Touching the database triggers the migration.
    final settings = await db.settingsDao.getSettings();
    expect(settings.id, 'singleton');
    await db.close();

    final raw = sqlite3.open(file.path);
    expect(raw.select('PRAGMA user_version').first.values.first, 3);
    raw.close();
  });

  test('no user data is lost', () async {
    final file = writeV1Database(dir);
    final db = AppDatabase(NativeDatabase(file));

    expect(await db.exercisesDao.countExercises(), 1);
    expect((await db.routinesDao.getRoutine('r-1'))!.name, 'Been');

    final workout = await db.workoutsDao.getWorkoutDetail('w-1');
    expect(workout!.workout.name, 'Been A');
    expect(workout.exercises, hasLength(1));
    expect(workout.exercises.single.sets.single.weightKg, 100.0);

    expect(await db.recordsDao.measurements(), hasLength(1));
    expect(await db.recordsDao.photos(), hasLength(1));

    // Both record rows survive; only the dangling reference is cleared.
    final records = await db.recordsDao.recordsForExercise('ex-1');
    expect(records, hasLength(2));
    expect(
      records.firstWhere((r) => r.id == 'pr-1').workoutSetId,
      'ws-1',
    );
    expect(
      records.firstWhere((r) => r.id == 'pr-2').workoutSetId,
      isNull,
      reason: 'de verwijzing naar een verdwenen set moet leeggemaakt zijn',
    );

    // v3 adds the warm-up preference; existing databases get the default.
    expect((await db.settingsDao.getSettings()).defaultWarmupSets, 0);

    await db.close();
  });

  test('after migrating, deleting a set clears the record reference', () async {
    final file = writeV1Database(dir);
    final db = AppDatabase(NativeDatabase(file));
    await db.settingsDao.getSettings();

    await db.workoutsDao.deleteSet('ws-1');

    final records = await db.recordsDao.recordsForExercise('ex-1');
    final healthy = records.firstWhere((r) => r.id == 'pr-1');
    expect(
      healthy.workoutSetId,
      isNull,
      reason: 'ON DELETE SET NULL moet nu actief zijn',
    );

    await db.close();
  });

  test('the migration leaves the schema consistent', () async {
    final file = writeV1Database(dir);
    final db = AppDatabase(NativeDatabase(file));
    await db.settingsDao.getSettings();

    final broken = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(broken, isEmpty);

    final enabled = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(enabled.data.values.first, 1);

    await db.close();
  });

  test('a fresh database is created at the current version', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.settingsDao.ensureInitialized();
    expect(db.schemaVersion, 3);

    final keys = await db
        .customSelect('PRAGMA foreign_key_list(personal_records)')
        .get();
    final onSet = keys.firstWhere(
      (row) => row.read<String>('from') == 'workout_set_id',
    );
    expect(onSet.read<String>('on_delete'), 'SET NULL');

    await db.close();
  });
}
