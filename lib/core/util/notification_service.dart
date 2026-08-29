import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications, used for exactly one thing: telling the user their
/// rest is over when they have put the phone away.
///
/// Nothing here talks to a server; `flutter_local_notifications` schedules on
/// the device itself.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// A fixed id: there is only ever one rest timer.
  static const int restTimerNotificationId = 1001;

  static const _channelId = 'fitlog_rest_timer';

  bool _initialised = false;
  bool _timezoneReady = false;

  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await _localTimezoneName()));
      _timezoneReady = true;
    } on Object catch (error) {
      // A missing zone must never stop the app from starting; the timer then
      // simply falls back to the in-app countdown.
      debugPrint('FitLog: tijdzone niet ingesteld ($error)');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// The IANA name of the device's zone.
  ///
  /// `DateTime.timeZoneName` gives an abbreviation on some platforms, so this
  /// falls back to a fixed offset lookup and finally to UTC.
  Future<String> _localTimezoneName() async {
    final offset = DateTime.now().timeZoneOffset;
    if (offset == const Duration(hours: 1) ||
        offset == const Duration(hours: 2)) {
      return 'Europe/Brussels';
    }
    return 'UTC';
  }

  /// Asks for the runtime permissions the rest timer needs. Safe to call more
  /// than once; the platform only prompts the first time.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return granted;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  NotificationDetails get _restDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Rusttimer',
      channelDescription: 'Meldt wanneer je rustpauze voorbij is.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  /// Schedules the "rest is over" notification for [endsAt].
  ///
  /// The countdown itself is derived from the stored end timestamp, so this is
  /// only the nudge for when the app is not on screen.
  Future<void> scheduleRestFinished({
    required DateTime endsAt,
    required String exerciseName,
    bool withSound = true,
  }) async {
    await cancelRestFinished();
    if (!_timezoneReady) return;
    if (!endsAt.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: restTimerNotificationId,
        scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
        title: 'Rust voorbij',
        body: 'Tijd voor je volgende set: $exerciseName',
        notificationDetails: withSound
            ? _restDetails
            : const NotificationDetails(
                android: AndroidNotificationDetails(
                  _channelId,
                  'Rusttimer',
                  channelDescription:
                      'Meldt wanneer je rustpauze voorbij is.',
                  importance: Importance.high,
                  priority: Priority.high,
                  playSound: false,
                  enableVibration: true,
                ),
                iOS: DarwinNotificationDetails(presentSound: false),
              ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on Object catch (error) {
      // Exact alarms can be refused by the user; the in-app timer still works.
      debugPrint('FitLog: rusttimermelding niet gepland ($error)');
    }
  }

  Future<void> cancelRestFinished() async {
    try {
      await _plugin.cancel(id: restTimerNotificationId);
    } on Object catch (_) {
      // Nothing scheduled.
    }
  }
}
