/// Which days of the week a routine belongs to, and which day it is now.
///
/// Pure Dart on purpose: nothing in `lib/core/calc/` imports Flutter.
library;

/// The hour a training day rolls over.
///
/// The calendar flips at midnight; a training day does not. Someone still in
/// the gym at half past midnight on Saturday means Friday's session, and the
/// dashboard already agrees with them - the greeting says "Goedenacht" until
/// six rather than "Goedemorgen". Four in the morning is late enough to catch
/// the long evening and early enough that nobody trains before it.
const int kDayStartHour = 4;

/// Midnight of the training day [now] belongs to.
DateTime trainingDay(DateTime now) {
  final shifted = now.hour < kDayStartHour
      ? now.subtract(const Duration(days: 1))
      : now;
  return DateTime(shifted.year, shifted.month, shifted.day);
}

/// The weekday the schedule should be read for, 1 (Monday) to 7 (Sunday).
int trainingWeekday(DateTime now) => trainingDay(now).weekday;

/// Whether both moments fall on the same training day.
bool sameTrainingDay(DateTime a, DateTime b) =>
    trainingDay(a) == trainingDay(b);

/// The days of the week a routine is planned on, packed into one integer.
///
/// Monday is bit 0 through Sunday at bit 6, so `DateTime.weekday` maps on as
/// `weekday - 1`. Seven fixed values need no table of their own, and a routine
/// carrying its own days means one day holds as many routines as you like
/// without anything else being written down.
class WeekdaySet {
  /// Takes only the seven bits that mean something, so a value that arrives
  /// damaged cannot produce an eighth weekday.
  const WeekdaySet(int mask) : mask = mask & _all;

  factory WeekdaySet.of(Iterable<int> weekdays) {
    var mask = 0;
    for (final weekday in weekdays) {
      if (weekday < DateTime.monday || weekday > DateTime.sunday) continue;
      mask |= 1 << (weekday - 1);
    }
    return WeekdaySet(mask);
  }

  static const int _all = 0x7F;

  /// No day at all: a routine you start whenever you feel like it.
  static const WeekdaySet none = WeekdaySet(0);

  final int mask;

  bool has(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return false;
    return mask & (1 << (weekday - 1)) != 0;
  }

  /// The same set with [weekday] added if it was missing and removed if it
  /// was there.
  WeekdaySet toggle(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return this;
    return WeekdaySet(mask ^ (1 << (weekday - 1)));
  }

  bool get isEmpty => mask == 0;

  bool get isNotEmpty => mask != 0;

  /// The days themselves, Monday first.
  List<int> get weekdays => [
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (has(weekday)) weekday,
  ];

  int get length => weekdays.length;

  /// The next day from [from] onwards that is in the set, [from] included.
  ///
  /// Null for an empty set; every other set answers within a week, because a
  /// week is all there is.
  int? nextFrom(int from) {
    if (isEmpty) return null;
    for (var step = 0; step < DateTime.daysPerWeek; step++) {
      final weekday = (from - 1 + step) % DateTime.daysPerWeek + 1;
      if (has(weekday)) return weekday;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is WeekdaySet && other.mask == mask;

  @override
  int get hashCode => mask.hashCode;

  @override
  String toString() => 'WeekdaySet($weekdays)';
}
