import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc/plates.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';

/// "What do I put on the bar?" - shown from a set row or the exercise menu.
class PlateCalculatorSheet extends ConsumerStatefulWidget {
  const PlateCalculatorSheet({super.key, this.initialTargetKg});

  static Future<void> show(BuildContext context, {double? targetKg}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PlateCalculatorSheet(initialTargetKg: targetKg),
    );
  }

  final double? initialTargetKg;

  @override
  ConsumerState<PlateCalculatorSheet> createState() =>
      _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends ConsumerState<PlateCalculatorSheet> {
  late double _targetKg = widget.initialTargetKg ?? 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final setup = ref.watch(barbellSetupProvider);

    final solution = calculatePlates(
      targetKg: _targetKg,
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
          Text('Schijvenberekening', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Doelgewicht',
                  value: formatters.weight(_targetKg),
                  onTap: () async {
                    final result = await showKeypadSheet(
                      context: context,
                      kind: KeypadFieldKind.weight,
                      initialValue: KeypadValue.fromNumber(
                        formatters.toDisplayWeight(_targetKg),
                      ),
                      unitLabel: formatters.weightUnitLabel,
                      title: 'Doelgewicht',
                    );
                    final value = result?.number;
                    if (value == null) return;
                    setState(
                      () => _targetKg = formatters.fromDisplayWeight(value),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Field(
                  label: 'Stang',
                  value: formatters.weight(setup.barKg),
                  onTap: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (solution.isBelowBar)
            const InfoBanner(
              icon: Icons.info_outline,
              message:
                  'Het doelgewicht ligt onder het gewicht van de lege stang.',
            )
          else ...[
            _BarView(solution: solution, formatters: formatters),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Per zijde', style: theme.textTheme.labelLarge),
                Text(
                  formatters.weight(solution.plateWeightPerSideKg),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Totaal op de stang', style: theme.textTheme.titleSmall),
                Text(
                  formatters.weight(solution.achievedKg),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            if (!solution.isExact) ...[
              const SizedBox(height: AppSpacing.md),
              InfoBanner(
                icon: Icons.report_problem_outlined,
                color: AppColors.record,
                message:
                    'Met deze schijven kom je niet exact uit: '
                    '${solution.differenceKg > 0 ? '+' : ''}'
                    '${formatters.weight(solution.differenceKg)} verschil.',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

/// A simple side view of the loaded bar: the sleeve with the plates stacked
/// from heaviest to lightest, drawn to relative size.
class _BarView extends StatelessWidget {
  const _BarView({required this.solution, required this.formatters});

  final PlateSolution solution;
  final Formatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (solution.perSide.isEmpty) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          'Lege stang',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final heaviest = solution.perSide.first.weightKg;

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final stack in solution.perSide)
                  for (var i = 0; i < stack.count; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: (28 + 62 * (stack.weightKg / heaviest))
                              .clamp(28, 90),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              formatters.weightValue(stack.weightKg),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
