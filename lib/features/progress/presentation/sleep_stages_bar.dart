import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// `1 u 22`, or `48 min` under an hour.
String stageLength(int minutes) {
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} u' : '${minutes ~/ 60} u $rest';
}

/// The stages of one night as a bar, each as wide as it lasted, with what
/// each colour is and how long it was underneath.
///
/// What the stages leave over of the night - lying awake, or minutes the
/// watch did not place - is shown as such when it is more than a little:
/// otherwise a night of three stages that add up to six of its eight hours
/// would look like a full night of sleep.
class SleepStagesBar extends StatelessWidget {
  const SleepStagesBar({
    super.key,
    required this.length,
    this.light,
    this.rem,
    this.deep,
  });

  final Duration length;
  final int? light;
  final int? rem;
  final int? deep;

  /// Whether there is anything to draw.
  static bool hasStages({int? light, int? rem, int? deep}) =>
      (light ?? 0) + (rem ?? 0) + (deep ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = length.inMinutes;
    final staged = (light ?? 0) + (rem ?? 0) + (deep ?? 0);
    final rest = total - staged;

    final parts = <(String, int, Color)>[
      if ((deep ?? 0) > 0) ('Diep', deep!, scheme.primary),
      if ((rem ?? 0) > 0) ('REM', rem!, scheme.tertiary),
      if ((light ?? 0) > 0)
        ('Licht', light!, scheme.primary.withValues(alpha: 0.45)),
      // More than a quarter of an hour unplaced is worth showing.
      if (rest > 15) ('Wakker of niet ingedeeld', rest, scheme.outlineVariant),
    ];
    final whole = parts.fold<int>(0, (sum, p) => sum + p.$2);
    if (whole == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (final (_, minutes, colour) in parts)
                  Expanded(
                    flex: minutes,
                    child: ColoredBox(color: colour),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (label, minutes, colour) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$label ${stageLength(minutes)} · '
                    '${(minutes * 100 / whole).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
