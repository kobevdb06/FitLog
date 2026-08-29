import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import 'progress_providers.dart';

/// The Voortgang tab: body weight, weekly load, and the way in to everything
/// else that tracks progress.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final buckets = ref.watch(weeklyBucketsProvider()).value ?? const [];
    final weight = ref.watch(bodyWeightSeriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Voortgang')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader('Lichaamsgewicht'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              onTap: () => context.push(Routes.measurements),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weight.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Center(
                        child: Text(
                          'Nog geen metingen',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: formatters.weight(weight.last.value),
                            label: 'Laatste meting',
                          ),
                        ),
                        if (weight.length > 1)
                          Expanded(
                            child: StatTile(
                              value:
                                  '${weight.last.value - weight.first.value > 0 ? '+' : ''}'
                                  '${formatters.weight(weight.last.value - weight.first.value)}',
                              label: 'Sinds de start',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TrendLineChart(
                      points: weight,
                      valueLabel: formatters.weightValue,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SectionHeader('Volume per week'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              child: SimpleBarChart(
                values: [for (final b in buckets) b.volumeKg],
                labels: [
                  for (final b in buckets) Formatters.dayMonth(b.weekStart),
                ],
                valueLabel: formatters.volume,
              ),
            ),
          ),
          const SectionHeader('Workouts per week'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              child: SimpleBarChart(
                values: [for (final b in buckets) b.workouts.toDouble()],
                labels: [
                  for (final b in buckets) Formatters.dayMonth(b.weekStart),
                ],
                height: 130,
                valueLabel: (v) => '${v.round()}',
              ),
            ),
          ),
          const SectionHeader('Meer'),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Grafiek per oefening'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.exerciseChart),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Geschiedenis'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.history),
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Lichaamsmetingen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.measurements),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Voortgangsfoto\'s'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.photos),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Persoonlijke records'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.records),
          ),
        ],
      ),
    );
  }
}
