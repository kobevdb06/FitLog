/// Photographs stacked into the months and days they were taken.
///
/// A month on its own was too coarse: four pictures under "SEPTEMBER 2026"
/// with the date written on every tile, which is the grid saying the same
/// thing four times and still leaving you to work out which belong together.
///
/// Pure Dart, so the shape of the list can be checked without a screen.
library;

import '../../../core/db/database.dart';

/// One day's photographs.
class PhotoDay {
  const PhotoDay({required this.day, required this.photos});

  /// Midnight of the day itself.
  final DateTime day;

  final List<ProgressPhotoRow> photos;
}

/// One month's days.
class PhotoMonth {
  const PhotoMonth({required this.month, required this.days});

  /// The first of the month.
  final DateTime month;

  final List<PhotoDay> days;

  int get photoCount {
    var total = 0;
    for (final day in days) {
      total += day.photos.length;
    }
    return total;
  }
}

/// Groups [photos] by month and then by day, newest first throughout.
///
/// The order does not depend on the order they arrive in: the screen reads a
/// stream whose sort is the database's business, and a heading in the wrong
/// place is worse than a slow sort of a list this size.
List<PhotoMonth> groupPhotos(Iterable<ProgressPhotoRow> photos) {
  final byDay = <DateTime, List<ProgressPhotoRow>>{};
  for (final photo in photos) {
    final at = DateTime.fromMillisecondsSinceEpoch(photo.takenAt);
    final day = DateTime(at.year, at.month, at.day);
    byDay.putIfAbsent(day, () => []).add(photo);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  final months = <DateTime, List<PhotoDay>>{};
  for (final day in days) {
    final photosOfDay = byDay[day]!
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    months
        .putIfAbsent(DateTime(day.year, day.month), () => [])
        .add(PhotoDay(day: day, photos: photosOfDay));
  }

  final ordered = months.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final month in ordered) PhotoMonth(month: month, days: months[month]!),
  ];
}

/// How many photographs there are of each pose.
Map<PhotoPose, int> photosPerPose(Iterable<ProgressPhotoRow> photos) {
  final counts = {for (final pose in PhotoPose.values) pose: 0};
  for (final photo in photos) {
    final pose = PhotoPose.fromWire(photo.pose);
    counts[pose] = counts[pose]! + 1;
  }
  return counts;
}

/// The pose a comparison should open on: the one you have most of.
///
/// Ties go to the order the poses are declared in, so the answer does not
/// depend on which photo happened to be read first. Falls back to the front,
/// which is the one people take.
PhotoPose mostComparablePose(Iterable<ProgressPhotoRow> photos) {
  final counts = photosPerPose(photos);
  var best = PhotoPose.values.first;
  for (final pose in PhotoPose.values) {
    if (counts[pose]! > counts[best]!) best = pose;
  }
  return best;
}
