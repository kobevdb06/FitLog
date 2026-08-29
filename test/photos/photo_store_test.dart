import 'dart:io';

import 'package:drift/native.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/photos/data/photo_library.dart';
import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Stands in for the system cache directory that `image_picker` writes to.
File writeSourceImage(
  Directory dir,
  String name, {
  int width = 2000,
  int height = 3000,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 30, 30));
  final file = File('${dir.path}/$name')
    ..writeAsBytesSync(img.encodeJpg(image, quality: 95));
  return file;
}

void main() {
  late Directory root;
  late Directory cache;
  late AppPaths paths;
  late PhotoStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fitlog_photos');
    cache = await Directory.systemTemp.createTemp('fitlog_cache');
    paths = AppPaths(root);
    store = PhotoStore(paths);
  });

  tearDown(() async {
    for (final dir in [root, cache]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  group('import', () {
    test('copies out of the source directory instead of referencing it',
        () async {
      final source = writeSourceImage(cache, 'picked.jpg');
      final fileName = await store.import(source);

      expect(await store.exists(fileName), isTrue);
      expect(
        store.fileFor(fileName).path,
        startsWith(paths.photosDirectory.path),
      );

      // The picker's file lives in a cache the OS empties whenever it likes.
      await source.delete();
      expect(await store.exists(fileName), isTrue);
    });

    test('stores only a file name, never a path', () async {
      final fileName = await store.import(writeSourceImage(cache, 'a.jpg'));

      expect(fileName, isNot(contains(Platform.pathSeparator)));
      expect(fileName, isNot(contains('/')));
      expect(fileName, endsWith('.jpg'));
      // The directory is resolved again on every read, so a container that
      // moves (an iOS update) cannot break the reference.
      expect(fileName, isNot(contains(root.path)));
    });

    test('creates the photo directory when it does not exist yet', () async {
      expect(await paths.photosDirectory.exists(), isFalse);
      await store.import(writeSourceImage(cache, 'a.jpg'));
      expect(await paths.photosDirectory.exists(), isTrue);
    });

    test('two imports never collide', () async {
      final first = await store.import(writeSourceImage(cache, 'a.jpg'));
      final second = await store.import(writeSourceImage(cache, 'b.jpg'));
      expect(first, isNot(second));
      expect(await store.exists(first), isTrue);
      expect(await store.exists(second), isTrue);
    });

    test('an unreadable file is rejected rather than stored', () async {
      final broken = File('${cache.path}/broken.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);
      await expectLater(
        store.import(broken),
        throwsA(isA<UnreadableImageException>()),
      );
      // Nothing half-written is left behind.
      expect(await store.storedFileNames(), isEmpty);
    });
  });

  group('processing', () {
    test('scales the long edge down to 1440', () {
      final source = writeSourceImage(cache, 'big.jpg', width: 2000, height: 3000);
      final out = PhotoStore.processBytes(source.readAsBytesSync());
      final decoded = img.decodeImage(out)!;

      expect(decoded.height, PhotoStore.maxLongEdge);
      // Aspect ratio is kept.
      expect(decoded.width, closeTo(1440 * 2000 / 3000, 2));
    });

    test('leaves a small photo alone', () {
      final source = writeSourceImage(cache, 'small.jpg', width: 400, height: 600);
      final decoded = img.decodeImage(
        PhotoStore.processBytes(source.readAsBytesSync()),
      )!;
      expect(decoded.width, 400);
      expect(decoded.height, 600);
    });

    test('a 4 MB camera photo shrinks a lot', () async {
      final source = writeSourceImage(cache, 'camera.jpg', width: 4000, height: 3000);
      final fileName = await store.import(source);
      final stored = await store.fileFor(fileName).length();

      expect(stored, lessThan(source.lengthSync()));
      expect(stored, lessThan(1024 * 1024));
    });

    test('bakes the EXIF orientation into the pixels', () {
      // Orientation 6 means "rotate 90 degrees clockwise on display".
      final landscape = img.Image(width: 1200, height: 600);
      img.fill(landscape, color: img.ColorRgb8(10, 200, 10));
      landscape.exif.imageIfd.orientation = 6;

      final decoded = img.decodeImage(
        PhotoStore.processBytes(img.encodeJpg(landscape)),
      )!;

      // After baking, the stored pixels are upright: what was 1200x600 with a
      // rotate flag becomes 600x1200 without one.
      expect(decoded.width, 600);
      expect(decoded.height, 1200);
    });
  });

  group('cleanup', () {
    late AppDatabase db;
    late PhotoLibrary library;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.settingsDao.ensureInitialized();
      library = PhotoLibrary(db: db, store: store);
    });

    tearDown(() async => db.close());

    test('a photo survives a restart', () async {
      final id = await library.importPhoto(
        source: writeSourceImage(cache, 'a.jpg'),
        pose: PhotoPose.front,
      );

      // A cold start reconciles files against rows before anything is shown.
      final result = await library.cleanup();
      expect(result.isClean, isTrue);

      final rows = await db.recordsDao.photos();
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(await store.exists(rows.single.fileName), isTrue);
    });

    test('deleting removes the file and the row, leaving no orphan', () async {
      await library.importPhoto(
        source: writeSourceImage(cache, 'a.jpg'),
        pose: PhotoPose.back,
      );
      final photo = (await db.recordsDao.photos()).single;

      await library.deletePhoto(photo);

      expect(await store.exists(photo.fileName), isFalse);
      expect(await db.recordsDao.photos(), isEmpty);
      expect(await store.storedFileNames(), isEmpty);
    });

    test('a file without a row is removed at startup', () async {
      await paths.ensurePhotosDirectory();
      File('${paths.photosDirectory.path}/wees.jpg')
          .writeAsBytesSync(img.encodeJpg(img.Image(width: 10, height: 10)));

      final result = await library.cleanup();

      expect(result.deletedFiles, contains('wees.jpg'));
      expect(await store.storedFileNames(), isEmpty);
    });

    test('a row without a file is dropped at startup', () async {
      await library.importPhoto(
        source: writeSourceImage(cache, 'a.jpg'),
        pose: PhotoPose.side,
      );
      final photo = (await db.recordsDao.photos()).single;

      // Simulate the file disappearing underneath the row.
      await store.deleteFile(photo.fileName);

      final result = await library.cleanup();
      expect(result.missingFiles, contains(photo.fileName));
      expect(await db.recordsDao.photos(), isEmpty);
    });

    test('cleanup leaves a healthy library untouched', () async {
      for (var i = 0; i < 3; i++) {
        await library.importPhoto(
          source: writeSourceImage(cache, 'p$i.jpg'),
          pose: PhotoPose.front,
        );
      }
      final result = await library.cleanup();

      expect(result.isClean, isTrue);
      expect(await db.recordsDao.photos(), hasLength(3));
      expect(await store.storedFileNames(), hasLength(3));
    });
  });
}
