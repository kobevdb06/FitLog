import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fitlog/core/db/connection.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitlog_enc_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('the bundled SQLite really is SQLCipher', () {
    final version = detectCipherVersion();
    expect(
      version,
      isNotEmpty,
      reason: 'PRAGMA cipher_version is leeg: dit is gewone SQLite',
    );
  });

  test('a database written with a key is unreadable without it', () async {
    final file = File('${tempDir.path}/fitlog.db');
    final keyHex = toHex(generateDek());

    final db = AppDatabase(
      openEncryptedExecutor(file: file, keyHex: keyHex),
    );
    await db.settingsDao.ensureInitialized();
    await db.close();

    expect(await file.exists(), isTrue);

    // The file header of a plain SQLite database starts with "SQLite format 3";
    // an encrypted one does not.
    final header = await file.openRead(0, 16).first;
    expect(String.fromCharCodes(header), isNot(startsWith('SQLite format 3')));

    // Opening it without a key fails as soon as the schema is touched.
    final plain = sqlite3.open(file.path);
    expect(
      () => plain.select('SELECT count(*) FROM sqlite_master'),
      throwsA(isA<SqliteException>()),
    );
    plain.close();
  });

  test('the wrong key is refused, the right key works', () async {
    final file = File('${tempDir.path}/fitlog.db');
    final rightKey = toHex(generateDek());
    final wrongKey = toHex(generateDek());

    var db = AppDatabase(
      openEncryptedExecutor(file: file, keyHex: rightKey),
    );
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(defaultRestSeconds: Value(123)),
    );
    await db.close();

    final wrong = AppDatabase(
      openEncryptedExecutor(file: file, keyHex: wrongKey),
    );
    await expectLater(
      wrong.settingsDao.getSettings(),
      throwsA(anything),
    );
    await wrong.close();

    db = AppDatabase(openEncryptedExecutor(file: file, keyHex: rightKey));
    expect((await db.settingsDao.getSettings()).defaultRestSeconds, 123);
    await db.close();
  });

  test('foreign keys are enforced on an encrypted connection', () async {
    final db = AppDatabase(
      openEncryptedMemoryExecutor(toHex(generateDek())),
    );
    await db.settingsDao.ensureInitialized();

    final enabled = await db
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(enabled.data.values.first, 1);

    // routine_exercises references a routine that does not exist.
    await expectLater(
      db.into(db.routineExercisesTable).insert(
        RoutineExercisesTableCompanion.insert(
          id: 'x',
          routineId: 'does-not-exist',
          exerciseId: 'neither',
          sortOrder: 0,
        ),
      ),
      throwsA(anything),
    );

    await db.close();
  });

  test('applyKeyAndVerify rejects a mismatched key with a typed error',
      () async {
    final file = File('${tempDir.path}/typed.db');
    final db = AppDatabase(
      openEncryptedExecutor(file: file, keyHex: toHex(generateDek())),
    );
    await db.settingsDao.ensureInitialized();
    await db.close();

    final raw = sqlite3.open(file.path);
    expect(
      () => applyKeyAndVerify(raw, toHex(generateDek())),
      throwsA(isA<WrongDatabaseKeyException>()),
    );
    raw.close();
  });

  test('the schema is created at the current version', () async {
    final db = AppDatabase(
      NativeDatabase.memory(),
    );
    expect(db.schemaVersion, 8);
    await db.settingsDao.ensureInitialized();
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(<String>{
      'user_profile',
      'app_settings',
      'exercises',
      'routine_folders',
      'routines',
      'routine_exercises',
      'routine_sets',
      'workouts',
      'workout_exercises',
      'workout_sets',
      'personal_records',
      'body_measurements',
      'progress_photos',
    }));
    await db.close();
  });

  test('the documented indexes exist', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.settingsDao.ensureInitialized();
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(<String>{
      'idx_workout_sets_workout_exercise',
      'idx_workout_exercises_workout',
      'idx_workout_exercises_exercise',
      'idx_workouts_started_at',
      'idx_personal_records_exercise_type',
      'idx_body_measurements_type_date',
    }));
    await db.close();
  });
}
