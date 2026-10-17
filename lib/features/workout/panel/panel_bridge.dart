import 'dart:async';

import 'package:flutter/services.dart';

/// The panel's line to the running app, through `WorkoutPanelActivity`.
///
/// The panel runs in an engine of its own and holds nothing: it asks the app,
/// which has the logbook open, for every set it shows and every change it
/// makes.
abstract interface class PanelBridge {
  /// `edit` or `coach`: which button in the notification opened it.
  Future<String> mode();

  /// A question for the running app; `{'closed': true}` when it is gone.
  Future<Map<Object?, Object?>> relay(
    String method, [
    Map<String, Object?>? arguments,
  ]);

  Future<void> close();

  /// FitLog itself, at [route].
  Future<void> openApp(String route);

  /// Another button in the notification while the panel is open.
  Stream<String> get modes;

  /// What the app sends unasked: the coach's answer as it is written.
  Stream<Map<Object?, Object?>> get events;
}

class AndroidPanelBridge implements PanelBridge {
  AndroidPanelBridge() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mode':
          _modes.add(call.arguments as String);
        case 'event':
          _events.add(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
  }

  static const _channel = MethodChannel('be.fitlog.app/panel');
  final _modes = StreamController<String>.broadcast();
  final _events = StreamController<Map<Object?, Object?>>.broadcast();

  @override
  Future<String> mode() async =>
      await _channel.invokeMethod<String>('mode') ?? 'edit';

  @override
  Future<Map<Object?, Object?>> relay(
    String method, [
    Map<String, Object?>? arguments,
  ]) async =>
      await _channel.invokeMethod<Map<Object?, Object?>>('relay', {
        'method': method,
        'args': arguments,
      }) ??
      const {};

  @override
  Future<void> close() => _channel.invokeMethod<void>('close');

  @override
  Future<void> openApp(String route) =>
      _channel.invokeMethod<void>('openApp', {'route': route});

  @override
  Stream<String> get modes => _modes.stream;

  @override
  Stream<Map<Object?, Object?>> get events => _events.stream;
}
