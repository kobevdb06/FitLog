import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import 'recovery_providers.dart';

/// Today and yesterday, in standard drinks.
///
/// Two days and no more: what counts for the estimate is drinking on the day
/// you trained, and the day you are most likely to fill in afterwards is the
/// next morning.
class AlcoholSection extends ConsumerWidget {
  const AlcoholSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(drinkDaysProvider).value ?? const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    int drinksOn(DateTime day) {
      for (final row in rows) {
        final at = DateTime.fromMillisecondsSinceEpoch(row.day);
        if (at.year == day.year && at.month == day.month && at.day == day.day) {
          return row.drinks;
        }
      }
      return 0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In standaardglazen: een pint, een glas wijn of een borrel is er '
              'een, een zwaar speciaalbier bijna twee. Pas vanaf een paar '
              'glazen op de dag dat je trainde telt het mee.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (label, day) in [
              ('Vandaag', today),
              ('Gisteren', yesterday),
            ])
              _DrinkRow(
                label: label,
                drinks: drinksOn(day),
                onChanged: (value) =>
                    ref.read(recoveryActionsProvider).drank(day, value),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrinkRow extends StatelessWidget {
  const _DrinkRow({
    required this.label,
    required this.drinks,
    required this.onChanged,
  });

  final String label;
  final int drinks;
  final ValueChanged<int> onChanged;

  /// More than this in a day is not a number anyone logs honestly with a
  /// plus button.
  static const int most = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        IconButton(
          tooltip: 'Een glas minder',
          onPressed: drinks > 0 ? () => onChanged(drinks - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 72,
          child: Text(
            drinks == 1 ? '1 glas' : '$drinks glazen',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        IconButton(
          tooltip: 'Een glas meer',
          onPressed: drinks < most ? () => onChanged(drinks + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
