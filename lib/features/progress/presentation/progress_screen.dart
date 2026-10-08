import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/plateau.dart';
import '../../../core/calc/progress_period.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/muscle_bars.dart';
import '../../../routing/routes.dart';
import 'plateau_card.dart';
import 'progress_providers.dart';
import 'recovery_providers.dart';

/// The Voortgang tab: what has stalled, then over the period you choose
/// whether your main exercises went up and what you did, your body weight,
/// and the way in to everything else that tracks progress.
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
          _MainLifts(period: period),
          _Training(period: period),
          _MuscleSets(period: period),
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

/// Whether the exercises you do most went up over the period.
///
/// First after the choice, because it is the question the tab is for: the
/// rest says how much you did, this says what came of it.
class _MainLifts extends ConsumerWidget {
  const _MainLifts({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lifts = ref.watch(mainLiftsProvider(period)).value;
    // Nothing until the first answer, rather than the empty text flashing
    // by on every change of period.
    if (lifts == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Hoofdoefeningen'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            padding: lifts.isEmpty
                ? const EdgeInsets.all(AppSpacing.lg)
                : const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: lifts.isEmpty
                ? Text(
                    'Doe een oefening twee keer in deze periode, en hier '
                    'staat of ze vooruitgaat.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [for (final lift in lifts) _LiftRow(lift: lift)],
                  ),
          ),
        ),
      ],
    );
  }
}

/// One exercise: where it stands, how far it came, and the line between.
class _LiftRow extends ConsumerWidget {
  const _LiftRow({required this.lift});

  final MainLift lift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final trend = lift.trend;
    final change = trend.change;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final what = switch (trend.measure) {
      ProgressMeasure.oneRm => 'Geschatte 1RM',
      ProgressMeasure.reps => 'Meeste herhalingen',
      ProgressMeasure.hold => 'Langste tijd',
    };
    final sessions = Formatters.amount(
      trend.points.length,
      'sessie',
      'sessies',
    );
    final moved = change == null
        ? null
        : '${_difference(formatters, trend.measure, change)} sinds '
              '${Formatters.dayMonth(trend.since)}';
    final up = change != null && _shown(formatters, trend.measure, change) > 0;

    return InkWell(
      onTap: () => context.push(Routes.exerciseCharts(lift.exercise.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lift.exercise.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('$what · $sessions', style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _value(formatters, trend.measure, trend.latest),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (moved != null)
                        Text(
                          moved,
                          style: muted?.copyWith(
                            color: up ? AppColors.success : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ExcludeSemantics(
              child: Sparkline(values: [for (final p in trend.points) p.value]),
            ),
          ],
        ),
      ),
    );
  }

  static String _value(
    Formatters formatters,
    ProgressMeasure measure,
    double value,
  ) => switch (measure) {
    ProgressMeasure.oneRm => formatters.weight(value),
    ProgressMeasure.reps => '${value.round()} reps',
    ProgressMeasure.hold => Formatters.minutesSeconds(value.round()),
  };

  /// The change as it will be shown: rounded the way the value is, so a
  /// tenth of a kilo does not count as going up.
  static double _shown(
    Formatters formatters,
    ProgressMeasure measure,
    double change,
  ) => switch (measure) {
    ProgressMeasure.oneRm =>
      formatters.toDisplayWeight(change.abs()) * change.sign,
    _ => change.roundToDouble(),
  };

  static String _difference(
    Formatters formatters,
    ProgressMeasure measure,
    double change,
  ) {
    final shown = _shown(formatters, measure, change);
    if (shown == 0) return 'Gelijk';
    final sign = shown > 0 ? '+' : '-';
    return '$sign${_value(formatters, measure, change.abs())}';
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

/// Where the sets of the period went, and which muscle has fallen behind
/// the stretch before it.
class _MuscleSets extends ConsumerWidget {
  const _MuscleSets({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final muscles = ref.watch(muscleSetsProvider(period)).value;
    if (muscles == null) return const SizedBox.shrink();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // To the half set: a tenth of a set a week says nothing.
    String perWeek(double sets) => formatters.decimal((sets * 2).round() / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Sets per spiergroep'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            child: muscles.isEmpty
                ? Text('Nog geen sets in deze periode.', style: muted)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MuscleBars(
                        bars: [
                          for (final m in muscles)
                            MuscleBar(
                              muscle: m.muscle,
                              value: m.perWeek,
                              usual: m.usualPerWeek,
                              label: perWeek(m.perWeek),
                              lagging: m.lagging,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Werksets per week. Het streepje is de periode ervoor; '
                        'wat daar duidelijk onder zakte, staat in het oranje.',
                        style: muted,
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
