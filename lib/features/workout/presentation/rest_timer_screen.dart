import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import 'workout_providers.dart';

/// The full screen countdown, reached by tapping the rest bar.
class RestTimerScreen extends ConsumerStatefulWidget {
  const RestTimerScreen({super.key});

  @override
  ConsumerState<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends ConsumerState<RestTimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(restTimerProvider);
    final notifier = ref.read(restTimerProvider.notifier);

    if (!state.isActive) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.timer_off_outlined,
          title: 'Geen rusttimer',
          message: 'De timer start zodra je een set afvinkt.',
          actionLabel: 'Terug',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    final remaining = state.remainingSeconds();
    final done = remaining <= 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Rust'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: state.progress(),
                          strokeWidth: 10,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: done ? AppColors.success : AppColors.accent,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            done
                                ? 'Klaar'
                                : Formatters.duration(remaining),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: done ? AppColors.success : null,
                            ),
                          ),
                          if (state.totalSeconds > 0)
                            Text(
                              'van ${Formatters.duration(state.totalSeconds)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (state.exerciseName != null)
                Column(
                  children: [
                    Text(
                      'Hierna',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      state.exerciseName!,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => notifier.adjust(-15),
                      child: const Text('-15 s'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => notifier.adjust(15),
                      child: const Text('+15 s'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () async {
                  await notifier.skip();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Overslaan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
