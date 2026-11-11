import 'dart:io';

import '../db/database.dart';
import 'photo_store.dart';

/// Ties the image files to the rows that point at them.
///
/// The two must stay in step: a row without a file shows a broken tile, and a
/// file without a row is dead weight that also ends up in every backup.
///
/// Three kinds of row point into this directory - progress photos, the two
/// frames of a user-made exercise, and a photo sent to the coach - and the
/// reconcile has to know about all of them, or it deletes one as an orphan.
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

  /// Runs at startup: deletes files nothing points at. A row whose file is
  /// gone stays: its pose, date, note and workout are kept, and the screen
  /// shows that the picture itself is missing. It used to be dropped - after
  /// a restore that did not bring every photo back, all that went too
  /// (DECISIONS 258). Deleting it is the user's.
  Future<PhotoCleanupResult> cleanup() async {
    final rows = await db.recordsDao.photos();
    final frames = await db.exercisesDao.imageFileNames();
    // A photo asked about in the chat lives here too.
    final asked = await db.chatDao.imageFileNames();
    final known = {for (final row in rows) row.fileName, ...frames, ...asked};

    return store.reconcile(known);
  }
}
