import 'package:fitlog/core/calc/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seven bits that say which days a routine is on.
void main() {
  group('the set', () {
    test('holds the days you put in it', () {
      final days = WeekdaySet.of([DateTime.monday, DateTime.thursday]);

      expect(days.has(DateTime.monday), isTrue);
      expect(days.has(DateTime.thursday), isTrue);
      expect(days.has(DateTime.tuesday), isFalse);
      expect(days.weekdays, [DateTime.monday, DateTime.thursday]);
    });

    test('comes back in the order of the week, not the order you typed', () {
      expect(WeekdaySet.of([DateTime.friday, DateTime.tuesday]).weekdays, [
        DateTime.tuesday,
        DateTime.friday,
      ]);
    });

    test('toggling puts a day in and takes it out again', () {
      final once = WeekdaySet.none.toggle(DateTime.wednesday);
      expect(once.weekdays, [DateTime.wednesday]);
      expect(once.toggle(DateTime.wednesday), WeekdaySet.none);
    });

    test('a day twice is still one day', () {
      expect(WeekdaySet.of([DateTime.monday, DateTime.monday]).length, 1);
    });

    test('two sets with the same days are the same set', () {
      expect(
        WeekdaySet.of([DateTime.monday, DateTime.friday]),
        WeekdaySet.of([DateTime.friday, DateTime.monday]),
      );
    });
  });

  group('what a damaged value cannot do', () {
    test('an eighth bit is dropped rather than trusted', () {
      // Whatever wrote 0xFF, there is no eighth weekday for it to mean.
      expect(WeekdaySet(0xFF).length, DateTime.daysPerWeek);
      expect(WeekdaySet(0xFF).mask, 0x7F);
    });

    test('a weekday outside 1 to 7 is simply not in the set', () {
      expect(WeekdaySet.of([0, 8, -3]), WeekdaySet.none);
      expect(WeekdaySet(0x7F).has(8), isFalse);
    });
  });

  group('the next day in the set', () {
    final monWed = WeekdaySet.of([DateTime.monday, DateTime.wednesday]);

    test('counts today itself', () {
      expect(monWed.nextFrom(DateTime.monday), DateTime.monday);
    });

    test('walks forward to the next one', () {
      expect(monWed.nextFrom(DateTime.tuesday), DateTime.wednesday);
    });

    test('wraps around the end of the week', () {
      expect(monWed.nextFrom(DateTime.friday), DateTime.monday);
    });

    test('an empty set has no next day', () {
      expect(WeekdaySet.none.nextFrom(DateTime.monday), isNull);
    });
  });

  group('when a training day starts', () {
    test('the evening belongs to its own day', () {
      expect(trainingWeekday(DateTime(2026, 9, 11, 21)), DateTime.friday);
    });

    test('and so does the hour after midnight', () {
      // Half past midnight on Saturday is still Friday's session; the app
      // already greets you with "Goedenacht" at that hour.
      expect(trainingWeekday(DateTime(2026, 9, 12, 0, 30)), DateTime.friday);
    });

    test('but a morning workout is a new day', () {
      expect(trainingWeekday(DateTime(2026, 9, 12, 7)), DateTime.saturday);
    });

    test('two moments either side of four are different days', () {
      final late = DateTime(2026, 9, 12, 3, 59);
      final early = DateTime(2026, 9, 12, 4, 1);

      expect(sameTrainingDay(late, early), isFalse);
      expect(sameTrainingDay(late, DateTime(2026, 9, 11, 22)), isTrue);
    });
  });
}
