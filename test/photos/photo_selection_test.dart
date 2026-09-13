import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/photos/domain/photo_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which photographs a comparison is made of.
void main() {
  ProgressPhotoRow photo(
    String id,
    DateTime at, {
    PhotoPose pose = PhotoPose.front,
  }) => ProgressPhotoRow(
    id: id,
    takenAt: at.millisecondsSinceEpoch,
    fileName: '$id.jpg',
    pose: pose.wire,
  );

  final newestFirst = [
    photo('c', DateTime(2026, 9, 13)),
    photo('b', DateTime(2026, 9, 7)),
    photo('a', DateTime(2026, 9, 1)),
  ];

  group('what is chosen', () {
    test('comes back in the order they were taken, not tapped', () {
      final chosen = chosenPhotos(all: newestFirst, ids: ['c', 'a']);

      expect([for (final p in chosen) p.id], ['a', 'c']);
    });

    test('an id of a photo that is gone is dropped, not a hole', () {
      // The ids travel in the address, so they can outlive the picture.
      final chosen = chosenPhotos(all: newestFirst, ids: ['a', 'weg', 'c']);

      expect([for (final p in chosen) p.id], ['a', 'c']);
    });

    test('nothing chosen is nothing to compare', () {
      expect(chosenPhotos(all: newestFirst, ids: const []), isEmpty);
    });
  });

  group('what the grid ticks to begin with', () {
    test('the two newest of the pose you have most of', () {
      final ids = defaultComparison(newestFirst);

      expect(ids, ['c', 'b']);
    });

    test('and it skips the poses you barely have', () {
      final ids = defaultComparison([
        photo('back-2', DateTime(2026, 9, 13), pose: PhotoPose.back),
        photo('front', DateTime(2026, 9, 10)),
        photo('back-1', DateTime(2026, 9, 1), pose: PhotoPose.back),
      ]);

      expect(ids, ['back-2', 'back-1']);
    });

    test('with one photo there is nothing to start from', () {
      expect(defaultComparison([newestFirst.first]), hasLength(1));
      expect(defaultComparison(const []), isEmpty);
    });
  });

  group('poses in one comparison', () {
    test('the same one twice is nothing to say', () {
      expect(mixedPoses(newestFirst), isFalse);
    });

    test('two different ones is', () {
      expect(
        mixedPoses([
          photo('a', DateTime(2026, 9, 1)),
          photo('b', DateTime(2026, 9, 2), pose: PhotoPose.side),
        ]),
        isTrue,
      );
    });
  });
}
