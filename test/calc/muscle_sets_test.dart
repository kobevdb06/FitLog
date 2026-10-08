import 'package:fitlog/core/calc/muscle_sets.dart';
import 'package:fitlog/core/calc/plateau.dart';
import 'package:fitlog/core/calc/progress_period.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday 8 October 2026, 15:00. Four weeks back is Monday 14 September;
  // the stretch as long before that begins on 20 August at 09:00.
  final now = DateTime(2026, 10, 8, 15);
  const weeks = (24 + 15 / 24) / 7;

  List<ProgressSet> sets(String muscle, DateTime at, int count) => [
    for (var i = 0; i < count; i++)
      ProgressSet(
        workoutId: 'w-$muscle-${at.millisecondsSinceEpoch}',
        startedAt: at,
        exerciseId: 'ex-$muscle',
        primaryMuscle: muscle,
        category: ExerciseCategory.barbell,
        weightKg: 60,
        reps: 8,
      ),
  ];

  final result = muscleSetsPerWeek(
    [
      ...sets('borst', DateTime(2026, 10, 1, 18), 12),
      ...sets('rug', DateTime(2026, 10, 2, 18), 6),
      ...sets('rug', DateTime(2026, 9, 1, 18), 20),
      ...sets('benen', DateTime(2026, 8, 25, 18), 10),
      // Before the stretch before, and after now: neither counts.
      ...sets('borst', DateTime(2026, 8, 10, 18), 30),
      ...sets('borst', DateTime(2026, 10, 9, 18), 30),
    ],
    period: ProgressPeriod.fourWeeks,
    now: now,
  );

  test('per week van de periode tot nu, de meeste eerst', () {
    expect([for (final m in result) m.muscle], ['borst', 'rug', 'benen']);
    expect(result[0].perWeek, closeTo(12 / weeks, 1e-9));
    expect(result[0].usualPerWeek, 0);
  });

  test('tegen de even lange periode ervoor, door dezelfde weken gedeeld', () {
    expect(result[1].perWeek, closeTo(6 / weeks, 1e-9));
    expect(result[1].usualPerWeek, closeTo(20 / weeks, 1e-9));
  });

  test('een spiergroep die je niet meer trainde, staat er ook', () {
    expect(result[2].muscle, 'benen');
    expect(result[2].perWeek, 0);
    expect(result[2].usualPerWeek, closeTo(10 / weeks, 1e-9));
  });

  test('achter: onder zeven tiende van een gewoonte van vier per week', () {
    expect(result[1].lagging, isTrue, reason: '1,7 tegen 5,7');
    expect(
      result[2].lagging,
      isFalse,
      reason: '2,8 per week is te weinig om bij achter te raken',
    );
    expect(laggingBehind(2.7, 4), isTrue);
    expect(laggingBehind(2.9, 4), isFalse);
    expect(laggingBehind(2.7, 3.9), isFalse);
  });
}
