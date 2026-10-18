/// What the ongoing notification says while a workout is running.
///
/// Worked out from the session itself rather than from the screen: the app may
/// be in the background, or gone from memory entirely, and the notification
/// still has to be right. Keeping it a pure function also means it can be
/// tested without a phone.
library;

import '../../../core/calc/progression.dart';
import '../../../core/calc/set_numbering.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';

/// Where a working set of the exercise stands: one segment of the bar.
enum SetMark { done, skipped, open }

/// The set the notification is about - the first one still to do - and what
/// to lift for it.
///
/// What the island shows closed, what its panel lets you change, and what
/// ticking it off from there writes: the values the set row shows, typed in
/// or greyed in from last time - and otherwise those of the set just done.
class NoticeSet {
  const NoticeSet({
    required this.setId,
    required this.exerciseName,
    required this.label,
    required this.marks,
    required this.category,
    required this.weightStepKg,
    this.position,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceM,
    this.isPrAttempt = false,
  });

  final String setId;
  final String exerciseName;

  /// `Set 3 van 4`, `Warming-up`, with the side for one side at a time.
  final String label;

  /// The working sets of the exercise, in order: the bar under the set.
  final List<SetMark> marks;

  /// Which of [marks] this set is; null for a warm-up, which is not on it.
  final int? position;

  final ExerciseCategory category;

  /// The step of the minus and plus beside the weight: the one you take on
  /// this exercise, or the smallest pair of plates.
  final double weightStepKg;

  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final double? distanceM;

  /// A PR attempt asks how it went once it is over, and only the app can.
  final bool isPrAttempt;

  bool get hasWeight => category.hasWeight;
  bool get hasDuration => category.hasDuration;
  bool get hasReps => !category.hasDuration;

  /// Whether it can be changed and ticked off from outside the app. A run
  /// has a distance, which the panel has no field for.
  bool get worksOutside => !isPrAttempt && !category.hasDistance;

  @override
  bool operator ==(Object other) =>
      other is NoticeSet &&
      other.setId == setId &&
      other.exerciseName == exerciseName &&
      other.label == label &&
      _sameMarks(other.marks, marks) &&
      other.position == position &&
      other.category == category &&
      other.weightStepKg == weightStepKg &&
      other.weightKg == weightKg &&
      other.reps == reps &&
      other.durationSeconds == durationSeconds &&
      other.distanceM == distanceM &&
      other.isPrAttempt == isPrAttempt;

  @override
  int get hashCode => Object.hash(
    setId,
    exerciseName,
    label,
    Object.hashAll(marks),
    position,
    category,
    weightStepKg,
    weightKg,
    reps,
    durationSeconds,
    distanceM,
    isPrAttempt,
  );

  static bool _sameMarks(List<SetMark> a, List<SetMark> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// What the island shows closed: what to lift, short enough for the 96dp a
/// status bar chip has - `80×8`, `×12` without weight, `0:45` for a plank.
String noticeChip(NoticeSet set, Formatters format) {
  if (set.hasDuration && set.durationSeconds != null) {
    return Formatters.duration(set.durationSeconds!)
        .replaceFirst(RegExp('^0'), '');
  }
  final reps = set.reps;
  final weight = set.weightKg;
  if (set.hasWeight && weight != null) {
    final value = format.weightValue(weight);
    return reps == null ? value : '$value×$reps';
  }
  if (reps != null) return '×$reps';
  return set.position == null ? 'W' : 'Set ${set.position! + 1}';
}

/// The same, written out: `80 kg × 8`.
String noticeValues(NoticeSet set, Formatters format) => format.setSummary(
  weightKg: set.hasWeight ? set.weightKg : null,
  reps: set.hasReps ? set.reps : null,
  durationSeconds: set.hasDuration ? set.durationSeconds : null,
  distanceM: set.distanceM,
);

class WorkoutNotice {
  const WorkoutNotice({
    required this.title,
    required this.body,
    required this.startedAt,
    this.restEndsAt,
    this.current,
  });

  /// The workout's name.
  final String title;

  /// Which exercise, and where in it.
  final String body;

  final DateTime startedAt;

  /// When the current rest is over, or null when nothing is resting.
  ///
  /// Android draws the countdown itself from this, so the app does not have to
  /// wake up every second to redraw a number - which is the whole reason a
  /// screen that is off can still show the time ticking away.
  final DateTime? restEndsAt;

  /// The set to do next, or null when there is none left.
  final NoticeSet? current;

  bool get isResting => restEndsAt != null;

  @override
  bool operator ==(Object other) =>
      other is WorkoutNotice &&
      other.title == title &&
      other.body == body &&
      other.startedAt == startedAt &&
      other.restEndsAt == restEndsAt &&
      other.current == current;

  @override
  int get hashCode => Object.hash(title, body, startedAt, restEndsAt, current);
}

/// The notice for [detail], or null when there is nothing to show.
///
/// [previous] fills in what an untouched set shows greyed out - last time's
/// matching set - and [platesKg] sets the weight step where the history has
/// none, as on the set row itself.
WorkoutNotice? workoutNoticeFor(
  WorkoutDetail? detail, {
  DateTime? restEndsAt,
  PreviousSession previous = PreviousSession.empty,
  List<double> platesKg = const [],
}) {
  if (detail == null) return null;
  if (detail.workout.endedAt != null) return null;

  return WorkoutNotice(
    title: detail.workout.isDeload
        ? '${detail.workout.name} · deload'
        : detail.workout.name,
    body: _whereYouAre(detail),
    startedAt: DateTime.fromMillisecondsSinceEpoch(detail.workout.startedAt),
    restEndsAt: restEndsAt,
    current: _nextSet(detail, previous, platesKg),
  );
}

/// The first set still to do, with its values and its exercise's bar.
NoticeSet? _nextSet(
  WorkoutDetail detail,
  PreviousSession previous,
  List<double> platesKg,
) {
  for (final exercise in detail.exercises) {
    final labels = labelSetsWithSides([
      for (final s in exercise.sets)
        (SetType.fromWire(s.setType), SetSide.fromWire(s.side)),
    ]);
    final working = [
      for (var i = 0; i < exercise.sets.length; i++)
        if (labels[i].workingIndex != null) i,
    ];

    for (var i = 0; i < exercise.sets.length; i++) {
      final row = exercise.sets[i];
      if (row.isCompleted || row.isSkipped) continue;

      final label = labels[i];
      final side = SetSide.fromWire(row.side);
      final sameSide = [
        for (final j in working)
          if (labels[j].side == side) j,
      ];
      final last = label.workingIndex == null
          ? null
          : _lastTime(previous, exercise, side, label.workingIndex!);
      // Nothing there and no history: the same again as the set just done.
      // From the island you cannot type, and starting from nothing every set
      // would be a lot of plus.
      WorkoutSetRow? before;
      for (var j = i - 1; j >= 0; j--) {
        final done = exercise.sets[j];
        if (done.isCompleted && SetSide.fromWire(done.side) == side) {
          before = done;
          break;
        }
      }
      final category = exercise.category;
      final named = switch (label.type) {
        SetType.warmup => 'Warming-up',
        _ => 'Set ${label.workingIndex! + 1} van ${sameSide.length}',
      };

      return NoticeSet(
        setId: row.id,
        exerciseName: exercise.exercise.name,
        label: side == null ? named : '$named · ${side.label}',
        marks: [
          for (final j in sameSide)
            exercise.sets[j].isCompleted
                ? SetMark.done
                : exercise.sets[j].isSkipped
                ? SetMark.skipped
                : SetMark.open,
        ],
        position: label.workingIndex == null ? null : sameSide.indexOf(i),
        category: category,
        weightStepKg:
            previous.weightSteps[exercise.exercise.id] ??
            defaultWeightStep(category, platesKg: platesKg),
        weightKg: row.weightKg ?? last?.weightKg ?? before?.weightKg,
        reps: row.reps ?? last?.reps ?? before?.reps,
        durationSeconds:
            row.durationSeconds ??
            last?.durationSeconds ??
            before?.durationSeconds,
        distanceM: row.distanceM ?? last?.distanceM ?? before?.distanceM,
        isPrAttempt:
            exercise.workoutExercise.isPrAttempt &&
            label.type != SetType.warmup,
      );
    }
  }
  return null;
}

/// Last time's set in this one's place, the way the previous column and
/// ticking a set off both match it; nothing for one that was skipped.
WorkoutSetRow? _lastTime(
  PreviousSession previous,
  WorkoutExerciseDetail exercise,
  SetSide? side,
  int workingIndex,
) {
  final sets = previous.setsFor(exercise.exercise.id, side);
  if (sets == null || workingIndex >= sets.length) return null;
  final match = sets[workingIndex];
  return match.isSkipped ? null : match;
}

/// The first set still to be done, named the way the set column names it.
String _whereYouAre(WorkoutDetail detail) {
  if (detail.exercises.isEmpty) return 'Nog geen oefeningen';

  for (final exercise in detail.exercises) {
    final labels = labelSets(
      exercise.sets.map((s) => SetType.fromWire(s.setType)),
    );
    final workingTotal = labels.where((l) => l.workingIndex != null).length;

    for (var i = 0; i < exercise.sets.length; i++) {
      // Done and skipped are both settled: the notification names the first
      // set you still have to do something about.
      if (exercise.sets[i].isCompleted || exercise.sets[i].isSkipped) continue;

      final label = labels[i];
      final where = switch (label.type) {
        SetType.warmup => 'warming-up',
        _ => 'set ${label.workingIndex! + 1} van $workingTotal',
      };
      return '${exercise.exercise.name} · $where';
    }
  }

  return 'Alle sets gedaan';
}
