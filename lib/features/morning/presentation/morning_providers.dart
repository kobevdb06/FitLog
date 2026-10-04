import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/util/notification_service.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../health/presentation/health_providers.dart';
import '../data/morning_alarm.dart';
import '../data/morning_reporter.dart';
import '../data/morning_run.dart';

part 'morning_providers.g.dart';

/// The last week or so of reports, newest first.
@riverpod
Stream<List<MorningReport>> morningReports(Ref ref) => ref
    .watch(databaseProvider)
    .reportsDao
    .watchReports()
    .map((rows) => [for (final row in rows) MorningReport.fromRow(row)]);

/// The reports of the week from [start], newest first.
@riverpod
Stream<List<MorningReport>> reportsInWeek(Ref ref, DateTime start) => ref
    .watch(databaseProvider)
    .reportsDao
    .watchReportsBetween(
      start,
      DateTime(start.year, start.month, start.day + 7),
    )
    .map((rows) => [for (final row in rows) MorningReport.fromRow(row)]);

/// Whether the report is made on its own every morning.
@riverpod
bool morningReportEnabled(Ref ref) =>
    ref.watch(settingsProvider).value?.morningReportEnabled ?? false;

/// At what time, in minutes after midnight.
@riverpod
int morningReportMinutes(Ref ref) =>
    ref.watch(settingsProvider).value?.morningReportMinutes ?? 420;

/// The alarm. Overridden in tests with one that only remembers.
@Riverpod(keepAlive: true)
MorningSchedule morningSchedule(Ref ref) =>
    const MorningSchedule(AndroidMorningAlarm());

/// Where the report is shown outside the app. Overridden in tests.
@Riverpod(keepAlive: true)
MorningNotices morningNotices(Ref ref) => const NotificationMorningNotices();

class MorningState {
  const MorningState({this.busy = false, this.error, this.notice});

  final bool busy;
  final String? error;

  /// Something worth knowing that is not an error: a permission that was
  /// refused, and what that means for the report.
  final String? notice;
}

/// Making a report, now or at the hour, and keeping that hour.
@Riverpod(keepAlive: true)
class MorningController extends _$MorningController {
  @override
  MorningState build() => const MorningState();

  AppDatabase get _db => ref.read(databaseProvider);

  Future<MorningReport?> makeNow({DateTime? now}) async {
    if (state.busy) return null;
    state = MorningState(busy: true, notice: state.notice);
    try {
      final report = await runMorning(
        db: _db,
        source: ref.read(healthSourceProvider),
        clientFactory: ref.read(coachClientFactoryProvider),
        now: now,
      );
      if (ref.mounted) state = MorningState(notice: state.notice);
      return report;
    } on Object catch (error) {
      if (ref.mounted) {
        state = MorningState(error: 'Het rapport opstellen lukte niet: $error');
      }
      return null;
    }
  }

  /// Switches the morning report on: asks what it needs, then sets the
  /// alarm.
  ///
  /// A refusal does not stop it. Without notifications the report is still
  /// made and waits on the recovery screen; without reading in the
  /// background it is made from what came in the last time the app was open.
  Future<void> enable() async {
    await NotificationService.instance.requestPermissions();

    String? notice;
    final settings = await _db.settingsDao.getSettings();
    if (settings.healthConnectEnabled) {
      final background = await ref
          .read(healthSourceProvider)
          .requestBackgroundAccess();
      if (!background) {
        notice =
            'Health Connect gaf geen toegang op de achtergrond. Het rapport '
            'komt er toch, maar met wat er binnen was toen je de app het '
            'laatst opende.';
      }
    }

    await _db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(morningReportEnabled: Value(true)),
    );
    await syncAlarm();
    if (ref.mounted) state = MorningState(notice: notice);
  }

  Future<void> disable() async {
    await _db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(morningReportEnabled: Value(false)),
    );
    await syncAlarm();
    if (ref.mounted) state = const MorningState();
  }

  Future<void> setMinutes(int minutes) async {
    await _db.settingsDao.updateSettings(
      AppSettingsTableCompanion(morningReportMinutes: Value(minutes)),
    );
    await syncAlarm();
  }

  /// Puts the alarm where the setting says. Run on every unlock as well: an
  /// update, a force stop or a restore can all leave it missing.
  Future<void> syncAlarm({DateTime? now}) async {
    final settings = await _db.settingsDao.getSettings();
    try {
      await ref
          .read(morningScheduleProvider)
          .apply(
            enabled: settings.morningReportEnabled,
            minutes: settings.morningReportMinutes,
            now: now,
          );
    } on Object catch (error) {
      // Opening the app must never fail on an alarm; the next unlock tries
      // again.
      if (ref.mounted) {
        state = MorningState(
          error: 'Het uur van het ochtendrapport instellen lukte niet: $error',
        );
      }
    }
  }

  /// The alarm went off while the app was running, and handed it over.
  Future<void> onAlarm() async {
    final notices = ref.read(morningNoticesProvider);
    if (ref.read(appControllerProvider) is! AppReady) {
      // Locked: the report waits for the unlock, as with a closed app.
      await notices.showLocked();
      return;
    }
    final report = await makeNow();
    if (report != null) await notices.showReport(report);
  }

  /// After an unlock: makes this morning's report if its hour has passed and
  /// there is none yet - because a PIN kept the alarm out, or the phone was
  /// off. If the notification that it waits for is still there, the report
  /// takes its place.
  Future<void> catchUp({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final settings = await _db.settingsDao.getSettings();
    if (!settings.morningReportEnabled) return;

    final due = DateTime(
      at.year,
      at.month,
      at.day,
      settings.morningReportMinutes ~/ 60,
      settings.morningReportMinutes % 60,
    );
    if (at.isBefore(due)) return;
    if (await _db.reportsDao.reportFor(at) != null) return;

    final notices = ref.read(morningNoticesProvider);
    final waiting = await notices.isShowing();
    final report = await makeNow(now: at);
    if (report != null && waiting) await notices.showReport(report);
  }
}
