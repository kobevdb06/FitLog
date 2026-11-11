/// Whole days on the calendar from the day of [from] to the day of [to],
/// whatever the clocks did in between.
///
/// A difference in hours came out a day short across the night the clocks
/// go forward: that Sunday has 23 hours, and a workout on it was "vandaag"
/// on the Monday (DECISIONS 268). Counted in UTC, where every day has 24.
int calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
