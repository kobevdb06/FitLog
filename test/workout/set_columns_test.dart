import 'package:fitlog/core/db/enums.dart';
import 'package:fitlog/core/widgets/numeric_keypad.dart';
import 'package:fitlog/features/workout/domain/set_columns.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which columns the set table offers for which exercise.
///
/// A plank is logged in seconds and a run in distance and time; asking for
/// kilograms there is asking for a number that means nothing.
void main() {
  SetValues set({
    double? weightKg,
    int? reps,
    int? durationSeconds,
    double? distanceM,
    double? rpe,
  }) => (
    weightKg: weightKg,
    reps: reps,
    durationSeconds: durationSeconds,
    distanceM: distanceM,
    rpe: rpe,
  );

  test('anything you load is weight times reps', () {
    for (final category in [
      ExerciseCategory.barbell,
      ExerciseCategory.dumbbell,
      ExerciseCategory.machine,
      ExerciseCategory.cable,
      ExerciseCategory.assistedBodyweight,
    ]) {
      expect(setColumnsFor(category, [set()]), [
        KeypadFieldKind.weight,
        KeypadFieldKind.reps,
      ], reason: category.wire);
    }
  });

  test('a body-weight exercise keeps its weight column', () {
    // You can hang a belt on a dip or hold a dumbbell for a pull-up, and
    // people log that. Taking the column away would lose it.
    expect(setColumnsFor(ExerciseCategory.bodyweight, [set()]), [
      KeypadFieldKind.weight,
      KeypadFieldKind.reps,
    ]);
  });

  test('a timed exercise asks for a time, not for kilograms', () {
    expect(setColumnsFor(ExerciseCategory.duration, [set()]), [
      KeypadFieldKind.duration,
    ]);
  });

  test('cardio asks for a distance and a time', () {
    expect(setColumnsFor(ExerciseCategory.cardio, [set()]), [
      KeypadFieldKind.distance,
      KeypadFieldKind.duration,
    ]);
  });

  test('a column stays for a value that is already stored', () {
    // Logged before the table knew about categories: the number is in the
    // database, so it has to stay visible and correctable.
    expect(
      setColumnsFor(ExerciseCategory.duration, [
        set(weightKg: 20, durationSeconds: 60),
      ]),
      [KeypadFieldKind.weight, KeypadFieldKind.duration],
    );
  });

  test('one filled set is enough to keep the column for all of them', () {
    expect(
      setColumnsFor(ExerciseCategory.duration, [
        set(),
        set(weightKg: 20),
        set(),
      ]),
      [KeypadFieldKind.weight, KeypadFieldKind.duration],
    );
  });

  test('an exercise without sets still gets its own columns', () {
    expect(setColumnsFor(ExerciseCategory.cardio, const []), [
      KeypadFieldKind.distance,
      KeypadFieldKind.duration,
    ]);
  });
}
