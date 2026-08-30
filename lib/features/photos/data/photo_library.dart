import 'dart:io';

import '../../../core/db/database.dart';
import 'photo_store.dart';

/// Ties the image files to the rows that point at them.
///
/// The two must stay in step: a row without a file shows a broken tile, and a
/// file without a row is dead weight that also ends up in every backup.
///
/// Two kinds of row point into this directory - progress photos and the two
/// frames of a user-made exercise - and the reconcile has to know about both,
/// or it deletes one of them as an orphan.
class PhotoLibrary {
  const PhotoLibrary({required this.db, required this.store});

  final AppDatabase db;
  final PhotoStore store;

  /// Copies [source] into the photo directory and only then writes the row.
  ///
  /// That order matters: a row that points at a file which was never written
  /// is worse than a file nobody references, because the second is cleaned up
  /// automatically and the first shows up as a hole in the grid.
  Future<String> importPhoto({
    required File source,
    required PhotoPose pose,
    DateTime? takenAt,
    String? note,
  }) async {
    final fileName = await store.import(source);
    return db.recordsDao.addPhoto(
      fileName: fileName,
      pose: pose,
      takenAt: takenAt ?? DateTime.now(),
      note: note,
    );
  }

  /// Removes the file first, then the row.
  Future<void> deletePhoto(ProgressPhotoRow photo) async {
    await store.deleteFile(photo.fileName);
    await db.recordsDao.deletePhoto(photo.id);
  }

  /// Runs at startup: deletes files nothing points at, and drops rows whose
  /// file is gone.
  Future<PhotoCleanupResult> cleanup() async {
    final rows = await db.recordsDao.photos();
    final frames = await db.exercisesDao.imageFileNames();
    final known = {for (final row in rows) row.fileName, ...frames};

    final result = await store.reconcile(known);

    for (final row in rows) {
      if (result.missingFiles.contains(row.fileName)) {
        await db.recordsDao.deletePhoto(row.id);
      }
    }
    // An exercise outlives its pictures: only the reference is cleared, so the
    // exercise itself and every workout that used it stay put.
    for (final fileName in result.missingFiles) {
      if (frames.contains(fileName)) {
        await db.exercisesDao.clearImageFile(fileName);
      }
    }
    return result;
  }
}
