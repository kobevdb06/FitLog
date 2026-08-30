import 'package:flutter/material.dart';

import '../../../core/calc/recovery.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// One muscle group's line: how long it still needs, and how far along it is.
class RecoveryRow extends StatelessWidget {
  const RecoveryRow({super.key, required this.estimate, this.now});

  final RecoveryEstimate estimate;

  /// Fixed by the caller where several rows must agree on the moment.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moment = now ?? DateTime.now();
    final ready = estimate.isReadyAt(moment);
    final colour = AppColors.forMuscle(estimate.muscle);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  estimate.muscle,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                ready
                    ? 'klaar'
                    : Formatters.remainingWords(estimate.remainingAt(moment)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ready
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (estimate.provisional) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message:
                      'Nog te weinig sessies voor deze spiergroep om met je '
                      'eigen gemiddelde te vergelijken.',
                  child: Icon(
                    Icons.help_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: estimate.progressAt(moment),
              minHeight: 4,
              backgroundColor: colour.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line that keeps the estimate honest about what it is.
class RecoveryDisclaimer extends StatelessWidget {
  const RecoveryDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Een schatting uit je eigen logboek: hoe zwaar deze sessie was ten '
      'opzichte van je gewoonte, en hoe je hem beoordeelde. Slaap, eten en '
      'stress wegen zwaarder mee dan de app kan zien.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
