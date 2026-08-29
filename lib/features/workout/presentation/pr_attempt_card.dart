import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../domain/pr_ramp.dart';
import 'pr_attempt_providers.dart';

/// The strip above a PR attempt inside the running session.
///
/// It answers the two things you want to know with a loaded bar in front of
/// you: what am I going for, and how many warm-ups are left.
class PrAttemptHeader extends StatelessWidget {
  const PrAttemptHeader({
    super.key,
    required this.detail,
    required this.formatters,
  });

  final WorkoutExerciseDetail detail;
  final Formatters formatters;

  /// The attempt is the only working set in the ladder.
  static int warmupsDone(WorkoutExerciseDetail detail) => detail.sets
      .where(
        (s) => SetType.fromWire(s.setType) == SetType.warmup && s.isCompleted,
      )
      .length;

  static int warmupsTotal(WorkoutExerciseDetail detail) => detail.sets
      .where((s) => SetType.fromWire(s.setType) == SetType.warmup)
      .length;

  /// True once every warm-up but the last one is done.
  static bool onLastWarmup(WorkoutExerciseDetail detail) {
    final total = warmupsTotal(detail);
    return total > 0 && warmupsDone(detail) == total - 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = detail.workoutExercise.prTargetWeightKg;
    final result = PrAttemptResult.fromWire(detail.workoutExercise.prResult);

    final done = warmupsDone(detail);
    final total = warmupsTotal(detail);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.record.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 16,
                color: AppColors.record,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  target == null
                      ? 'PR-poging'
                      : 'PR-poging · doel ${formatters.weight(target)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.record,
                  ),
                ),
              ),
              if (result != null)
                Text(
                  result.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: result == PrAttemptResult.success
                        ? AppColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (result == null && total > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: done / total,
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: AppColors.record,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  done >= total
                      ? 'Klaar voor de poging'
                      : 'Opwarmset ${done + 1} van $total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (onLastWarmup(detail)) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Nog een opwarmer, dan de poging.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.record,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// What happens after the attempt set is ticked, or given up on.
///
/// No judgement either way: a missed attempt is information, and the offer is
/// a back-off single or simply stopping.
Future<void> showPrOutcomeSheet(
  BuildContext context,
  WidgetRef ref, {
  required WorkoutExerciseDetail detail,
  required PrAttemptResult result,
  required double achievedKg,
  required int extraAttemptsLeft,
}) async {
  final formatters = ref.read(formattersProvider);
  final setup = ref.read(barbellSetupProvider);
  final actions = ref.read(prAttemptActionsProvider);

  await actions.finish(detail.workoutExercise.id, result);

  if (!context.mounted) return;

  final nextTarget = nextTargetAfterSuccess(
    achievedKg: achievedKg,
    platesKg: setup.platesKg,
  );
  final backoff = backoffAfterFailure(
    previousBestKg: achievedKg,
    barKg: setup.barKg,
    platesKg: setup.platesKg,
  );

  await showAppSheet<void>(
    context: context,
    title: result == PrAttemptResult.success
        ? 'Gelukt: ${formatters.weight(achievedKg)}'
        : 'Poging niet gelukt',
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result == PrAttemptResult.success) ...[
            Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: AppColors.record,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Nieuw record op ${formatters.weight(achievedKg)}. '
                    'Dat staat nu in je geschiedenis.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (extraAttemptsLeft > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await actions.addFollowUpAttempt(
                    workoutExerciseId: detail.workoutExercise.id,
                    achievedKg: achievedKg,
                    platesKg: setup.platesKg,
                    barKg: setup.barKg,
                  );
                },
                child: Text(
                  'Nog een poging op ${formatters.weight(nextTarget)}',
                ),
              ),
            ],
          ] else ...[
            Text(
              'Vandaag zat het er niet in. Dat gebeurt, en de poging blijft '
              'in je geschiedenis staan.',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await actions.addBackoffSingle(
                  workoutExerciseId: detail.workoutExercise.id,
                  previousBestKg: achievedKg,
                  platesKg: setup.platesKg,
                  barKg: setup.barKg,
                );
              },
              child: Text(
                'Back-off single op ${formatters.weight(backoff)}',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Afsluiten'),
          ),
        ],
      ),
    ),
  );
}
