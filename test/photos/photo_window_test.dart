import 'package:fitlog/features/photos/domain/photo_window.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which sessions sit close enough to a photograph to have been its reason.
void main() {
  final window = workoutWindowFor(DateTime(2026, 9, 7, 10, 30));

  bool covers(DateTime at) =>
      !at.isBefore(window.from) && at.isBefore(window.to);

  test('the day the photo was taken', () {
    expect(covers(DateTime(2026, 9, 7, 0, 1)), isTrue);
    expect(covers(DateTime(2026, 9, 7, 23, 59)), isTrue);
  });

  test('and the evening before and the day after', () {
    expect(covers(DateTime(2026, 9, 6, 19)), isTrue);
    expect(covers(DateTime(2026, 9, 8, 9)), isTrue);
  });

  test('but nothing two days out', () {
    expect(covers(DateTime(2026, 9, 5, 12)), isFalse);
    expect(covers(DateTime(2026, 9, 9, 12)), isFalse);
  });

  test('the time of day does not move the window', () {
    // Photographed at half past eleven at night, still the same three days.
    final late = workoutWindowFor(DateTime(2026, 9, 7, 23, 30));
    expect(late.from, window.from);
    expect(late.to, window.to);
  });
}
