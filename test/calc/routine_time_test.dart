import 'package:fitlog/core/calc/routine_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long a routine takes, from what is planned in it.
void main() {
  List<PlannedSetTime> sets(
    int exercises,
    int each, {
    int? rest,
    int? seconds,
  }) => [
    for (var e = 0; e < exercises; e++)
      for (var s = 0; s < each; s++)
        PlannedSetTime(
          exercise: e,
          restSeconds: rest,
          durationSeconds: seconds,
        ),
  ];

  test('nothing planned takes no time', () {
    expect(estimatedRoutineMinutes(const [], defaultRestSeconds: 90), 0);
  });

  test('three exercises of three sets with the default rest', () {
    // 9 sets of 40 s, 8 rests of 90 s, two walks to the next exercise.
    expect(
      estimatedRoutineMinutes(sets(3, 3), defaultRestSeconds: 90),
      (9 * 40 + 8 * 90 + 2 * 60) ~/ 60,
    );
    expect(estimatedRoutineMinutes(sets(3, 3), defaultRestSeconds: 90), 20);
  });

  test('the rest the routine sets wins over the default', () {
    final short = estimatedRoutineMinutes(sets(4, 3), defaultRestSeconds: 90);
    final long = estimatedRoutineMinutes(
      sets(4, 3, rest: 180),
      defaultRestSeconds: 90,
    );
    expect(short, 30);
    expect(long, 45);
  });

  test('a timed set counts its own length', () {
    // Three five-minute holds, a minute apart: 17 minutes, so 15.
    expect(
      estimatedRoutineMinutes(
        sets(1, 3, rest: 60, seconds: 300),
        defaultRestSeconds: 90,
      ),
      15,
    );
  });

  test('no rest after the very last set', () {
    // One set: only its own 40 seconds, which is still the five minimum.
    expect(estimatedRoutineMinutes(sets(1, 1), defaultRestSeconds: 600), 5);
  });

  test('rounded to five minutes', () {
    for (var n = 1; n <= 12; n++) {
      final minutes = estimatedRoutineMinutes(
        sets(n, 3),
        defaultRestSeconds: 120,
      );
      expect(minutes % 5, 0, reason: '$n exercises');
      expect(minutes, greaterThanOrEqualTo(5));
    }
  });
}
