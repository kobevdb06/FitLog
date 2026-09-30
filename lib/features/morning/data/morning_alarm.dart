import 'dart:async';
import 'dart:io';
import 'dart:isolate';
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
import '../../health/data/health_connect_source.dart';
import '../../health/data/health_source.dart';
import '../domain/morning_facts.dart';
import 'morning_reporter.dart';
import 'morning_run.dart';

/// When the next morning run is due: today at [minutes] past midnight if
/// that is still ahead of [now], tomorrow otherwise.
///
/// Built from the calendar, not by adding 24 hours, so the night the clocks
/// change still wakes you at seven and not at six or eight.
DateTime nextMorning(DateTime now, int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, hour, minute);
}

/// Something that can wake the app at a moment, once.
abstract interface class MorningAlarm {
  Future<void> setAt(DateTime at, {required int minutes});
  Future<void> cancel();
}

/// Keeps the one alarm in step with the setting.
class MorningSchedule {
  const MorningSchedule(this.alarm);

  final MorningAlarm alarm;

  Future<void> apply({
    required bool enabled,
    required int minutes,
    DateTime? now,
  }) async {
    if (!enabled) {
      await alarm.cancel();
      return;
    }
    await alarm.setAt(
      nextMorning(now ?? DateTime.now(), minutes),
      minutes: minutes,
    );
  }
}

/// Android's AlarmManager, exact and allowed while the phone dozes: a
/// report at "around seven" is not what was asked for.
class AndroidMorningAlarm implements MorningAlarm {
  const AndroidMorningAlarm();

  static const int id = 7301;

  /// Whether the plugin was started in this process.
  static bool _started = false;

  @override
  Future<void> setAt(DateTime at, {required int minutes}) async {
    if (!Platform.isAndroid) return;
    // Only here, not at every start: starting the plugin also starts a
    // second, background Flutter engine that waits for the alarm, and that
    // is memory nobody without a morning report should pay for. Once
    // started, Android remembers where to hand the alarm, even after the app
    // was closed.
    if (!_started) {
      await AndroidAlarmManager.initialize();
      _started = true;
    }
    await AndroidAlarmManager.oneShotAt(
      at,
      id,
      morningAlarm,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
      // The hour rides along, so the next alarm can be set from here without
      // opening the database - which with a PIN cannot be opened at all.
      params: {'minutes': minutes},
    );
  }

  @override
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(id);
  }
}

/// The name under which the running app listens for the alarm.
const String kMorningPortName = 'fitlog.morning';

/// Where the alarm lands: a separate isolate, started by Android, with no
/// screen and nothing of the running app - if it runs at all.
@pragma('vm:entry-point')
Future<void> morningAlarm(int id, Map<String, dynamic> params) async {
  DartPluginRegistrant.ensureInitialized();
  final minutes = (params['minutes'] as num?)?.toInt() ?? 420;

  await MorningAlarmHandler(
    schedule: const MorningSchedule(AndroidMorningAlarm()),
    handOff: handOffToOpenApp,
    keys: KeyManager(SecureStorageSecretStore()),
    openDatabase: (key) async => AppDatabase(
      openEncryptedExecutor(
        file: (await AppPaths.resolve()).databaseFile,
        keyHex: toHex(key),
      ),
    ),
    source: HealthConnectSource(),
    notices: const NotificationMorningNotices(),
  ).handle(minutes: minutes);
}

/// Hands the run to the app when it is open, so two isolates never write the
/// same database at once. True when the app took it.
///
/// A name left behind by an app that is gone answers nobody; after a few
/// seconds of silence the name is cleared and the alarm does the work itself.
Future<bool> handOffToOpenApp({
  Duration wait = const Duration(seconds: 3),
}) async {
  final app = IsolateNameServer.lookupPortByName(kMorningPortName);
  if (app == null) return false;

  final reply = ReceivePort();
  try {
    app.send(reply.sendPort);
    return await reply.first.timeout(wait) == true;
  } on TimeoutException {
    IsolateNameServer.removePortNameMapping(kMorningPortName);
    return false;
  } finally {
    reply.close();
  }
}

/// What the morning run shows.
abstract interface class MorningNotices {
  Future<void> showReport(MorningReport report);

  /// With a PIN the database stays shut until you unlock; this says the
  /// report is waiting for that.
  Future<void> showLocked();

  /// Whether a morning notification is in the shade right now.
  Future<bool> isShowing();
}

class NotificationMorningNotices implements MorningNotices {
  const NotificationMorningNotices();

  @override
  Future<void> showReport(MorningReport report) async {
    await NotificationService.instance.initialise();
    await NotificationService.instance.showMorningReport(
      title: morningTitle(report.facts),
      body: report.text,
    );
  }

  @override
  Future<void> showLocked() async {
    await NotificationService.instance.initialise();
    await NotificationService.instance.showMorningReport(
      title: 'Ochtendrapport',
      body:
          'Goeiemorgen. Ontgrendel FitLog en je rapport staat klaar: met een '
          'pincode blijft je logboek dicht tot jij het opent.',
    );
  }

  @override
  Future<bool> isShowing() => NotificationService.instance.morningReportShowing;
}

enum MorningOutcome {
  /// The open app took it.
  handedOff,

  /// A PIN keeps the database shut; the report waits for the unlock.
  locked,

  /// Switched off since the alarm was set.
  switchedOff,

  /// Made and shown.
  reported,

  /// Nothing to do: the app was never set up on this phone.
  nothing,
}

/// One alarm, from start to finish, with everything it touches handed in so
/// a test can stand in for Android.
class MorningAlarmHandler {
  MorningAlarmHandler({
    required this.schedule,
    required this.handOff,
    required this.keys,
    required this.openDatabase,
    required this.source,
    required this.notices,
    this.clientFactory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MorningSchedule schedule;
  final Future<bool> Function() handOff;
  final KeyManager keys;
  final Future<AppDatabase> Function(Uint8List key) openDatabase;
  final HealthSource source;
  final MorningNotices notices;
  final ReportClientFactory? clientFactory;
  final DateTime Function() _clock;

  Future<MorningOutcome> handle({required int minutes}) async {
    final now = _clock();
    // Tomorrow's first, so a failure below does not end the mornings. A
    // minute on, so an alarm that fires on the dot does not set itself again
    // for the same moment.
    await schedule.apply(
      enabled: true,
      minutes: minutes,
      now: now.add(const Duration(minutes: 1)),
    );

    if (await handOff()) return MorningOutcome.handedOff;

    final status = await keys.status();
    if (!status.initialised) return MorningOutcome.nothing;
    // A PIN is the only way in, and it is not here. Biometrics keep a copy
    // of the key, but that copy is for after a fingerprint, not for this.
    if (status.mode == LockMode.pin) {
      await notices.showLocked();
      return MorningOutcome.locked;
    }
    final key = await keys.readDirectKey();
    if (key == null) {
      await notices.showLocked();
      return MorningOutcome.locked;
    }

    final db = await openDatabase(key);
    try {
      final settings = await db.settingsDao.getSettings();
      if (!settings.morningReportEnabled) {
        await schedule.apply(enabled: false, minutes: minutes);
        return MorningOutcome.switchedOff;
      }
      final report = await runMorning(
        db: db,
        source: source,
        clientFactory: clientFactory,
        now: now,
      );
      await notices.showReport(report);
      return MorningOutcome.reported;
    } finally {
      await db.close();
    }
  }
}
