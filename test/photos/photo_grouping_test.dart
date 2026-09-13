import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/photos/domain/photo_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Photographs stacked into the months and days they were taken.
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

  group('the grouping', () {
    test('a day of its own inside a month of its own', () {
      final months = groupPhotos([photo('a', DateTime(2026, 9, 7, 10))]);

      expect(months.single.month, DateTime(2026, 9));
      expect(months.single.days.single.day, DateTime(2026, 9, 7));
      expect(months.single.days.single.photos.single.id, 'a');
    });

    test('two days in one month are two headings', () {
      final months = groupPhotos([
        photo('a', DateTime(2026, 9, 7, 10)),
        photo('b', DateTime(2026, 9, 13, 10)),
      ]);

      expect(months.single.days, hasLength(2));
      expect(months.single.photoCount, 2);
    });

    test('and photos of the same day stay together', () {
      final months = groupPhotos([
        photo('a', DateTime(2026, 9, 7, 10)),
        photo('b', DateTime(2026, 9, 7, 18)),
        photo('c', DateTime(2026, 9, 8, 10)),
      ]);

      expect(months.single.days.first.photos, hasLength(1));
      expect(months.single.days.last.photos, hasLength(2));
    });

    test('a day either side of midnight is two days', () {
      final months = groupPhotos([
        photo('a', DateTime(2026, 9, 7, 23, 59)),
        photo('b', DateTime(2026, 9, 8, 0, 1)),
      ]);

      expect(months.single.days, hasLength(2));
    });
  });

  group('the order', () {
    test('newest month first, newest day first', () {
      final months = groupPhotos([
        photo('oud', DateTime(2026, 7, 1)),
        photo('nieuw', DateTime(2026, 9, 13)),
        photo('midden', DateTime(2026, 9, 7)),
      ]);

      expect(
        [for (final m in months) m.month],
        [DateTime(2026, 9), DateTime(2026, 7)],
      );
      expect(
        [for (final d in months.first.days) d.day],
        [DateTime(2026, 9, 13), DateTime(2026, 9, 7)],
      );
    });

    test('and newest first within a day, whatever order they arrive in', () {
      // The screen reads a stream whose sort is the database's business; a
      // heading in the wrong place is worse than sorting a list this size.
      final months = groupPhotos([
        photo('ochtend', DateTime(2026, 9, 7, 8)),
        photo('avond', DateTime(2026, 9, 7, 20)),
      ]);

      expect(
        [for (final p in months.single.days.single.photos) p.id],
        ['avond', 'ochtend'],
      );
    });

    test('an empty list gives an empty list, not a stray heading', () {
      expect(groupPhotos(const []), isEmpty);
    });
  });

  group('which pose a comparison opens on', () {
    test('the one you have most of', () {
      final pose = mostComparablePose([
        photo('a', DateTime(2026, 9, 1), pose: PhotoPose.front),
        photo('b', DateTime(2026, 9, 2), pose: PhotoPose.back),
        photo('c', DateTime(2026, 9, 3), pose: PhotoPose.back),
      ]);

      expect(pose, PhotoPose.back);
    });

    test('a tie does not depend on which photo was read first', () {
      final one = [
        photo('a', DateTime(2026, 9, 1), pose: PhotoPose.side),
        photo('b', DateTime(2026, 9, 2), pose: PhotoPose.back),
      ];

      expect(mostComparablePose(one), mostComparablePose(one.reversed));
    });

    test('with nothing at all it still answers', () {
      expect(mostComparablePose(const []), PhotoPose.front);
    });

    test('the counts say in advance what there is to compare', () {
      final counts = photosPerPose([
        photo('a', DateTime(2026, 9, 1), pose: PhotoPose.front),
        photo('b', DateTime(2026, 9, 2), pose: PhotoPose.front),
      ]);

      expect(counts[PhotoPose.front], 2);
      expect(counts[PhotoPose.side], 0);
      expect(counts[PhotoPose.back], 0);
    });
  });
}
