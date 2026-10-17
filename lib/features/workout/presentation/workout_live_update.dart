import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/util/notification_service.dart';
import '../domain/workout_notice.dart';
import 'workout_providers.dart';

part 'workout_live_update.g.dart';

/// Where the standing notification goes: the phone's, or a test's.
abstract interface class WorkoutNoticePoster {
  Future<void> show(WorkoutNotice notice, Formatters format);
  Future<void> cancel();
}

class _SystemPoster implements WorkoutNoticePoster {
  const _SystemPoster();

  @override
  Future<void> show(WorkoutNotice notice, Formatters format) =>
      NotificationService.instance.showWorkout(
        title: notice.title,
        body: notice.body,
        startedAt: notice.startedAt,
        restEndsAt: notice.restEndsAt,
      );

  @override
  Future<void> cancel() => NotificationService.instance.cancelWorkout();
}

@Riverpod(keepAlive: true)
WorkoutNoticePoster workoutNoticePoster(Ref ref) => const _SystemPoster();

/// Keeps the standing notification - the island, on a phone that has one -
/// in step with the running workout, also while FitLog is out of sight.
///
/// It used to be redrawn from the root widget's build, and a build only runs
/// with a frame. In the background there are none, so a set ticked off from
/// the notification would not have moved it on until the app was opened
/// again. Listeners run without frames.
@Riverpod(keepAlive: true)
class WorkoutLiveUpdate extends _$WorkoutLiveUpdate {
  /// Bumped on every sync, so an answer that comes back after a newer one
  /// started is dropped rather than posted over it.
  int _generation = 0;

  /// Last time's sets, read once per line-up: ticking a set off cannot
  /// change what the session before looked like.
  String? _historyKey;
  PreviousSession _history = PreviousSession.empty;

  /// Goes off when the rest is over, so the island stops counting and shows
  /// what to lift again.
  Timer? _restOver;

  @override
  WorkoutNotice? build() {
    ref.listen(activeWorkoutProvider, (_, _) => unawaited(sync()));
    ref.listen(restTimerProvider, (_, _) => unawaited(sync()));
    ref.listen(settingsProvider, (_, _) => unawaited(sync()));
    ref.onDispose(() => _restOver?.cancel());
    scheduleMicrotask(() => unawaited(sync()));
    return null;
  }

  /// Works the notice out again and posts it when it changed. Awaitable, so a
  /// set ticked off from the notification can wait for the notification to
  /// show the next one before it lets Android freeze the app again.
  Future<void> sync() async {
    final generation = ++_generation;
    final detail = ref.read(activeWorkoutProvider).value;
    final rest = ref.read(restTimerProvider);
    final settings = ref.read(settingsProvider).value;

    final running = detail != null && detail.workout.endedAt == null;
    if (running) {
      final key = '${detail.workout.id}|${lineUpOf(detail)}';
      if (key != _historyKey) {
        final history = await ref
            .read(databaseProvider)
            .workoutsDao
            .previousSessionFor(detail.workout.id);
        if (generation != _generation) return;
        _historyKey = key;
        _history = history;
      }
    }

    final now = DateTime.now();
    final restEndsAt = rest.endsAt != null && rest.endsAt!.isAfter(now)
        ? rest.endsAt
        : null;
    _restOver?.cancel();
    if (restEndsAt != null) {
      _restOver = Timer(restEndsAt.difference(now), () => unawaited(sync()));
    }

    final notice = workoutNoticeFor(
      detail,
      restEndsAt: restEndsAt,
      previous: running ? _history : PreviousSession.empty,
      platesKg: settings == null
          ? const []
          : decodePlates(settings.availablePlatesKg),
    );
    if (notice == state) return;
    state = notice;

    final poster = ref.read(workoutNoticePosterProvider);
    if (notice == null) {
      await poster.cancel();
    } else {
      await poster.show(notice, ref.read(formattersProvider));
    }
  }
}
