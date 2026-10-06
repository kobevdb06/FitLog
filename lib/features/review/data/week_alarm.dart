import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../../../core/db/connection.dart';
import '../../../core/db/database.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/security/key_material.dart';
import '../../../core/security/secret_store.dart';
import '../../../core/util/notification_service.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/week_navigator.dart';
import '../../morning/data/morning_alarm.dart' show handOffToOpenApp;
import '../../morning/data/morning_reporter.dart' show ReportClientFactory;
import '../domain/week_facts.dart';
import 'week_facts_builder.dart';
import 'week_reviewer.dart';

/// The weekly review comes at eight on Sunday evening: the week is done,
/// and there is still an evening to plan Monday.
const int kWeekReviewHour = 20;

/// Sunday at eight in the evening of the week [now] falls in.
DateTime sundayEveningOf(DateTime now) => DateTime(
  now.year,
  now.month,
  now.day + (DateTime.sunday - now.weekday),
  kWeekReviewHour,
);

/// When the next weekly review is due: this Sunday evening if that is still
/// ahead of [now], next Sunday's otherwise. From the calendar, like the
/// morning, so the week the clocks change still lands on eight.
DateTime nextSundayEvening(DateTime now) {
  final sunday = sundayEveningOf(now);
  return sunday.isAfter(now)
      ? sunday
      : DateTime(sunday.year, sunday.month, sunday.day + 7, kWeekReviewHour);
}

/// The Sunday evening that last went by, up to and including [now].
DateTime lastSundayEvening(DateTime now) {
  final sunday = sundayEveningOf(now);
  return sunday.isAfter(now)
      ? DateTime(sunday.year, sunday.month, sunday.day - 7, kWeekReviewHour)
      : sunday;
}

/// Something that can wake the app at a moment, once.
abstract interface class WeekAlarm {
  Future<void> setAt(DateTime at);
  Future<void> cancel();
}

/// Keeps the one alarm in step with the setting.
class WeekSchedule {
  const WeekSchedule(this.alarm);

  final WeekAlarm alarm;

  Future<void> apply({required bool enabled, DateTime? now}) async {
    if (!enabled) {
      await alarm.cancel();
      return;
    }
    await alarm.setAt(nextSundayEvening(now ?? DateTime.now()));
  }
}

/// Android's AlarmManager, exact, as for the morning report.
class AndroidWeekAlarm implements WeekAlarm {
  const AndroidWeekAlarm();

  static const int id = 7302;
  static bool _started = false;

  @override
  Future<void> setAt(DateTime at) async {
    if (!Platform.isAndroid) return;
    if (!_started) {
      await AndroidAlarmManager.initialize();
      _started = true;
    }
    await AndroidAlarmManager.oneShotAt(
      at,
      id,
      weekAlarm,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  @override
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(id);
  }
}

/// The name under which the running app listens for this alarm.
const String kWeekPortName = 'fitlog.week';

/// Where the alarm lands: a separate isolate started by Android.
@pragma('vm:entry-point')
Future<void> weekAlarm(int id, Map<String, dynamic> params) async {
  DartPluginRegistrant.ensureInitialized();
  await WeekAlarmHandler(
    schedule: const WeekSchedule(AndroidWeekAlarm()),
    handOff: () => handOffToOpenApp(portName: kWeekPortName),
    keys: KeyManager(SecureStorageSecretStore()),
    openDatabase: (key) async => AppDatabase(
      openEncryptedExecutor(
        file: (await AppPaths.resolve()).databaseFile,
        keyHex: toHex(key),
      ),
    ),
    notices: const NotificationWeekNotices(),
  ).handle();
}

/// The week from [start] made into its review: the coach's words where
/// there is a coach, and in any case a row that says the review of that week
/// was made - which is what keeps it from being made again after an unlock.
Future<WeekReview> makeWeekReview(
  AppDatabase db,
  DateTime start, {
  required DateTime now,
  ReportClientFactory? clientFactory,
}) async {
  final written = await WeekReviewer(
    db,
    clientFactory: clientFactory,
  ).write(start, now: now);
  if (written != null) return written;

  final facts = await buildWeekFacts(db, start, now: now);
  await db.reportsDao.saveWeekReview(
    start: start,
    createdAt: now,
    facts: jsonEncode(facts.toJson()),
  );
  return WeekReview(facts: facts, createdAt: now);
}

/// `Je week: 3 van 4 trainingen`.
String weekTitle(WeekFacts facts) {
  if (facts.planned case final planned?) {
    return 'Je week: ${facts.plannedDone} van $planned trainingen';
  }
  return facts.workouts == 1
      ? 'Je week: 1 training'
      : 'Je week: ${facts.workouts} trainingen';
}

/// `64 sets · 2 records · 7 u 5 slaap per nacht`, for when there is no text
/// of the coach.
String weekSummary(WeekFacts facts) {
  final sleep = facts.sleepMinutes;
  return [
    '${facts.sets} sets',
    if (facts.records.length == 1) '1 record',
    if (facts.records.length > 1) '${facts.records.length} records',
    if (sleep != null)
      '${sleep ~/ 60} u${sleep % 60 == 0 ? '' : ' ${sleep % 60}'} slaap per '
          'nacht',
  ].join(' · ');
}

/// What the Sunday run shows.
abstract interface class WeekNotices {
  Future<void> showReview(WeekReview review);

  /// With a PIN the logbook stays shut until you open it; this says the
  /// review waits for that.
  Future<void> showLocked();

  Future<bool> isShowing();
}

class NotificationWeekNotices implements WeekNotices {
  const NotificationWeekNotices();

  @override
  Future<void> showReview(WeekReview review) async {
    await NotificationService.instance.initialise();
    await NotificationService.instance.showWeekReview(
      title: weekTitle(review.facts),
      body: review.coachText ?? weekSummary(review.facts),
      start: review.facts.start,
    );
  }

  @override
  Future<void> showLocked() async {
    await NotificationService.instance.initialise();
    await NotificationService.instance.showWeekReview(
      title: 'Weekoverzicht',
      body:
          'Je week staat klaar. Ontgrendel FitLog om ze te zien: met een '
          'pincode blijft je logboek dicht tot jij het opent.',
      start: weekStartOf(DateTime.now()),
    );
  }

  @override
  Future<bool> isShowing() => NotificationService.instance.weekReviewShowing;
}

enum WeekOutcome { handedOff, locked, switchedOff, reported, nothing }

/// One Sunday alarm, from start to finish, with everything it touches handed
/// in so a test can stand in for Android.
class WeekAlarmHandler {
  WeekAlarmHandler({
    required this.schedule,
    required this.handOff,
    required this.keys,
    required this.openDatabase,
    required this.notices,
    this.clientFactory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WeekSchedule schedule;
  final Future<bool> Function() handOff;
  final KeyManager keys;
  final Future<AppDatabase> Function(Uint8List key) openDatabase;
  final WeekNotices notices;
  final ReportClientFactory? clientFactory;
  final DateTime Function() _clock;

  Future<WeekOutcome> handle() async {
    final now = _clock();
    // Next Sunday's first, so a failure below does not end the Sundays.
    await schedule.apply(
      enabled: true,
      now: now.add(const Duration(minutes: 1)),
    );

    if (await handOff()) return WeekOutcome.handedOff;

    final status = await keys.status();
    if (!status.initialised) return WeekOutcome.nothing;
    if (status.mode == LockMode.pin) {
      await notices.showLocked();
      return WeekOutcome.locked;
    }
    final key = await keys.readDirectKey();
    if (key == null) {
      await notices.showLocked();
      return WeekOutcome.locked;
    }

    final db = await openDatabase(key);
    try {
      final settings = await db.settingsDao.getSettings();
      if (!settings.weekReviewNotify) {
        await schedule.apply(enabled: false);
        return WeekOutcome.switchedOff;
      }
      final review = await makeWeekReview(
        db,
        weekStartOf(now),
        now: now,
        clientFactory: clientFactory,
      );
      await notices.showReview(review);
      return WeekOutcome.reported;
    } finally {
      await db.close();
    }
  }
}
