import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../core/util/paths.dart';

/// Thrown when a picked file cannot be decoded as an image.
///
/// package:image probes format after format and lets a low level `RangeError`
/// escape on garbage input. That is not something a caller can act on, so it
/// is converted here into one typed failure the UI can explain. The error is
/// replaced, never swallowed: [import] still fails.
class UnreadableImageException implements Exception {
  const UnreadableImageException([this.cause]);

  final Object? cause;

  @override
  String toString() =>
      'UnreadableImageException: dit bestand is geen leesbare afbeelding'
      '${cause == null ? '' : ' ($cause)'}';
}

/// Owns the progress-photo files on disk.
///
/// Two rules make this survive a restart and an app update:
///
/// 1. The picker hands back a file in the system cache directory, which the OS
///    deletes whenever it feels like it. Every import is therefore **copied**
///    into the app's own documents directory before anything is written to the
///    database.
/// 2. Only the **file name** is stored. The directory is resolved again on
///    every read, because on iOS the app container UUID changes on update and
///    reinstall, which would turn any stored absolute path into a dead one.
class PhotoStore {
  const PhotoStore(this.paths);

  final AppPaths paths;

  static const _uuid = Uuid();

  /// The long edge a stored photo is scaled down to.
  static const int maxLongEdge = 1440;

  /// JPEG quality of a stored photo.
  static const int jpegQuality = 85;

  File fileFor(String fileName) => paths.photoFile(fileName);

  Future<bool> exists(String fileName) => fileFor(fileName).exists();

  /// Copies [source] into the photo directory, corrected and compressed.
  ///
  /// Returns the file name to store in `progress_photos.file_name`.
  Future<String> import(File source) async {
    final bytes = await source.readAsBytes();
    final processed = await _process(bytes);

    final dir = await paths.ensurePhotosDirectory();
    final fileName = '${_uuid.v4()}.jpg';
    await File('${dir.path}/$fileName').writeAsBytes(processed, flush: true);
    return fileName;
  }

  /// Decoding and re-encoding a camera photo is heavy enough to drop frames,
  /// so it happens on its own isolate.
  static Future<Uint8List> _process(Uint8List bytes) =>
      Isolate.run(() => processBytes(bytes));

  /// Bakes the EXIF orientation into the pixels, scales the long edge down to
  /// [maxLongEdge] and re-encodes as JPEG.
  ///
  /// Camera photos carry their rotation in an EXIF tag that `Image.file` does
  /// not apply, so without baking they show up on their side.
  static Uint8List processBytes(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object catch (error) {
      throw UnreadableImageException(error);
    }
    if (decoded == null) throw const UnreadableImageException();

    final upright = img.bakeOrientation(decoded);
    final longEdge = upright.width > upright.height
        ? upright.width
        : upright.height;

    final sized = longEdge <= maxLongEdge
        ? upright
        : img.copyResize(
            upright,
            width: upright.width >= upright.height ? maxLongEdge : null,
            height: upright.height > upright.width ? maxLongEdge : null,
            interpolation: img.Interpolation.average,
          );

    return img.encodeJpg(sized, quality: jpegQuality);
  }

  Future<void> deleteFile(String fileName) async {
    final file = fileFor(fileName);
    if (await file.exists()) await file.delete();
  }

  /// Every file currently in the photo directory.
  Future<Set<String>> storedFileNames() async {
    final dir = paths.photosDirectory;
    if (!await dir.exists()) return const {};
    final names = <String>{};
    await for (final entity in dir.list()) {
      if (entity is File) names.add(entity.uri.pathSegments.last);
    }
    return names;
  }

  /// Compares the files on disk with the file names the database knows about.
  ///
  /// Orphan files are deleted straight away; orphan rows are reported so the
  /// caller can remove them from the database.
  Future<PhotoCleanupResult> reconcile(Set<String> knownFileNames) async {
    final onDisk = await storedFileNames();

    final orphanFiles = onDisk.difference(knownFileNames);
    for (final name in orphanFiles) {
      await deleteFile(name);
    }

    return PhotoCleanupResult(
      deletedFiles: orphanFiles,
      missingFiles: knownFileNames.difference(onDisk),
    );
  }
}

class PhotoCleanupResult {
  const PhotoCleanupResult({
    required this.deletedFiles,
    required this.missingFiles,
  });

  /// Files that were on disk without a row, and have been removed.
  final Set<String> deletedFiles;

  /// File names a row points at that are not on disk. Those rows are stale.
  final Set<String> missingFiles;

  bool get isClean => deletedFiles.isEmpty && missingFiles.isEmpty;
}
