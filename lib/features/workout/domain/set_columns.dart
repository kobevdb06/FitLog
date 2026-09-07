/// Which value columns the set table offers, per exercise.
///
/// Not everything is weight times reps. A plank is a number of seconds, a run
/// is a distance and a time, and offering kilograms there is asking for a
/// number that means nothing. The category already knows which of the four
/// make sense; this turns that into the columns on screen.
library;

import '../../../core/db/enums.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/widgets/numeric_keypad.dart';

/// The four numbers a set can carry, whatever it is stored in.
///
/// A running set and a set in a routine template hold the same four values in
/// two different tables; this is what the column rule needs to see of either,
/// so both get the same answer.
typedef SetValues = ({
  double? weightKg,
  int? reps,
  int? durationSeconds,
  double? distanceM,
});

/// The columns for [category], in the order they are filled in.
///
/// Weight travels with reps rather than with `ExerciseCategory.hasWeight`:
/// almost anything you count in reps can be loaded - a belt on dips, a plate
/// on a push-up - so hiding the column for body-weight exercises would take
/// away something people log today. What weight genuinely means nothing for is
/// the timed and the measured-out work, and those are exactly the categories
/// that ask for a time or a distance instead.
///
/// A column also appears when one of [sets] already holds a value for it, even
/// if the category says otherwise. Sessions logged before the table knew about
/// categories put weights on anything, and hiding the column would hide what
/// was recorded - the number would still be in the database, with no way to
/// see or correct it.
List<KeypadFieldKind> setColumnsFor(
  ExerciseCategory category,
  Iterable<SetValues> sets,
) {
  final rows = sets.toList(growable: false);
  bool anyHas(bool Function(SetValues) has) => rows.any(has);

  return [
    if (category.hasReps || anyHas((s) => s.weightKg != null))
      KeypadFieldKind.weight,
    if (category.hasDistance || anyHas((s) => s.distanceM != null))
      KeypadFieldKind.distance,
    if (category.hasDuration || anyHas((s) => s.durationSeconds != null))
      KeypadFieldKind.duration,
    if (category.hasReps || anyHas((s) => s.reps != null)) KeypadFieldKind.reps,
  ];
}

/// What the header of a value column says.
String columnLabel(KeypadFieldKind kind, Formatters formatters) =>
    switch (kind) {
      KeypadFieldKind.weight => formatters.weightUnitLabel.toUpperCase(),
      KeypadFieldKind.reps => 'REPS',
      KeypadFieldKind.duration => 'TIJD',
      KeypadFieldKind.distance => formatters.distanceUnitLabel.toUpperCase(),
      KeypadFieldKind.rpe => 'RPE',
    };
