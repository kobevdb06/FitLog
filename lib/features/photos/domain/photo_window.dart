/// Which sessions sit close enough to a photograph to have been the reason
/// for it.
///
/// Pure Dart: the arithmetic is the whole decision, and it is worth pinning
/// down without a database or a widget in the way.
library;

/// How far either side of a photo's day to look.
///
/// You photograph yourself before or after training, not a fortnight later, so
/// a wider net would mostly offer sessions the picture has nothing to do with -
/// which is worse than offering none at all.
const Duration kPhotoWorkoutWindow = Duration(days: 1);

/// The half-open range `[from, to)` a photo taken at [takenAt] looks in.
({DateTime from, DateTime to}) workoutWindowFor(DateTime takenAt) {
  final day = DateTime(takenAt.year, takenAt.month, takenAt.day);
  return (
    from: day.subtract(kPhotoWorkoutWindow),
    to: day.add(const Duration(days: 1)).add(kPhotoWorkoutWindow),
  );
}
