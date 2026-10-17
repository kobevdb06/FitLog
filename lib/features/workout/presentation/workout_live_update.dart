import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/util/notification_service.dart';
import '../../../routing/router.dart';
import '../data/workout_notice_channel.dart';
import '../domain/workout_notice.dart';
import 'workout_providers.dart';

part 'workout_live_update.g.dart';

/// Where the standing notification goes: the phone's, or a test's.
abstract interface class WorkoutNoticePoster {
  Future<void> show(WorkoutNotice notice, Formatters format);
  Future<void> cancel();
}

/// On Android the notification is FitLog's own (a Live Update, with the
/// buttons); elsewhere the plugin's, as before.
class _SystemPoster implements WorkoutNoticePoster {
  const _SystemPoster();

  static const _android = WorkoutNoticeChannel();

  @override
  Future<void> show(WorkoutNotice notice, Formatters format) async {
    if (Platform.isAndroid) {
      try {
        await _android.show(workoutNoticePayload(notice, format));
      } on Object catch (error) {
        // A workout must never fail because a notification would not go up.
        debugPrint('FitLog: workoutmelding niet getoond ($error)');
      }
      return;
    }
    await NotificationService.instance.showWorkout(
      title: notice.title,
      body: notice.body,
      startedAt: notice.startedAt,
      restEndsAt: notice.restEndsAt,
    );
  }

  @override
  Future<void> cancel() async {
    if (Platform.isAndroid) {
      try {
        await _android.cancel();
      } on Object catch (error) {
        debugPrint('FitLog: workoutmelding niet weggehaald ($error)');
      }
      return;
    }
    await NotificationService.instance.cancelWorkout();
  }
}

/// Where the taps in the notification come in: the phone's channel, or none.
@Riverpod(keepAlive: true)
WorkoutNoticeChannel? workoutNoticeChannel(Ref ref) =>
    Platform.isAndroid ? const WorkoutNoticeChannel() : null;

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
    final channel = ref.read(workoutNoticeChannelProvider);
    channel?.listen(
      onTick: tick,
      onPanelState: panelState,
      onEdit: edit,
      onOpen: (route) => ref.read(routerProvider).go(route),
    );
    ref.onDispose(() {
      _restOver?.cancel();
      channel?.stop();
    });
    scheduleMicrotask(() => unawaited(sync()));
    return null;
  }

  /// What the panel over another app shows: the set up next, in the unit
  /// and the theme the app is set to.
  Map<String, Object?> panelState() {
    final notice = state;
    final set = notice?.current;
    return {
      'title': notice?.title,
      'unit': ref.read(formattersProvider).weightUnit.wire,
      'theme': ref.read(settingsProvider).value?.themeMode ?? 'dark',
      'set': set == null ? null : panelSetPayload(set),
    };
  }

  /// The panel's steppers, written to the set it showed - and with
  /// [complete], ticked off as well. Answers with what the panel shows next.
  Future<Map<String, Object?>> edit(
    String setId,
    PanelValues values, {
    required bool complete,
  }) async {
    if (state?.current?.setId != setId) {
      await sync();
      return {'ok': false, ...panelState()};
    }
    if (complete) {
      final ok = await tick(setId, values: values);
      return {'ok': ok, ...panelState()};
    }
    await ref
        .read(workoutControllerProvider)
        .updateSetValues(
          setId,
          weightKg: values.weightKg == null
              ? const Value.absent()
              : Value(values.weightKg),
          reps: values.reps == null ? const Value.absent() : Value(values.reps),
          durationSeconds: values.durationSeconds == null
              ? const Value.absent()
              : Value(values.durationSeconds),
        );
    await sync();
    return {'ok': true, ...panelState()};
  }

  /// Afvinken in the notification: the set it showed, with the values it
  /// showed - passed in, so what is stored is what was on screen - and the
  /// rest that follows, as the tick on the set row does.
  ///
  /// Only that set: a second tap on a notification that was not redrawn yet
  /// must not tick off the set after it. True when it was ticked off.
  /// [values] are the panel's, when it ticks the set off; otherwise the
  /// notice's own.
  Future<bool> tick(String setId, {PanelValues? values}) async {
    if (state?.current?.setId != setId) {
      await sync();
      return false;
    }

    final shown = state!.current!;
    final result = await ref
        .read(workoutControllerProvider)
        .completeSet(
          setId: setId,
          weightKg:
              values?.weightKg ?? (shown.hasWeight ? shown.weightKg : null),
          reps: values?.reps ?? (shown.hasReps ? shown.reps : null),
          durationSeconds:
              values?.durationSeconds ??
              (shown.hasDuration ? shown.durationSeconds : null),
          distanceM: shown.distanceM,
        );
    if (result != null && result.restSeconds > 0) {
      final settings = ref.read(settingsProvider).value;
      await ref
          .read(restTimerProvider.notifier)
          .start(
            seconds: result.restSeconds,
            exerciseName: result.exerciseName,
            withSound: settings?.restSoundEnabled ?? true,
          );
    }
    // Before answering: Android may freeze the app again once it has its
    // answer, and the notification should show the next set by then.
    await sync();
    return result != null;
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
