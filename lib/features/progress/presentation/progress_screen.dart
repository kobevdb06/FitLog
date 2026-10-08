import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/progress_period.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import 'plateau_card.dart';
import 'progress_providers.dart';
import 'recovery_providers.dart';

/// The Voortgang tab: what has stalled, what you did over the period you
/// choose, your body weight, and the way in to everything else that tracks
/// progress.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(progressPeriodChoiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voortgang')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // First, because it is the one thing here to act on - and only
          // there while something has stalled. Above the period, because it
          // does not follow it: stalling is measured over weeks of its own.
          const PlateauSection(),
          const _PeriodPicker(),
          _Training(period: period),
          _BodyWeight(period: period),
          // Your records and measurements are on Profiel, with the rest of
          // what is about you; one place for each.
          const SectionHeader('Meer'),
          const _RecoveryTile(),
          ListTile(
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: const Text('Weekoverzicht'),
            subtitle: const Text('Je week op een rij'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.weekReview),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Gezondheid'),
            subtitle: const Text('Slaap, HRV, hartslag, gewicht en lopen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.health),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Geschiedenis'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.history),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text("Voortgangsfoto's"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.photos),
          ),
        ],
      ),
    );
  }
}

/// The one choice every chart below it follows.
class _PeriodPicker extends ConsumerWidget {
  const _PeriodPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(progressPeriodChoiceProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: SegmentedButton<ProgressPeriod>(
        expandedInsets: EdgeInsets.zero,
        showSelectedIcon: false,
        segments: [
          for (final value in ProgressPeriod.values)
            ButtonSegment(value: value, label: Text(value.label)),
        ],
        selected: {period},
        onSelectionChanged: (chosen) => ref
            .read(progressPeriodChoiceProvider.notifier)
            .choose(chosen.first),
      ),
    );
  }
}

/// What you did over the period: the totals, then the bars they add up from.
class _Training extends ConsumerWidget {
  const _Training({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final buckets =
        ref.watch(trainingBucketsProvider(period)).value ?? const [];

    final per = period.byMonth ? 'maand' : 'week';
    final labels = [
      for (final b in buckets)
        period.byMonth
            ? Formatters.month(b.start)
            : Formatters.dayMonth(b.start),
    ];
    // As many dates as fit under the bars on a phone with a large font.
    final labelEvery = switch (period) {
      ProgressPeriod.fourWeeks => 1,
      ProgressPeriod.threeMonths => 3,
      ProgressPeriod.year => 2,
    };
    final caption = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    var workouts = 0;
    var sets = 0;
    var volume = 0.0;
    for (final b in buckets) {
      workouts += b.workouts;
      sets += b.sets;
      volume += b.volumeKg;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Training'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(
                  children: [
                    StatTile(
                      value: formatters.count(workouts),
                      label: 'Workouts',
                    ),
                    StatTile(value: formatters.count(sets), label: 'Sets'),
                    StatTile(value: formatters.volume(volume), label: 'Volume'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Volume per $per', style: caption),
                const SizedBox(height: AppSpacing.sm),
                SimpleBarChart(
                  values: [for (final b in buckets) b.volumeKg],
                  labels: labels,
                  labelEvery: labelEvery,
                  valueLabel: formatters.volume,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Workouts per $per', style: caption),
                const SizedBox(height: AppSpacing.sm),
                SimpleBarChart(
                  values: [for (final b in buckets) b.workouts.toDouble()],
                  labels: labels,
                  labelEvery: labelEvery,
                  height: 110,
                  valueLabel: (v) => '${v.round()}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Your weight over the period, and the latest whenever it was.
class _BodyWeight extends ConsumerWidget {
  const _BodyWeight({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final all = ref.watch(bodyWeightSeriesProvider).value ?? const [];
    final from = period.start(DateTime.now());
    final inPeriod = [
      for (final point in all)
        if (!point.at.isBefore(from)) point,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Lichaamsgewicht'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            onTap: () => context.push(Routes.measurements),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        'Nog geen metingen',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: formatters.weight(all.last.value),
                          label: 'Laatste meting',
                        ),
                      ),
                      if (inPeriod.length > 1)
                        Expanded(
                          child: StatTile(
                            value: _change(
                              formatters,
                              inPeriod.last.value - inPeriod.first.value,
                            ),
                            label:
                                'Sinds ${Formatters.dayMonth(inPeriod.first.at)}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TrendLineChart(
                    points: inPeriod,
                    valueLabel: formatters.weightValue,
                    emptyMessage: 'Geen metingen in deze periode',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _change(Formatters formatters, double kg) =>
      '${kg > 0 ? '+' : ''}${formatters.weight(kg)}';
}

/// The way into Herstel, saying in passing how things stand.
class _RecoveryTile extends ConsumerWidget {
  const _RecoveryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(recoveryEstimatesProvider).value ?? const [];
    final now = DateTime.now();
    final recovering = estimates.where((e) => !e.isReadyAt(now)).length;

    return ListTile(
      leading: const Icon(Icons.healing_outlined),
      title: const Text('Herstel'),
      subtitle: Text(
        recovering == 0
            ? 'Alles hersteld'
            : recovering == 1
            ? '1 spiergroep herstelt nog'
            : '$recovering spiergroepen herstellen nog',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.muscleRecovery),
    );
  }
}
