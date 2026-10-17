import 'package:flutter/services.dart';

import '../../../core/formatting/formatters.dart';
import '../domain/workout_notice.dart';

/// The workout notification as Android's side reads it: everything already
/// worked out and worded, so the Kotlin only lays it out.
Map<String, Object?> workoutNoticePayload(
  WorkoutNotice notice,
  Formatters format,
) {
  final set = notice.current;
  return {
    'title': notice.title,
    'body': notice.body,
    'startedAt': notice.startedAt.millisecondsSinceEpoch,
    'restEndsAt': notice.restEndsAt?.millisecondsSinceEpoch,
    'set': set == null
        ? null
        : {
            'id': set.setId,
            'exercise': set.exerciseName,
            'label': set.label,
            'marks': [for (final mark in set.marks) mark.name],
            'position': set.position,
            'chip': noticeChip(set, format),
            // Null for a set with nothing filled in yet, rather than a dash.
            'values': switch (noticeValues(set, format)) {
              '-' => null,
              final values => values,
            },
            'outside': set.worksOutside,
          },
  };
}

/// The set as the panel over another app shows it: everything it needs to
/// draw the steppers, in kilograms - it converts to the unit it shows.
Map<String, Object?> panelSetPayload(NoticeSet set) => {
  'id': set.setId,
  'exercise': set.exerciseName,
  'label': set.label,
  'marks': [for (final mark in set.marks) mark.name],
  'position': set.position,
  'weightKg': set.weightKg,
  'reps': set.reps,
  'durationSeconds': set.durationSeconds,
  'hasWeight': set.hasWeight,
  'hasReps': set.hasReps,
  'hasDuration': set.hasDuration,
  'stepKg': set.weightStepKg,
  'outside': set.worksOutside,
};

/// What the panel changed: only the fields the set has.
typedef PanelValues = ({double? weightKg, int? reps, int? durationSeconds});

PanelValues panelValuesFrom(Map<Object?, Object?>? arguments) => (
  weightKg: (arguments?['weightKg'] as num?)?.toDouble(),
  reps: (arguments?['reps'] as num?)?.toInt(),
  durationSeconds: (arguments?['durationSeconds'] as num?)?.toInt(),
);

/// The way to `FitLogActivity`'s workout channel, both ways.
class WorkoutNoticeChannel {
  const WorkoutNoticeChannel();

  static const _channel = MethodChannel('be.fitlog.app/workout');

  Future<void> show(Map<String, Object?> payload) =>
      _channel.invokeMethod<void>('show', payload);

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  /// Whether Android lets the workout be a live notification; null before
  /// Android 16, which has no such switch.
  Future<bool?> canPromote() => _channel.invokeMethod<bool>('canPromote');

  /// Android's page for FitLog's live notifications.
  Future<void> openPromoteSettings() =>
      _channel.invokeMethod<void>('openPromote');

  /// Something the open panel should hear without asking: the coach's
  /// answer, as it is written.
  Future<void> panelEvent(Map<String, Object?> event) =>
      _channel.invokeMethod<void>('panelEvent', event);

  /// What a tap in the notification, or the panel over another app, asks
  /// for. [onTick] answers whether the set was ticked off; the notification
  /// shows it again when it was not.
  void listen({
    required Future<bool> Function(String setId) onTick,
    required Map<String, Object?> Function() onPanelState,
    required Future<Map<String, Object?>> Function(
      String setId,
      PanelValues values, {
      required bool complete,
    })
    onEdit,
    required void Function(String route) onOpen,
    Future<Object?> Function(String method, Map<Object?, Object?>? arguments)?
    onOther,
  }) {
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final setId = arguments?['setId'] as String?;
      switch (call.method) {
        case 'tick':
          return {'ticked': setId != null && await onTick(setId)};
        case 'state':
          return onPanelState();
        case 'update' || 'complete' when setId != null:
          return onEdit(
            setId,
            panelValuesFrom(arguments),
            complete: call.method == 'complete',
          );
        case 'open':
          final route = arguments?['route'] as String?;
          if (route != null) onOpen(route);
          return null;
      }
      if (onOther != null) return onOther(call.method, arguments);
      throw MissingPluginException(call.method);
    });
  }

  void stop() => _channel.setMethodCallHandler(null);
}
