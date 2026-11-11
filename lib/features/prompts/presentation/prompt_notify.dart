import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/util/notification_service.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/prompt_alarm.dart';

part 'prompt_notify.g.dart';

/// The alarm of the geplande prompts. Overridden in tests with one that only
/// remembers.
@Riverpod(keepAlive: true)
PromptSchedule promptSchedule(Ref ref) =>
    const PromptSchedule(AndroidPromptAlarm());

/// Where what the coach said is shown outside the app. Overridden in tests.
@Riverpod(keepAlive: true)
PromptNotices promptNotices(Ref ref) => const NotificationPromptNotices();

@Riverpod(keepAlive: true)
PromptNotify promptNotify(Ref ref) => PromptNotify(ref);

/// The geplande prompts that come with a notification: the alarm, and the
/// asking when the alarm finds the app open or after an unlock.
class PromptNotify {
  PromptNotify(this.ref);

  final Ref ref;

  /// Puts the alarm where the prompts say. Run on every unlock and after a
  /// change: an update, a force stop or a restore can all leave it missing.
  Future<void> syncAlarm({DateTime? now}) async {
    try {
      final times = await PromptTimes.load(ref.read(databaseProvider));
      await ref.read(promptScheduleProvider).apply(times, now: now);
    } on Object {
      // Opening the app must never fail on an alarm; the next unlock tries
      // again.
    }
  }

  /// One of them was switched on: notifications are what it comes with.
  Future<void> switchedOn() async {
    await NotificationService.instance.requestPermissions();
    await syncAlarm();
  }

  /// The alarm went off while the app was running, and handed it over.
  Future<void> onAlarm({DateTime? now}) async {
    final notices = ref.read(promptNoticesProvider);
    if (ref.read(appControllerProvider) is! AppReady) {
      await notices.showLocked();
      return;
    }
    final runs = await runDuePrompts(
      ref.read(databaseProvider),
      now: now ?? DateTime.now(),
      clientFactory: ref.read(coachClientFactoryProvider),
    );
    if (runs.isEmpty) return;
    if (!await wordsInNotifications(ref)) {
      await notices.showLocked();
      return;
    }
    for (final run in runs) {
      await notices.show(run);
    }
  }

  /// After an unlock: asks what a PIN or a phone that was off kept from
  /// being asked. Shown in place of the notification that it waited, if
  /// that is there; otherwise it is simply there, in the chat or on the
  /// month.
  Future<void> catchUp({DateTime? now}) async {
    final notices = ref.read(promptNoticesProvider);
    final waiting = await notices.lockedShowing();
    final runs = await runDuePrompts(
      ref.read(databaseProvider),
      now: now ?? DateTime.now(),
      clientFactory: ref.read(coachClientFactoryProvider),
    );
    // Behind a PIN, the notice that it waits stays as it is.
    if (!waiting || !await wordsInNotifications(ref)) return;
    for (final run in runs) {
      await notices.show(run);
    }
  }
}
