import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// "Deload", on a session that was one: in the workout, the history and the
/// island. "Lichter" on one made lighter on its own.
class DeloadTag extends StatelessWidget {
  const DeloadTag({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.record.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          light ? 'Lichter' : 'Deload',
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.record),
        ),
      ),
    );
  }
}

/// Under an exercise in a deload session: what the set is now, that it may
/// feel light, and what the last ordinary time was. "Lichter" in a session
/// made lighter on its own, which is no deload.
class DeloadLine extends StatelessWidget {
  const DeloadLine({super.key, this.now, this.before, this.light = false});

  final bool light;

  /// `72,5 kg × 8`, or null for a set with nothing in it.
  final String? now;

  /// The last ordinary time, or null without one.
  final String? before;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.record.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              now == null
                  ? '${light ? 'Lichter' : 'Deload'}: het mag licht voelen.'
                  : '${light ? 'Lichter' : 'Deload'}: $now, het mag licht '
                        'voelen.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (before != null)
              Text(
                'Vorige gewone keer: $before',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
