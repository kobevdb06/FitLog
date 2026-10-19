/// Which conversation the Chat tab shows.
///
/// It used to be the newest one, which cost two taps for every quick
/// question. Now it is a new, empty one whenever the app starts, and again
/// after [kCoachFreshAfter] away from it - unless a workout is running. Then
/// it is the conversation of that workout, the same one the coach in the
/// island writes in, so a question between two sets and one asked at the
/// bench go on together.
///
/// Switching tabs is not leaving: whoever looks at the records for a minute
/// comes back to the conversation they were in.
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../workout/presentation/workout_providers.dart';
import 'chat_providers.dart';

part 'coach_session.g.dart';

/// How long away from the app before the coach starts afresh.
const Duration kCoachFreshAfter = Duration(minutes: 30);

class CoachSession {
  const CoachSession({this.threadId, this.workoutId});

  /// The conversation on screen; null for a new one, which the first
  /// question makes.
  final String? threadId;

  /// The workout this is the conversation of, while it runs.
  final String? workoutId;
}

@Riverpod(keepAlive: true)
class CoachSessionController extends _$CoachSessionController {
  /// The workout running, as last seen.
  String? _running;

  /// When the app went to the background.
  DateTime? _leftAt;

  @override
  CoachSession build() {
    // A workout that starts - or is already running when the app starts -
    // takes the tab to its conversation. One that ends leaves it there:
    // the answer to the last question may still be being read.
    ref.listen(activeWorkoutProvider, (_, next) {
      if (!next.hasValue) return;
      final id = next.value?.workout.id;
      if (id == _running) return;
      _running = id;
      if (id != null) unawaited(_toWorkout(id));
    }, fireImmediately: true);
    return const CoachSession();
  }

  Future<void> _toWorkout(String workoutId) async {
    final thread = await ref
        .read(databaseProvider)
        .chatDao
        .threadForWorkout(workoutId);
    if (_running != workoutId) return;
    state = CoachSession(threadId: thread?.id, workoutId: workoutId);
  }

  /// A new, empty conversation - or during a workout, that workout's.
  Future<void> fresh() async {
    final running = _running;
    if (running != null) return _toWorkout(running);
    state = const CoachSession();
  }

  /// Nieuw gesprek: empty, whatever is running.
  void startNew() => state = const CoachSession();

  /// A conversation picked from the list.
  void show(String threadId, {String? workoutId}) =>
      state = CoachSession(threadId: threadId, workoutId: workoutId);

  /// The app went to the background at [at].
  void left(DateTime at) => _leftAt = at;

  /// The app came back at [at]: afresh after [kCoachFreshAfter], but never
  /// while an answer is being written.
  Future<void> back(DateTime at) async {
    final left = _leftAt;
    _leftAt = null;
    if (left == null || at.difference(left) < kCoachFreshAfter) return;
    if (ref.read(coachControllerProvider).sending) return;
    await fresh();
  }

  /// The conversation the next question goes into, made when there is none
  /// yet - or when the one on screen was wiped in the meantime.
  Future<String> threadFor(String question) async {
    final db = ref.read(databaseProvider);
    final asked = state;
    if (asked.threadId case final id?) {
      if (await db.chatDao.threadExists(id)) return id;
    }
    final coach = ref.read(coachControllerProvider.notifier);
    final workoutId = asked.workoutId;
    final id = workoutId != null && workoutId == _running
        ? await coach.workoutThread(workoutId)
        : await coach.startThread(question);
    // Only if nothing else was picked while it was being made.
    if (identical(state, asked)) {
      state = CoachSession(threadId: id, workoutId: workoutId);
    }
    return id;
  }
}
