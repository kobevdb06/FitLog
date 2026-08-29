import 'dart:io';

import '../../../core/db/database.dart';
import 'photo_store.dart';

/// Ties the photo files to their rows.
///
/// The two must stay in step: a row without a file shows a broken tile, and a
/// file without a row is dead weight that also ends up in every backup.
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
    final known = {for (final row in rows) row.fileName};

    final result = await store.reconcile(known);

    for (final row in rows) {
      if (result.missingFiles.contains(row.fileName)) {
        await db.recordsDao.deletePhoto(row.id);
      }
    }
    return result;
  }
}
