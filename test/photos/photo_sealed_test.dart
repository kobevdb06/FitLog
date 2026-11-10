import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fitlog/core/security/key_material.dart';
import 'package:fitlog/core/security/photo_crypto.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/core/widgets/photo_image.dart';
import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'photo_store_test.dart' show writeSourceImage;

/// Photos sealed on the phone, as the database is (DECISIONS 257).
///
/// They lay in the photo folder as plain JPEGs, behind nothing - a PIN kept
/// only the database shut - while the privacy page said they were
/// encrypted.
void main() {
  late Directory home;
  late Directory cache;
  late AppPaths paths;
  late Uint8List dek;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('fitlog_sealed');
    cache = await Directory.systemTemp.createTemp('fitlog_sealed_src');
    paths = AppPaths(home);
    dek = generateDek();
  });

  tearDown(() async {
    PhotoKey.current = null;
    for (final dir in [home, cache]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  bool isJpeg(List<int> bytes) =>
      bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  test('a stored photo is sealed, and opens with the key', () async {
    final store = PhotoStore(paths, key: dek);

    final name = await store.import(writeSourceImage(cache, 'a.jpg'));

    final onDisk = await store.fileFor(name).readAsBytes();
    expect(isJpeg(onDisk), isFalse, reason: 'no JPEG lies in the folder');
    expect(PhotoCrypto.isSealed(onDisk), isTrue);
    final opened = (await store.readBytes(name))!;
    expect(isJpeg(opened), isTrue);
    expect(img.decodeJpg(opened)!.width, PhotoStore.maxLongEdge * 2 ~/ 3);
  });

  test('another key, or none - locked - does not open it', () async {
    final name = await PhotoStore(
      paths,
      key: dek,
    ).import(writeSourceImage(cache, 'a.jpg'));

    await expectLater(
      PhotoStore(paths, key: generateDek()).readBytes(name),
      throwsA(isA<PhotoUnreadableException>()),
    );
    await expectLater(
      PhotoStore(paths).readBytes(name),
      throwsA(isA<PhotoUnreadableException>()),
    );
  });

  test(
    'a photo from before is read as it is, and sealed in its turn',
    () async {
      final plain = await PhotoStore(paths)
          .import(writeSourceImage(cache, 'a.jpg'));
      final store = PhotoStore(paths, key: dek);
      expect(isJpeg(await store.fileFor(plain).readAsBytes()), isTrue);
      expect(isJpeg((await store.readBytes(plain))!), isTrue);

      expect(await store.sealAll(), 1);
      expect(await store.sealAll(), 0, reason: 'once is enough');

      expect(
        PhotoCrypto.isSealed(await store.fileFor(plain).readAsBytes()),
        isTrue,
      );
      expect(isJpeg((await store.readBytes(plain))!), isTrue);
      expect(
        paths.photosDirectory.listSync().where((f) => f.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );

  test('one of its own photos as the source of another opens first', () async {
    final store = PhotoStore(paths, key: dek);
    final sent = await store.import(writeSourceImage(cache, 'a.jpg'));

    final frame = await store.import(store.fileFor(sent), maxLongEdge: 720);

    expect(img.decodeJpg((await store.readBytes(frame))!)!.height, 720);
  });

  testWidgets('shown on screen, opened on the way', (tester) async {
    late String name;
    await tester.runAsync(() async {
      name = await PhotoStore(
        paths,
        key: dek,
      ).import(writeSourceImage(cache, 'a.jpg', width: 40, height: 60));
    });
    PhotoKey.current = dek;

    final image = PhotoImage(paths.photoFile(name));
    await tester.runAsync(() async {
      final stream = image.resolve(ImageConfiguration.empty);
      final done = Completer<ImageInfo>();
      stream.addListener(
        ImageStreamListener(
          (info, _) => done.complete(info),
          onError: (error, stack) => done.completeError(error, stack),
        ),
      );
      final info = await done.future;
      expect(info.image.width, 40);
    });
  });
}
