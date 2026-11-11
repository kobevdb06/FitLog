import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/feedback_service.dart';
import '../../../routing/routes.dart';
import '../domain/rest_timer.dart';
import 'workout_providers.dart';

/// How long "Rust voorbij" stays once the rest is over. Long enough to see
/// when you look up between sets, short enough not to sit there through the
/// next one.
const Duration kRestOverShown = Duration(seconds: 30);

/// The compact rest bar under the set list.
///
/// The countdown is recomputed from the stored end timestamp on every tick, so
/// it stays correct across a trip to the background.
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(_checkFinished);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _checkFinished() {
    final state = ref.read(restTimerProvider);
    if (!state.isActive || !state.hasElapsed()) return;
    final notifier = ref.read(restTimerProvider.notifier);

    // Over for a while: the bar has said so, and goes. The sound is not the
    // bar's: [RestSignal] makes it, wherever you are (DECISIONS 285).
    if (DateTime.now().isAfter(state.endsAt!.add(kRestOverShown))) {
      notifier.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(restTimerProvider);
    if (!state.isActive) return const SizedBox.shrink();

    final remaining = state.remainingSeconds();
    final notifier = ref.read(restTimerProvider.notifier);
    final done = remaining <= 0;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: state.progress(),
              minHeight: 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: done
                  ? AppColors.successOf(context)
                  : AppColors.accentOf(context),
            ),
            InkWell(
              onTap: () => context.push(Routes.restTimer),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.timer_outlined,
                      color: done
                          ? AppColors.successOf(context)
                          : AppColors.accentOf(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      done ? 'Rust voorbij' : Formatters.duration(remaining),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: done ? AppColors.successOf(context) : null,
                      ),
                    ),
                    const Spacer(),
                    // Once it is over there is nothing to shorten or
                    // lengthen, and nothing to skip: only closing it.
                    if (done)
                      IconButton(
                        tooltip: 'Sluiten',
                        onPressed: notifier.skip,
                        icon: const Icon(Icons.close),
                      )
                    else ...[
                      TextButton(
                        onPressed: () => notifier.adjust(-15),
                        child: const Text('-15'),
                      ),
                      TextButton(
                        onPressed: () => notifier.adjust(15),
                        child: const Text('+15'),
                      ),
                      IconButton(
                        tooltip: 'Overslaan',
                        onPressed: notifier.skip,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of a rest, said once while FitLog is in sight - whatever screen
/// is up, the keypad too. It was the rest bar's, and the bar gives way to
/// the keypad: typing your weights, you heard nothing (DECISIONS 285). Out
/// of sight, the notification says it.
class RestSignal extends ConsumerStatefulWidget {
  const RestSignal({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RestSignal> createState() => _RestSignalState();
}

class _RestSignalState extends ConsumerState<RestSignal> {
  Timer? _over;

  @override
  void initState() {
    super.initState();
    _follow(ref.read(restTimerProvider));
  }

  @override
  void dispose() {
    _over?.cancel();
    super.dispose();
  }

  void _follow(RestTimerState state) {
    _over?.cancel();
    _over = null;
    final endsAt = state.endsAt;
    if (endsAt == null || state.finishedHandled) return;
    final left = endsAt.difference(DateTime.now());
    _over = Timer(left.isNegative ? Duration.zero : left, _sound);
  }

  void _sound() {
    if (!mounted) return;
    // Out of sight the notification says it; both at once was the trouble.
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) return;
    final state = ref.read(restTimerProvider);
    if (!state.isActive || state.finishedHandled || !state.hasElapsed()) return;
    // Long over - coming back to the app: the notification said it.
    if (DateTime.now().isAfter(state.endsAt!.add(kRestOverShown))) return;
    ref.read(restTimerProvider.notifier).markFinishedHandled();
    final settings = ref.read(settingsProvider).value;
    FeedbackService(setCheckSoundEnabled: settings?.restSoundEnabled ?? true)
        .restFinished();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(restTimerProvider, (_, next) => _follow(next));
    return widget.child;
  }
}
