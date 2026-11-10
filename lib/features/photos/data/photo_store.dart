import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../core/util/paths.dart';
import '../../../core/security/photo_crypto.dart';

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
///
/// Every file it writes is sealed with the database key while the app is
/// open (DECISIONS 257); [key] stands in for that key in a test.
class PhotoStore {
  const PhotoStore(this.paths, {this._key});

  final AppPaths paths;
  final Uint8List? _key;

  /// The key files are sealed and opened with: none while the app is locked.
  Uint8List? get key => _key ?? PhotoKey.current;

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
  ///
  /// [maxLongEdge] defaults to the size a progress photo is kept at; an
  /// exercise frame is never shown larger than a card and asks for less.
  ///
  /// [source] may be one of the app's own sealed photos - one sent to the
  /// coach, put on an exercise: it is opened first.
  Future<String> import(File source, {int? maxLongEdge}) async {
    final bytes = await PhotoCrypto.open(await source.readAsBytes(), key);
    final processed = await _process(
      bytes,
      maxLongEdge ?? PhotoStore.maxLongEdge,
    );
    return _write(processed);
  }

  /// The same, for an image that never was a file: one that arrived over the
  /// network rather than out of a camera.
  Future<String> importBytes(Uint8List bytes, {int? maxLongEdge}) async {
    final processed = await _process(
      bytes,
      maxLongEdge ?? PhotoStore.maxLongEdge,
    );
    return _write(processed);
  }

  /// [jpeg] into the photo directory under a new name, sealed when there is
  /// a key - which there is whenever the app is open.
  Future<String> _write(Uint8List jpeg) async {
    final current = key;
    final stored = current == null
        ? jpeg
        : await PhotoCrypto.seal(jpeg, current);
    final dir = await paths.ensurePhotosDirectory();
    final fileName = '${_uuid.v4()}.jpg';
    await File('${dir.path}/$fileName').writeAsBytes(stored, flush: true);
    return fileName;
  }

  /// The picture of [fileName], opened: what leaves the phone or is shown.
  /// Null when the file is gone; an error while the app is locked.
  Future<Uint8List?> readBytes(String fileName) async {
    final file = fileFor(fileName);
    if (!await file.exists()) return null;
    return PhotoCrypto.open(await file.readAsBytes(), key);
  }

  /// Seals every photo that is still plain: those from before photos were
  /// sealed, and those a backup of that time brought back. In place, and
  /// whole - written next to it and moved over it - so a crash halfway
  /// leaves the plain one or the sealed one. Returns how many it sealed.
  Future<int> sealAll() async {
    final current = key;
    final dir = paths.photosDirectory;
    if (current == null || !await dir.exists()) return 0;
    var sealed = 0;
    await for (final entity in dir.list()) {
      if (entity is! File || entity.path.endsWith('.tmp')) continue;
      final bytes = await entity.readAsBytes();
      if (PhotoCrypto.isSealed(bytes)) continue;
      final temporary = File('${entity.path}.tmp');
      await temporary.writeAsBytes(
        await PhotoCrypto.seal(bytes, current),
        flush: true,
      );
      await temporary.rename(entity.path);
      sealed++;
    }
    return sealed;
  }

  /// Decoding and re-encoding a camera photo is heavy enough to drop frames,
  /// so it happens on its own isolate.
  static Future<Uint8List> _process(Uint8List bytes, int maxLongEdge) =>
      Isolate.run(() => processBytes(bytes, maxLongEdge: maxLongEdge));

  /// Bakes the EXIF orientation into the pixels, scales the long edge down to
  /// [maxLongEdge] and re-encodes as JPEG - without any of the camera's
  /// metadata.
  ///
  /// Baking kept every EXIF tag but the orientation, and the encoder wrote
  /// them back: where the photo was taken went along to the coach, and to
  /// Google (DECISIONS 247).
  ///
  /// Camera photos carry their rotation in an EXIF tag that `Image.file` does
  /// not apply, so without baking they show up on their side.
  static Uint8List processBytes(Uint8List bytes, {int? maxLongEdge}) {
    final limit = maxLongEdge ?? PhotoStore.maxLongEdge;
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

    final sized = longEdge <= limit
        ? upright
        : img.copyResize(
            upright,
            width: upright.width >= upright.height ? limit : null,
            height: upright.height > upright.width ? limit : null,
            interpolation: img.Interpolation.average,
          );

    sized.exif = img.ExifData();
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

/// [jpeg] without its metadata: every APP1 segment - EXIF, with where the
/// photo was taken, and XMP - and every comment taken out, the picture
/// itself copied byte for byte. For photos stored before metadata was taken
/// out at the import, as they leave the phone (DECISIONS 247).
///
/// Anything that is not a JPEG it can read to the image comes back as it
/// was.
Uint8List stripJpegMetadata(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) return jpeg;
  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var at = 2;
  while (at + 4 <= jpeg.length) {
    if (jpeg[at] != 0xFF) return jpeg;
    final marker = jpeg[at + 1];
    // The image data starts here and runs to the end: copied whole.
    if (marker == 0xDA) {
      out.add(Uint8List.sublistView(jpeg, at));
      return out.takeBytes();
    }
    final length = (jpeg[at + 2] << 8) | jpeg[at + 3];
    if (length < 2 || at + 2 + length > jpeg.length) return jpeg;
    final end = at + 2 + length;
    // APP1 holds EXIF and XMP; COM a free comment.
    if (marker != 0xE1 && marker != 0xFE) {
      out.add(Uint8List.sublistView(jpeg, at, end));
    }
    at = end;
  }
  return jpeg;
}
