import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/util/paths.dart';
import '../data/photo_library.dart';
import '../data/photo_store.dart';
import '../data/pick_recovery.dart';

part 'photo_providers.g.dart';

@riverpod
Stream<List<ProgressPhotoRow>> progressPhotos(Ref ref) =>
    ref.watch(databaseProvider).recordsDao.watchPhotos();

/// Null while the documents directory is still being resolved.
@riverpod
PhotoStore? photoStore(Ref ref) {
  final paths = ref.watch(appPathsProvider).value;
  return paths == null ? null : PhotoStore(paths);
}

// Kept alive on purpose. These objects hold a `Ref` and every one of their
// callers uses them across an async gap: a confirmation dialog, the photo
// picker, the PR configuration screen. An auto-disposing provider is torn down
// while that gap is open, and the next call throws on a dead `Ref`.
@Riverpod(keepAlive: true)
PhotoActions photoActions(Ref ref) => PhotoActions(ref);

/// The screen-facing wrapper: picking is the only part that needs a plugin,
/// everything after it is plain file and database work.
class PhotoActions {
  const PhotoActions(this.ref);

  final Ref ref;

  Future<PhotoLibrary> _library() async {
    final paths = await ref.read(appPathsProvider.future);
    return PhotoLibrary(
      db: ref.read(databaseProvider),
      store: PhotoStore(paths),
    );
  }

  /// Returns the new photo's id, or null when the user backed out.
  Future<String?> add({
    required ImageSource source,
    required PhotoPose pose,
    DateTime? takenAt,
    String? note,
  }) async {
    final recovery = await _recovery();
    await recovery.remember(PendingPick.progressPhoto(pose));
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // A generous cap keeps the decode cheap; PhotoStore does the real
        // resizing so the stored size is the same whatever the picker returns.
        maxWidth: 2400,
      );
      if (picked == null) return null;

      final library = await _library();
      return await library.importPhoto(
        source: File(picked.path),
        pose: pose,
        takenAt: takenAt,
        note: note,
      );
    } finally {
      // The note is only useful while the app is not running. Once the pick
      // has come back - or been cancelled, or thrown - it has to go, or the
      // next launch would try to place a file that is not lost.
      await recovery.forget();
    }
  }

  Future<PickRecovery> _recovery() async => PickRecovery(
    db: ref.read(databaseProvider),
    paths: await ref.read(appPathsProvider.future),
  );

  Future<void> delete(ProgressPhotoRow photo) async {
    final library = await _library();
    await library.deletePhoto(photo);
  }

  Future<AppPaths> paths() => ref.read(appPathsProvider.future);
}
