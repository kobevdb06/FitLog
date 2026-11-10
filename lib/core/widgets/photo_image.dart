import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../security/photo_crypto.dart';

/// A photo from the photo folder, opened with the database key before it is
/// decoded: [Image.file] for a file that may be sealed (DECISIONS 257). A
/// plain one from before is shown as it is.
@immutable
class PhotoImage extends ImageProvider<PhotoImage> {
  const PhotoImage(this.file, {this.scale = 1.0});

  final File file;
  final double scale;

  @override
  Future<PhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<PhotoImage>(this);

  @override
  ImageStreamCompleter loadImage(PhotoImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: key.scale,
        debugLabel: key.file.path,
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    // Read at once: a few hundred kilobytes, done before the handle could
    // outlive the picture it was for. The opening, which takes long, goes
    // to its own isolate.
    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) {
      // As FileImage does: an empty file is no picture, and not cached.
      PaintingBinding.instance.imageCache.evict(this);
      throw StateError('$file is leeg');
    }
    final opened = await PhotoCrypto.open(bytes, PhotoKey.current);
    return decode(await ui.ImmutableBuffer.fromUint8List(opened));
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoImage &&
      other.file.path == file.path &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(file.path, scale);

  @override
  String toString() => 'PhotoImage("${file.path}", scale: $scale)';
}

/// [Image.file], for a photo that may be sealed: the same arguments, the
/// picture opened first.
Image photoImage(
  File file, {
  double? width,
  double? height,
  BoxFit? fit,
  int? cacheWidth,
  int? cacheHeight,
  bool gaplessPlayback = false,
  ImageErrorWidgetBuilder? errorBuilder,
}) => Image(
  image: ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, PhotoImage(file)),
  width: width,
  height: height,
  fit: fit,
  gaplessPlayback: gaplessPlayback,
  errorBuilder: errorBuilder,
);
