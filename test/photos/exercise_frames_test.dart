import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/photos/data/photo_library.dart';
import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'photo_store_test.dart' show writeSourceImage;

/// The two frames of a user-made exercise live in the same directory as the
/// progress photos, which is what makes them travel in the backup for free.
/// The price is that the startup reconcile has to know about them: it deletes
/// every file no row points at, and an exercise frame is pointed at from a
/// different table.
void main() {
  late Directory root;
  late Directory cache;
  late AppPaths paths;
  late PhotoStore store;
  late AppDatabase db;
  late PhotoLibrary library;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fitlog_frames');
    cache = await Directory.systemTemp.createTemp('fitlog_frames_cache');
    paths = AppPaths(root);
    store = PhotoStore(paths);
    db = AppDatabase(NativeDatabase.memory());
    await db.settingsDao.ensureInitialized();
    library = PhotoLibrary(db: db, store: store);
  });

  tearDown(() async {
    await db.close();
    for (final dir in [root, cache]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  Future<String> importFrame(String name) => store.import(
    writeSourceImage(cache, name, width: 1600, height: 1200),
    maxLongEdge: 720,
  );

  Future<String> makeExercise({String? start, String? end}) async {
    const id = 'own-1';
    await db.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: id,
        name: 'Kabel curl schuin',
        primaryMuscle: 'biceps',
        category: 'cable',
        isCustom: const Value(true),
        startImageFile: Value(start),
        endImageFile: Value(end),
        createdAt: 0,
      ),
    );
    return id;
  }

  test('a frame is scaled down further than a progress photo', () async {
    final fileName = await importFrame('start.jpg');
    final decoded = img.decodeJpg(store.fileFor(fileName).readAsBytesSync())!;

    expect(decoded.width, 720);
    expect(decoded.height, 540);
  });

  test('both frames come back as the names to keep', () async {
    final start = await importFrame('start.jpg');
    final end = await importFrame('end.jpg');
    await makeExercise(start: start, end: end);

    expect(await db.exercisesDao.imageFileNames(), {start, end});
  });

  test('an exercise without pictures contributes no names', () async {
    await makeExercise();
    expect(await db.exercisesDao.imageFileNames(), isEmpty);
  });

  test('the reconcile leaves the frames alone', () async {
    final start = await importFrame('start.jpg');
    final end = await importFrame('end.jpg');
    await makeExercise(start: start, end: end);

    final result = await library.cleanup();

    expect(result.deletedFiles, isEmpty);
    expect(await store.exists(start), isTrue);
    expect(await store.exists(end), isTrue);
  });

  test('a file nothing points at is still swept up', () async {
    final kept = await importFrame('start.jpg');
    final orphan = await importFrame('stray.jpg');
    await makeExercise(start: kept);

    final result = await library.cleanup();

    expect(result.deletedFiles, {orphan});
    expect(await store.exists(kept), isTrue);
  });

  test('a frame whose file is gone loses the reference, not the exercise',
      () async {
    final start = await importFrame('start.jpg');
    final end = await importFrame('end.jpg');
    final id = await makeExercise(start: start, end: end);

    await store.deleteFile(end);
    final result = await library.cleanup();

    expect(result.missingFiles, {end});
    final row = await db.exercisesDao.getById(id);
    expect(row, isNotNull, reason: 'the exercise itself must survive');
    expect(row!.startImageFile, start);
    expect(row.endImageFile, isNull);
  });

  test('clearing one frame does not touch the other', () async {
    final start = await importFrame('start.jpg');
    final end = await importFrame('end.jpg');
    final id = await makeExercise(start: start, end: end);

    await db.exercisesDao.clearImageFile(start);

    final row = await db.exercisesDao.getById(id);
    expect(row!.startImageFile, isNull);
    expect(row.endImageFile, end);
  });
}
