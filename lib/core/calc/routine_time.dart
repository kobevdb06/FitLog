/// How long a routine takes, roughly, from what is planned in it.
///
/// An estimate for choosing between routines, not a promise: the work of a
/// set is guessed, the rest is what the routine says or your own default,
/// and walking to the next machine is a minute.
///
/// Pure Dart on purpose: no Flutter import anywhere in `lib/core/calc/`.
library;

/// How long a set of repetitions takes, more or less.
const int kSecondsPerSet = 40;

/// Getting from one exercise to the next.
const int kSecondsBetweenExercises = 60;

/// One planned set, as far as the clock goes.
class PlannedSetTime {
  const PlannedSetTime({
    required this.exercise,
    this.restSeconds,
    this.durationSeconds,
  });

  /// Which exercise of the routine it belongs to, in order.
  final int exercise;

  /// The rest after it, when the routine sets one.
  final int? restSeconds;

  /// A hold or a timed set says how long it is itself.
  final int? durationSeconds;
}

/// The routine of [sets] in minutes, rounded to five and at least five.
///
/// No rest after the very last set: the session is over then.
int estimatedRoutineMinutes(
  List<PlannedSetTime> sets, {
  required int defaultRestSeconds,
}) {
  if (sets.isEmpty) return 0;
  var seconds = 0;
  for (var i = 0; i < sets.length; i++) {
    final set = sets[i];
    seconds += set.durationSeconds ?? kSecondsPerSet;
    if (i == sets.length - 1) continue;
    seconds += set.restSeconds ?? defaultRestSeconds;
    if (sets[i + 1].exercise != set.exercise) {
      seconds += kSecondsBetweenExercises;
    }
  }
  final minutes = ((seconds / 60) / 5).round() * 5;
  return minutes < 5 ? 5 : minutes;
}
