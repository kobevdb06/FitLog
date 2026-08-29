/// Training streak, counted in calendar weeks.
///
/// A streak is the number of consecutive weeks that contain at least one
/// finished workout. It only breaks after a *full* calendar week without one,
/// so an empty current week does not immediately reset the counter.
library;

class StreakResult {
  const StreakResult({required this.weeks, required this.daysSinceLast});

  const StreakResult.none() : weeks = 0, daysSinceLast = null;

  final int weeks;

  /// Whole days between the last workout and today, or null if there is none.
  final int? daysSinceLast;

  bool get isActive => weeks > 0;
}

/// Midnight of the Monday that starts the week containing [date].
DateTime startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// [workoutDates] may be in any order and may contain several entries per day.
StreakResult computeStreak(Iterable<DateTime> workoutDates, {DateTime? now}) {
  final today = _startOfDay(now ?? DateTime.now());
  final dates = workoutDates.toList();
  if (dates.isEmpty) return const StreakResult.none();

  final weeks = dates.map(startOfWeek).toSet();

  var cursor = startOfWeek(today);
  var count = 0;

  // The current week may legitimately still be empty; the streak survives
  // until a whole week has passed without a workout.
  if (!weeks.contains(cursor)) {
    cursor = startOfWeek(cursor.subtract(const Duration(days: 1)));
  }

  while (weeks.contains(cursor)) {
    count++;
    cursor = startOfWeek(cursor.subtract(const Duration(days: 1)));
  }

  final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
  final daysSinceLast = today.difference(_startOfDay(last)).inDays;

  return StreakResult(weeks: count, daysSinceLast: daysSinceLast);
}
