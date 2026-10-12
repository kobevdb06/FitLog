import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/util/notification_service.dart';

part 'exact_timer_tile.g.dart';

/// Whether Android lets the rest timer's notification come on the second.
///
/// A provider so a test can say either, and the screen can ask again when
/// the user comes back from the system page where it is switched on.
@riverpod
Future<bool> exactRestTimer(Ref ref) =>
    NotificationService.instance.canTimeExactly();

/// The way to let the rest timer come on the second.
///
/// The app no longer claims exact alarms for itself (`USE_EXACT_ALARM` is
/// for alarm clocks and calendars only), so on Android 14 and later the user
/// grants it - here, knowing what it is for, rather than through a system
/// page that opened by itself at the start of every workout.
class ExactTimerTile extends ConsumerStatefulWidget {
  const ExactTimerTile({super.key});

  @override
  ConsumerState<ExactTimerTile> createState() => _ExactTimerTileState();
}

class _ExactTimerTileState extends ConsumerState<ExactTimerTile>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the system page: it may have been switched on there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(exactRestTimerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exact = ref.watch(exactRestTimerProvider).value;
    if (exact == null) return const SizedBox.shrink();

    return ListTile(
      leading: Icon(exact ? Icons.timer : Icons.timer_outlined),
      title: const Text('Rusttimer op de seconde'),
      subtitle: Text(
        exact
            ? 'Aan. De melding dat je rust voorbij is, komt op tijd.'
            : 'Uit. Android laat de melding dat je rust voorbij is dan soms '
                  'een minuut later komen als je gsm in je zak zit. Tik om het '
                  'toe te staan.',
      ),
      trailing: exact ? null : const Icon(Icons.chevron_right),
      onTap: exact
          ? null
          : () => NotificationService.instance.askToTimeExactly(),
    );
  }
}
