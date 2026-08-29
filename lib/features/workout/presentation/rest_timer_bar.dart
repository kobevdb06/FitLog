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
import 'workout_providers.dart';

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
    if (!state.isActive || state.finishedHandled) return;
    if (!state.hasElapsed()) return;

    ref.read(restTimerProvider.notifier).markFinishedHandled();
    final settings = ref.read(settingsProvider).value;
    FeedbackService(
      setCheckSoundEnabled: settings?.restSoundEnabled ?? true,
    ).restFinished();
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
              color: done ? AppColors.success : AppColors.accent,
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
                      color: done ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      done ? 'Rust voorbij' : Formatters.duration(remaining),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: done ? AppColors.success : null,
                      ),
                    ),
                    const Spacer(),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
