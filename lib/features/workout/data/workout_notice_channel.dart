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

/// The way to `FitLogActivity`'s workout channel, both ways.
class WorkoutNoticeChannel {
  const WorkoutNoticeChannel();

  static const _channel = MethodChannel('be.fitlog.app/workout');

  Future<void> show(Map<String, Object?> payload) =>
      _channel.invokeMethod<void>('show', payload);

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  /// What a tap in the notification asks for. [onTick] answers whether the
  /// set was ticked off; the notification shows it again when it was not.
  void listen({required Future<bool> Function(String setId) onTick}) {
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'tick':
          final setId = arguments?['setId'] as String?;
          return {'ticked': setId != null && await onTick(setId)};
      }
      throw MissingPluginException(call.method);
    });
  }

  void stop() => _channel.setMethodCallHandler(null);
}
