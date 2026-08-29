import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc/warmup.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';

/// Proposes the four warm-up sets that lead up to a working weight, and can
/// insert them in front of the exercise.
class WarmupSheet extends ConsumerStatefulWidget {
  const WarmupSheet({super.key, required this.workWeightKg});

  /// Returns the sets the user accepted, or null when they backed out.
  static Future<List<({double weightKg, int reps})>?> show(
    BuildContext context, {
    required double workWeightKg,
  }) {
    return showModalBottomSheet<List<({double weightKg, int reps})>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => WarmupSheet(workWeightKg: workWeightKg),
    );
  }

  final double workWeightKg;

  @override
  ConsumerState<WarmupSheet> createState() => _WarmupSheetState();
}

class _WarmupSheetState extends ConsumerState<WarmupSheet> {
  late double _workWeightKg = widget.workWeightKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final setup = ref.watch(barbellSetupProvider);

    final sets = calculateWarmupSets(
      workWeightKg: _workWeightKg,
      barKg: setup.barKg,
      availablePlatesKg: setup.platesKg,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Warming-up', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Opbouw naar je werkgewicht, afgerond op wat je echt kunt laden.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: () async {
              final result = await showKeypadSheet(
                context: context,
                kind: KeypadFieldKind.weight,
                initialValue: KeypadValue.fromNumber(
                  formatters.toDisplayWeight(_workWeightKg),
                ),
                unitLabel: formatters.weightUnitLabel,
                title: 'Werkgewicht',
              );
              final value = result?.number;
              if (value == null) return;
              setState(
                () => _workWeightKg = formatters.fromDisplayWeight(value),
              );
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Werkgewicht'),
              child: Text(
                formatters.weight(_workWeightKg),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (sets.isEmpty)
            const InfoBanner(
              message: 'Vul eerst een werkgewicht in.',
            )
          else
            for (final set in sets)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(set.percentage * 100).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${formatters.weight(set.weightKg)} × ${set.reps}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: sets.isEmpty
                ? null
                : () => Navigator.of(context).pop([
                    for (final s in sets)
                      (weightKg: s.weightKg, reps: s.reps),
                  ]),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Toevoegen als warming-up sets'),
          ),
        ],
      ),
    );
  }
}
