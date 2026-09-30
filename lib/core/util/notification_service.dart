import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: the nudge when a rest is over, the standing one that
/// shows where you are while a workout runs, and the morning report.
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

  /// And only ever one running workout.
  static const int workoutNotificationId = 1002;

  /// And one morning report: a new one replaces the one before.
  static const int morningNotificationId = 1003;

  /// What a tap on the morning report carries.
  static const String morningPayload = 'morning';

  static const _channelId = 'fitlog_rest_timer';
  static const _workoutChannelId = 'fitlog_workout';
  static const _morningChannelId = 'fitlog_morning';

  /// Called with the payload of a notification the user tapped while the
  /// app was running. The app sets it; the service only passes it on.
  void Function(String payload)? onTapped;

  bool _initialised = false;
  bool _timezoneReady = false;
  bool _permissionAsked = false;

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
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTapped?.call(payload);
      },
    );
  }

  /// The payload of the notification that started the app, if one did.
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } on Object {
      return null;
    }
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

  /// Asks for permission the first time in this run, and not again.
  ///
  /// Android 13 and later post nothing at all without it, and a permission
  /// that is declared in the manifest but never requested is simply refused -
  /// silently, which is exactly how the rest timer came to have a
  /// notification nobody ever saw.
  ///
  /// Asked when a workout starts rather than at launch: that is the moment it
  /// is obvious what it is for.
  Future<bool> ensurePermission() async {
    if (_permissionAsked) return true;
    _permissionAsked = true;
    try {
      return await requestPermissions();
    } on Object catch (error) {
      debugPrint('FitLog: toestemming voor meldingen niet gevraagd ($error)');
      return false;
    }
  }

  /// Whether the user has actually allowed notifications.
  Future<bool> get isAllowed async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    } on Object {
      return false;
    }
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

  /// Shows, or updates, the notification that stands while a workout runs.
  ///
  /// Silent and low importance: it is a place to look, not an interruption -
  /// the rest timer already has the job of getting your attention.
  ///
  /// While resting, Android renders the countdown itself from [restEndsAt];
  /// otherwise it counts the workout up from [startedAt]. Either way the app
  /// does not have to wake up to redraw a number, which is what lets the time
  /// keep moving with the screen off.
  ///
  /// On Android 14 and later a standing notification can still be swiped away
  /// - Google made that deliberate - so this is posted again on every change.
  Future<void> showWorkout({
    required String title,
    required String body,
    required DateTime startedAt,
    DateTime? restEndsAt,
  }) async {
    final resting = restEndsAt != null && restEndsAt.isAfter(DateTime.now());

    try {
      await _plugin.show(
        id: workoutNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _workoutChannelId,
            'Lopende workout',
            channelDescription:
                'Blijft staan zolang je workout bezig is, met je oefening, '
                'je set en je resterende rust.',
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.workout,
            playSound: false,
            enableVibration: false,
            silent: true,
            onlyAlertOnce: true,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            when: (resting ? restEndsAt : startedAt).millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: resting,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBanner: false,
          ),
        ),
      );
    } on Object catch (error) {
      // A workout must never fail to start because a notification would not
      // go up.
      debugPrint('FitLog: workoutmelding niet getoond ($error)');
    }
  }

  /// Shows this morning's report, or replaces the one already there.
  ///
  /// Private on a locked screen: what it says is how you slept, and Android
  /// then shows only that FitLog has a notification, unless you allowed
  /// more.
  Future<void> showMorningReport({
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id: morningNotificationId,
        title: title,
        body: body,
        payload: morningPayload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _morningChannelId,
            'Ochtendrapport',
            channelDescription:
                'Je slaapscore en wat er nog herstelt, elke ochtend op het '
                'uur dat je koos.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.status,
            styleInformation: BigTextStyleInformation(body),
            visibility: NotificationVisibility.private,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true),
        ),
      );
    } on Object catch (error) {
      debugPrint('FitLog: ochtendrapport niet getoond ($error)');
    }
  }

  /// Whether a morning report is in the notification shade right now - the
  /// one that says it waits for an unlock, most likely.
  Future<bool> get morningReportShowing async {
    if (!Platform.isAndroid) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final active = await android?.getActiveNotifications() ?? const [];
      return active.any((n) => n.id == morningNotificationId);
    } on Object {
      return false;
    }
  }

  Future<void> cancelWorkout() async {
    try {
      await _plugin.cancel(id: workoutNotificationId);
    } on Object catch (_) {
      // Nothing showing.
    }
  }

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
                  channelDescription: 'Meldt wanneer je rustpauze voorbij is.',
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
