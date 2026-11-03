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
import '../../morning/data/morning_alarm.dart' show handOffToOpenApp;
import '../domain/coach_moments.dart';
import 'moment_answerer.dart';
import 'moment_asker.dart';
import 'moment_facts.dart';

/// The geplande prompts that come with a notification, and when, as the
/// alarm carries them: so the next one can be set without the database,
/// which a PIN keeps shut.
class PromptTimes {
  const PromptTimes({this.idle = false, this.free, this.month = false});

  factory PromptTimes.of(Iterable<MomentPrompt> prompts) {
    var idle = false;
    FreeTime? free;
    var month = false;
    for (final prompt in prompts) {
      if (!prompt.enabled) continue;
      switch (prompt.moment) {
        case CoachMoment.idle:
          idle = true;
        case CoachMoment.free:
          free = prompt.freeTime;
        case CoachMoment.month:
          month = true;
        default:
      }
    }
    return PromptTimes(idle: idle, free: free, month: month);
  }

  factory PromptTimes.fromParams(Map<String, dynamic> params) {
    final weekday = params['freeWeekday'];
    final hour = params['freeHour'];
    return PromptTimes(
      idle: params['idle'] == true,
      free: weekday is int && hour is int
          ? (weekday: weekday, hour: hour)
          : null,
      month: params['month'] == true,
    );
  }

  static Future<PromptTimes> load(AppDatabase db) async => PromptTimes.of([
    for (final moment in const [
      CoachMoment.idle,
      CoachMoment.free,
      CoachMoment.month,
    ])
      await MomentPrompt.load(db, moment),
  ]);

  /// Whether a day without training is looked at, every day at [kIdleHour].
  final bool idle;
  final FreeTime? free;
  final bool month;

  bool get any => idle || free != null || month;

  Map<String, dynamic> toParams() => {
    'idle': idle,
    'freeWeekday': ?free?.weekday,
    'freeHour': ?free?.hour,
    'month': month,
  };

  /// The first moment after [now] at which one of them is due; null when
  /// none is on.
  DateTime? nextAfter(DateTime now) {
    final candidates = <DateTime>[
      if (idle) _nextDaily(now, kIdleHour),
      if (free case final time?) _nextWeekly(now, time),
      if (month) _nextMonthly(now),
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.isBefore(b) ? a : b);
  }
}

DateTime _nextDaily(DateTime now, int hour) {
  final today = DateTime(now.year, now.month, now.day, hour);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, hour);
}

DateTime _nextWeekly(DateTime now, FreeTime time) {
  final days = (time.weekday - now.weekday) % 7;
  final at = DateTime(now.year, now.month, now.day + days, time.hour);
  return at.isAfter(now)
      ? at
      : DateTime(at.year, at.month, at.day + 7, time.hour);
}

DateTime _nextMonthly(DateTime now) {
  final first = DateTime(now.year, now.month, 1, kMonthHour);
  return first.isAfter(now)
      ? first
      : DateTime(now.year, now.month + 1, 1, kMonthHour);
}

/// The vrij moment that last went by, up to and including [now].
DateTime lastFreeTime(DateTime now, FreeTime time) {
  final next = _nextWeekly(now, time);
  return DateTime(next.year, next.month, next.day - 7, time.hour);
}

/// The first of the month that last went by at [kMonthHour].
DateTime lastMonthTurn(DateTime now) {
  final first = DateTime(now.year, now.month, 1, kMonthHour);
  return first.isAfter(now)
      ? DateTime(now.year, now.month - 1, 1, kMonthHour)
      : first;
}

/// What a run of the alarm found to say: the moment, and the answer.
typedef PromptRun = ({
  CoachMoment moment,
  String subject,
  MomentAnswerView answer,
});

/// How long after its moment a prompt is still asked: a phone that was off,
/// or a PIN that was not entered, still gets it a little later - not a
/// nudge from last month.
const Duration kPromptCatchUp = Duration(days: 2);

/// Asks every geplande prompt that is due at [now] and was not asked yet,
/// and returns what came back.
Future<List<PromptRun>> runDuePrompts(
  AppDatabase db, {
  required DateTime now,
  MomentClientFactory? clientFactory,
}) async {
  final answerer = MomentAnswerer(db, clientFactory: clientFactory);
  final runs = <PromptRun>[];

  Future<void> run(CoachMoment moment, String subject) async {
    if (!await answerer.isDue(moment, subject, now: now)) return;
    final answer = await answerer.answer(moment, subject, now: now);
    if (answer != null) {
      runs.add((moment: moment, subject: subject, answer: answer));
    }
  }

  final idle = await MomentPrompt.load(db, CoachMoment.idle);
  if (idle.enabled && now.hour >= kIdleHour) {
    final last = await db.workoutsDao.watchLastFinished().first;
    if (last != null) {
      final day = DateTime.fromMillisecondsSinceEpoch(last.startedAt);
      final days = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(day.year, day.month, day.day)).inDays;
      // Once per stretch without training: the stretch is named after the
      // workout it started from.
      if (days >= idle.idleDays) await run(CoachMoment.idle, last.id);
    }
  }

  final free = await MomentPrompt.load(db, CoachMoment.free);
  if (free.enabled) {
    final due = lastFreeTime(now, free.freeTime);
    if (now.difference(due) <= kPromptCatchUp) {
      await run(CoachMoment.free, MomentSubject.day(due));
    }
  }

  final month = await MomentPrompt.load(db, CoachMoment.month);
  if (month.enabled) {
    final turn = lastMonthTurn(now);
    if (now.difference(turn) <= kPromptCatchUp) {
      await run(
        CoachMoment.month,
        MomentSubject.month(DateTime(turn.year, turn.month - 1)),
      );
    }
  }
  return runs;
}

/// Something that can wake the app at a moment, once, with what it needs.
abstract interface class PromptAlarm {
  Future<void> setAt(DateTime at, PromptTimes times);
  Future<void> cancel();
}

/// Keeps the one alarm in step with the prompts.
class PromptSchedule {
  const PromptSchedule(this.alarm);

  final PromptAlarm alarm;

  Future<void> apply(PromptTimes times, {DateTime? now}) async {
    final next = times.nextAfter(now ?? DateTime.now());
    if (next == null) {
      await alarm.cancel();
      return;
    }
    await alarm.setAt(next, times);
  }
}

/// Android's AlarmManager, as for the morning report and the week.
class AndroidPromptAlarm implements PromptAlarm {
  const AndroidPromptAlarm();

  static const int id = 7303;
  static bool _started = false;

  @override
  Future<void> setAt(DateTime at, PromptTimes times) async {
    if (!Platform.isAndroid) return;
    if (!_started) {
      await AndroidAlarmManager.initialize();
      _started = true;
    }
    await AndroidAlarmManager.oneShotAt(
      at,
      id,
      promptAlarm,
      exact: false,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
      params: times.toParams(),
    );
  }

  @override
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(id);
  }
}

/// The name under which the running app listens for this alarm.
const String kPromptsPortName = 'fitlog.prompts';

/// Where the alarm lands: a separate isolate started by Android.
@pragma('vm:entry-point')
Future<void> promptAlarm(int id, Map<String, dynamic> params) async {
  DartPluginRegistrant.ensureInitialized();
  await PromptAlarmHandler(
    times: PromptTimes.fromParams(params),
    schedule: const PromptSchedule(AndroidPromptAlarm()),
    handOff: () => handOffToOpenApp(portName: kPromptsPortName),
    keys: KeyManager(SecureStorageSecretStore()),
    openDatabase: (key) async => AppDatabase(
      openEncryptedExecutor(
        file: (await AppPaths.resolve()).databaseFile,
        keyHex: toHex(key),
      ),
    ),
    notices: const NotificationPromptNotices(),
  ).handle();
}

/// What a run shows.
abstract interface class PromptNotices {
  Future<void> show(PromptRun run);

  /// With a PIN the logbook stays shut until you open it; this says
  /// something waits for that.
  Future<void> showLocked();

  Future<bool> lockedShowing();
}

class NotificationPromptNotices implements PromptNotices {
  const NotificationPromptNotices();

  @override
  Future<void> show(PromptRun run) async {
    final answer = run.answer;
    await NotificationService.instance.initialise();
    await NotificationService.instance.showCoachMoment(
      id: NotificationService.promptNotificationId(run.moment.index),
      title: run.moment == CoachMoment.month
          ? 'Je maand'
          : 'De coach: ${run.moment.title.toLowerCase()}',
      body: answer.coachText ?? answer.coachError ?? run.moment.title,
      payload: switch (answer.threadId) {
        final thread? => '${NotificationService.threadPayloadPrefix}$thread',
        null when run.moment == CoachMoment.month =>
          '${NotificationService.monthPayloadPrefix}${run.subject}',
        null => null,
      },
    );
  }

  @override
  Future<void> showLocked() async {
    await NotificationService.instance.initialise();
    await NotificationService.instance.showCoachMoment(
      id: NotificationService.promptLockedNotificationId,
      title: 'De coach',
      body:
          'Er staat iets van de coach klaar. Ontgrendel FitLog om het te '
          'zien: met een pincode blijft je logboek dicht tot jij het opent.',
    );
  }

  @override
  Future<bool> lockedShowing() => NotificationService.instance.isShowing(
    NotificationService.promptLockedNotificationId,
  );
}

enum PromptOutcome { handedOff, locked, asked, nothing }

/// One alarm, from start to finish, with everything it touches handed in so
/// a test can stand in for Android.
class PromptAlarmHandler {
  PromptAlarmHandler({
    required this.times,
    required this.schedule,
    required this.handOff,
    required this.keys,
    required this.openDatabase,
    required this.notices,
    this.clientFactory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// What the alarm was set with.
  final PromptTimes times;
  final PromptSchedule schedule;
  final Future<bool> Function() handOff;
  final KeyManager keys;
  final Future<AppDatabase> Function(Uint8List key) openDatabase;
  final PromptNotices notices;
  final MomentClientFactory? clientFactory;
  final DateTime Function() _clock;

  Future<PromptOutcome> handle() async {
    final now = _clock();
    // The next one first, so a failure below does not end them.
    await schedule.apply(times, now: now.add(const Duration(minutes: 1)));

    if (await handOff()) return PromptOutcome.handedOff;

    final status = await keys.status();
    if (!status.initialised) return PromptOutcome.nothing;
    final key = status.mode == LockMode.pin ? null : await keys.readDirectKey();
    if (key == null) {
      await notices.showLocked();
      return PromptOutcome.locked;
    }

    final db = await openDatabase(key);
    try {
      final runs = await runDuePrompts(
        db,
        now: now,
        clientFactory: clientFactory,
      );
      for (final run in runs) {
        await notices.show(run);
      }
      return runs.isEmpty ? PromptOutcome.nothing : PromptOutcome.asked;
    } finally {
      await db.close();
    }
  }
}
