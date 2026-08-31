/// What the ongoing notification says while a workout is running.
///
/// Worked out from the session itself rather than from the screen: the app may
/// be in the background, or gone from memory entirely, and the notification
/// still has to be right. Keeping it a pure function also means it can be
/// tested without a phone.
library;

import '../../../core/calc/set_numbering.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';

class WorkoutNotice {
  const WorkoutNotice({
    required this.title,
    required this.body,
    required this.startedAt,
    this.restEndsAt,
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

  bool get isResting => restEndsAt != null;

  @override
  bool operator ==(Object other) =>
      other is WorkoutNotice &&
      other.title == title &&
      other.body == body &&
      other.startedAt == startedAt &&
      other.restEndsAt == restEndsAt;

  @override
  int get hashCode => Object.hash(title, body, startedAt, restEndsAt);
}

/// The notice for [detail], or null when there is nothing to show.
WorkoutNotice? workoutNoticeFor(
  WorkoutDetail? detail, {
  DateTime? restEndsAt,
}) {
  if (detail == null) return null;
  if (detail.workout.endedAt != null) return null;

  return WorkoutNotice(
    title: detail.workout.name,
    body: _whereYouAre(detail),
    startedAt: DateTime.fromMillisecondsSinceEpoch(detail.workout.startedAt),
    restEndsAt: restEndsAt,
  );
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
      if (exercise.sets[i].isCompleted) continue;

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
