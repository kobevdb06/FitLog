import 'dart:io';
import 'dart:typed_data';

import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:fitlog/features/photos/data/picked_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Where a photo was taken does not leave the phone (DECISIONS 247).
///
/// Baking the orientation in kept every other EXIF tag, the JPEG encoder
/// wrote them back - the location included - and the coach sent the stored
/// file to Google as it was.
void main() {
  /// A small camera photo, with where it was taken in it.
  Uint8List withLocation() {
    final image = img.Image(width: 64, height: 48);
    img.fill(image, color: img.ColorRgb8(200, 80, 40));
    image.exif.gpsIfd.setGpsLocation(latitude: 50.8798, longitude: 4.7005);
    image.exif.imageIfd['Make'] = img.IfdValueAscii('Telefoon');
    return img.encodeJpg(image);
  }

  test('the photo made for this test has a location in it', () {
    final decoded = img.decodeJpg(withLocation())!;
    expect(decoded.exif.gpsIfd.gpsLatitude, closeTo(50.88, 0.01));
  });

  test('a stored photo keeps no location, nor anything else of the camera', () {
    final stored = PhotoStore.processBytes(withLocation());

    final decoded = img.decodeJpg(stored)!;
    expect(decoded.exif.gpsIfd.isEmpty, isTrue);
    expect(decoded.exif.isEmpty, isTrue);
  });

  test('one stored before is sent without it, its pixels untouched', () {
    final before = withLocation();

    final sent = stripJpegMetadata(before);

    final decoded = img.decodeJpg(sent)!;
    expect(decoded.exif.isEmpty, isTrue);
    final original = img.decodeJpg(before)!;
    expect(decoded.width, original.width);
    expect(decoded.getPixel(10, 10), original.getPixel(10, 10));
    expect(sent.length, lessThan(before.length));
  });

  test('what is not a JPEG is sent as it is', () {
    final png = img.encodePng(img.Image(width: 4, height: 4));
    expect(stripJpegMetadata(png), png);
    final broken = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
    expect(stripJpegMetadata(broken), broken);
  });

  group('the copy the picker hands over', () {
    late Directory cache;
    late Directory elsewhere;

    setUp(() async {
      cache = await Directory.systemTemp.createTemp('fitlog_cache');
      elsewhere = await Directory.systemTemp.createTemp('fitlog_elders');
    });

    tearDown(() async {
      for (final dir in [cache, elsewhere]) {
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    });

    test('goes once it is stored', () async {
      final copy = File('${cache.path}/image_picker_1.jpg')
        ..writeAsBytesSync(withLocation());

      await forgetPickedCopy(copy.path, cache: () async => cache);

      expect(copy.existsSync(), isFalse);
    });

    test('a file anywhere else is never touched', () async {
      final own = File('${elsewhere.path}/vakantie.jpg')
        ..writeAsBytesSync(withLocation());

      await forgetPickedCopy(own.path, cache: () async => cache);

      expect(own.existsSync(), isTrue);
    });
  });
}
