import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/photos/data/pick_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_store_test.dart' show writeSourceImage;

/// Android may kill the app while the camera is in front of it. The picture is
/// still taken, and the plugin offers it back on the next launch - but only if
/// somebody asks, and only if something remembers where it was meant to go.
void main() {
  late Directory root;
  late Directory cache;
  late AppDatabase db;
  late AppPaths paths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fitlog_lost');
    cache = await Directory.systemTemp.createTemp('fitlog_lost_cache');
    paths = AppPaths(root);
    db = AppDatabase(NativeDatabase.memory());
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
    for (final dir in [root, cache]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  /// Stands in for the file the plugin hands back after the app was killed.
  PickRecovery recoveryWith(File? lost) =>
      PickRecovery(db: db, paths: paths, readLostFile: () async => lost);

  Future<String> makeExercise() async {
    await db.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: 'own-1',
        name: 'Kabel curl schuin',
        primaryMuscle: 'biceps',
        category: 'cable',
        isCustom: const Value(true),
        createdAt: 0,
      ),
    );
    return 'own-1';
  }

  group('the note', () {
    test('is nothing until a pick starts', () async {
      expect(await recoveryWith(null).pending(), isNull);
    });

    test('survives being written and read back', () async {
      final recovery = recoveryWith(null);
      await recovery.remember(PendingPick.progressPhoto(PhotoPose.front));

      final pending = await recovery.pending();
      expect(pending!.kind, PickKind.progressPhoto);
      expect(pending.ref, PhotoPose.front.wire);
    });

    test('is cleared again', () async {
      final recovery = recoveryWith(null);
      await recovery.remember(PendingPick.progressPhoto(PhotoPose.front));
      await recovery.forget();

      expect(await recovery.pending(), isNull);
    });

    test('names the exercise and the slot for a frame', () async {
      final recovery = recoveryWith(null);
      await recovery.remember(
        PendingPick.exerciseFrame(exerciseId: 'own-1', isStart: false),
      );

      final slot = ExerciseFrameSlot.parse((await recovery.pending())!.ref);
      expect(slot!.exerciseId, 'own-1');
      expect(slot.isStart, isFalse);
    });

    test('has no exercise while one is still being created', () {
      final ref = PendingPick.exerciseFrame(
        exerciseId: null,
        isStart: true,
      ).ref;
      expect(ExerciseFrameSlot.parse(ref), isNull);
    });
  });

  group('recovering', () {
    test('does nothing when no photo comes back', () async {
      expect(await recoveryWith(null).recover(), PickRecoveryOutcome.nothing);
    });

    test('clears a stale note when the pick was simply cancelled', () async {
      final recovery = recoveryWith(null);
      await recovery.remember(PendingPick.progressPhoto(PhotoPose.front));

      await recovery.recover();

      expect(await recovery.pending(), isNull);
    });

    test('a file without a note has nowhere to go', () async {
      final lost = writeSourceImage(cache, 'lost.jpg');
      expect(
        await recoveryWith(lost).recover(),
        PickRecoveryOutcome.orphaned,
      );
      expect(await db.recordsDao.photos(), isEmpty);
    });

    test('a lost progress photo lands in the grid', () async {
      final lost = writeSourceImage(cache, 'lost.jpg');
      final recovery = recoveryWith(lost);
      await recovery.remember(PendingPick.progressPhoto(PhotoPose.side));

      expect(await recovery.recover(), PickRecoveryOutcome.recovered);

      final photos = await db.recordsDao.photos();
      expect(photos, hasLength(1));
      expect(photos.single.pose, PhotoPose.side.wire);
      expect(await File(paths.photoFile(photos.single.fileName).path).exists(),
          isTrue);
      expect(await recovery.pending(), isNull);
    });

    test('a lost frame lands on its exercise', () async {
      final id = await makeExercise();
      final lost = writeSourceImage(cache, 'lost.jpg');
      final recovery = recoveryWith(lost);
      await recovery.remember(
        PendingPick.exerciseFrame(exerciseId: id, isStart: false),
      );

      expect(await recovery.recover(), PickRecoveryOutcome.recovered);

      final row = await db.exercisesDao.getById(id);
      expect(row!.endImageFile, isNotNull);
      expect(row.startImageFile, isNull);
      expect(await File(paths.photoFile(row.endImageFile!).path).exists(),
          isTrue);
    });

    test('a frame for an exercise that was never saved is let go', () async {
      final lost = writeSourceImage(cache, 'lost.jpg');
      final recovery = recoveryWith(lost);
      await recovery.remember(
        PendingPick.exerciseFrame(exerciseId: null, isStart: true),
      );

      expect(await recovery.recover(), PickRecoveryOutcome.unplaceable);
      expect(await recovery.pending(), isNull);
    });

    test('a frame for an exercise that is gone is let go', () async {
      final lost = writeSourceImage(cache, 'lost.jpg');
      final recovery = recoveryWith(lost);
      await recovery.remember(
        PendingPick.exerciseFrame(exerciseId: 'verdwenen', isStart: true),
      );

      expect(await recovery.recover(), PickRecoveryOutcome.unplaceable);
    });

    test('the recovered photo is processed like any other', () async {
      final lost = writeSourceImage(cache, 'lost.jpg', width: 3000, height: 2000);
      final recovery = recoveryWith(lost);
      await recovery.remember(PendingPick.progressPhoto(PhotoPose.front));
      await recovery.recover();

      final photo = (await db.recordsDao.photos()).single;
      final stored = paths.photoFile(photo.fileName);
      expect(stored.lengthSync(), lessThan(lost.lengthSync()));
    });
  });
}
