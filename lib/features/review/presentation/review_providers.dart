import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/db/database.dart';
import '../../../core/util/notification_service.dart';
import '../../../core/widgets/week_navigator.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/week_alarm.dart';
import '../data/week_facts_builder.dart';
import '../data/week_reviewer.dart';
import '../domain/week_facts.dart';

part 'review_providers.g.dart';

/// The week from [start], worked out from the logbook as it is now.
@riverpod
Future<WeekFacts> weekFacts(Ref ref, DateTime start) =>
    buildWeekFacts(ref.watch(databaseProvider), start);

/// What the coach wrote about the week from [start], if it did.
@riverpod
Stream<WeekReview?> weekReview(Ref ref, DateTime start) => ref
    .watch(databaseProvider)
    .reportsDao
    .watchWeekReview(start)
    .map((row) => row == null ? null : WeekReview.fromRow(row));

class WeekReviewState {
  const WeekReviewState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Having the coach write about a week.
@Riverpod(keepAlive: true)
class WeekReviewController extends _$WeekReviewController {
  @override
  WeekReviewState build() => const WeekReviewState();

  Future<WeekReview?> write(DateTime start, {DateTime? now}) async {
    if (state.busy) return null;
    state = const WeekReviewState(busy: true);
    try {
      final review = await WeekReviewer(
        ref.read(databaseProvider),
        clientFactory: ref.read(coachClientFactoryProvider),
      ).write(start, now: now);
      if (ref.mounted) state = const WeekReviewState();
      return review;
    } on Object catch (error) {
      if (ref.mounted) {
        state = WeekReviewState(
          error: 'Het weekoverzicht laten schrijven lukte niet: $error',
        );
      }
      return null;
    }
  }
}

/// The Sunday alarm. Overridden in tests with one that only remembers.
@Riverpod(keepAlive: true)
WeekSchedule weekSchedule(Ref ref) => const WeekSchedule(AndroidWeekAlarm());

/// Where the review is shown outside the app. Overridden in tests.
@Riverpod(keepAlive: true)
WeekNotices weekNotices(Ref ref) => const NotificationWeekNotices();

/// The Sunday evening notification: the switch, the alarm, and making the
/// review when the alarm finds the app open or locked.
@Riverpod(keepAlive: true)
WeekNotify weekNotify(Ref ref) => WeekNotify(ref);

class WeekNotify {
  WeekNotify(this.ref);

  final Ref ref;

  AppDatabase get _db => ref.read(databaseProvider);

  /// How long after its Sunday evening a week is still made on an unlock:
  /// a phone that was off on Sunday night still gets Monday's.
  static const Duration catchUpFor = Duration(days: 2);

  Future<void> enable() async {
    await NotificationService.instance.requestPermissions();
    await _db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(weekReviewNotify: Value(true)),
    );
    await syncAlarm();
  }

  Future<void> disable() async {
    await _db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(weekReviewNotify: Value(false)),
    );
    await syncAlarm();
  }

  /// Puts the alarm where the setting says. Run on every unlock: an update,
  /// a force stop or a restore can all leave it missing - and it is on for
  /// everyone until switched off, so the first unlock after the update is
  /// what sets it at all.
  Future<void> syncAlarm({DateTime? now}) async {
    final settings = await _db.settingsDao.getSettings();
    try {
      await ref
          .read(weekScheduleProvider)
          .apply(enabled: settings.weekReviewNotify, now: now);
    } on Object {
      // Opening the app must never fail on an alarm; the next unlock tries
      // again.
    }
  }

  /// The alarm went off while the app was running, and handed it over.
  Future<void> onAlarm({DateTime? now}) async {
    final notices = ref.read(weekNoticesProvider);
    if (ref.read(appControllerProvider) is! AppReady) {
      await notices.showLocked();
      return;
    }
    final at = now ?? DateTime.now();
    final review = await makeWeekReview(
      _db,
      weekStartOf(at),
      now: at,
      clientFactory: ref.read(coachClientFactoryProvider),
    );
    await notices.showReview(review);
  }

  /// After an unlock: makes the review of the week whose Sunday evening last
  /// went by, if a PIN or a phone that was off kept it from being made. When
  /// the notification that it waits for is still there, the review takes its
  /// place; otherwise it is simply there on the screen.
  Future<void> catchUp({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final settings = await _db.settingsDao.getSettings();
    if (!settings.weekReviewNotify) return;

    final due = lastSundayEvening(at);
    if (at.difference(due) > catchUpFor) return;
    final start = weekStartOf(due);
    if (await _db.reportsDao.weekReviewFor(start) != null) return;

    final notices = ref.read(weekNoticesProvider);
    final waiting = await notices.isShowing();
    final review = await makeWeekReview(
      _db,
      start,
      now: at,
      clientFactory: ref.read(coachClientFactoryProvider),
    );
    if (waiting) await notices.showReview(review);
  }
}
