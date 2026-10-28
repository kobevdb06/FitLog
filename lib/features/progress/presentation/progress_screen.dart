import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/plateau.dart';
import '../../../core/calc/progress_period.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/muscle_bars.dart';
import '../../../routing/routes.dart';
import '../../history/presentation/history_providers.dart';
import '../../photos/presentation/photo_providers.dart';
import 'plateau_card.dart';
import 'progress_providers.dart';
import 'recovery_providers.dart';

/// The Voortgang tab: what has stalled, then over the period you choose
/// whether your main exercises went up and what you did, and the way in to
/// everything else that tracks progress - your weight among it.
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
          _More(period: period),
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
            ButtonSegment(
              value: value,
              // On one line, a little smaller where it has to be: on a
              // narrow phone with a large font "3 maanden" broke in two.
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value.label, maxLines: 1, softWrap: false),
              ),
            ),
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
        // What the kilos are, once for all of them. Repetitions and a time
        // say what they are by their unit.
        SectionHeader(
          'Hoofdoefeningen',
          action: lifts.any((l) => l.trend.measure == ProgressMeasure.oneRm)
              ? Text(
                  'geschatte 1RM',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
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
                    style: theme.textTheme.bodySmall?.copyWith(
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

/// One exercise: where it stands, how far it came, and the line between -
/// in two lines, the line beside how far it came.
class _LiftRow extends ConsumerWidget {
  const _LiftRow({required this.lift});

  final MainLift lift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final trend = lift.trend;
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
    final latest = _shown(formatters, trend.measure, trend.latest);
    // Between the two ends as they are shown, so the change is what the
    // numbers on screen add up to.
    final shownChange = switch (trend.earliest) {
      final from? => latest - _shown(formatters, trend.measure, from),
      null => null,
    };
    // Without two ends to compare, how often it was done.
    final moved = shownChange == null
        ? sessions
        : '${_difference(formatters, trend.measure, shownChange)} sinds '
              '${Formatters.dayMonth(trend.since)}';
    final up = shownChange != null && shownChange > 0;
    final value = _value(formatters, trend.measure, latest);

    return InkWell(
      onTap: () => context.push(Routes.exerciseCharts(lift.exercise.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only the value beside the name: the change has a date in
              // it, and next to a long name on a narrow phone with a large
              // font it ran off the card.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      lift.exercise.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    value,
                    // The header says it once for the eye; a screen reader
                    // hears it with every number.
                    semanticsLabel: '$what $value',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      moved,
                      style: muted?.copyWith(
                        color: up ? AppColors.success : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 96,
                      child: Sparkline(
                        values: [for (final p in trend.points) p.value],
                        height: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [value] as it is shown, in the unit it is shown in: an estimate to the
  /// whole kilo or pound, repetitions and seconds whole.
  static int _shown(
    Formatters formatters,
    ProgressMeasure measure,
    double value,
  ) => switch (measure) {
    ProgressMeasure.oneRm => formatters.estimateValue(value),
    _ => value.round(),
  };

  /// A number from [_shown], with its unit.
  static String _value(
    Formatters formatters,
    ProgressMeasure measure,
    int shown,
  ) => switch (measure) {
    ProgressMeasure.oneRm =>
      '${formatters.count(shown)} ${formatters.weightUnitLabel}',
    ProgressMeasure.reps => '$shown reps',
    ProgressMeasure.hold => Formatters.minutesSeconds(shown),
  };

  static String _difference(
    Formatters formatters,
    ProgressMeasure measure,
    int change,
  ) {
    if (change == 0) return 'Gelijk';
    final sign = change > 0 ? '+' : '-';
    return '$sign${_value(formatters, measure, change.abs())}';
  }
}

/// What you did over the period: the totals, then the bars of the one you
/// choose.
///
/// One chart with a choice rather than a chart for each: two charts of the
/// same weeks were most of a screen, and the second was read less.
class _Training extends ConsumerWidget {
  const _Training({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final measure = ref.watch(trainingMeasureChoiceProvider);
    final buckets = ref.watch(trainingBucketsProvider(period)).value;
    if (buckets == null) return const SizedBox.shrink();

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

    var workouts = 0;
    var sets = 0;
    var volume = 0.0;
    for (final b in buckets) {
      workouts += b.workouts;
      sets += b.sets;
      volume += b.volumeKg;
    }

    final (values, valueLabel) = switch (measure) {
      TrainingMeasure.volume => (
        [for (final b in buckets) b.volumeKg],
        formatters.volume,
      ),
      TrainingMeasure.workouts => (
        [for (final b in buckets) b.workouts.toDouble()],
        (double v) => '${v.round()}',
      ),
      TrainingMeasure.sets => (
        [for (final b in buckets) b.sets.toDouble()],
        (double v) => formatters.count(v.round()),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Training'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // Without a workout in the period, one line instead of a row of
          // noughts over a chart with no bars: that was most of a screen
          // of nothing.
          child: AppCard(
            child: workouts == 0
                ? Text(
                    'Nog geen workouts in deze periode.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The number of the chart below in colour, so the
                      // two read as one.
                      StatRow(
                        children: [
                          StatTile(
                            value: formatters.count(workouts),
                            label: 'Workouts',
                            emphasis: measure == TrainingMeasure.workouts,
                          ),
                          StatTile(
                            value: formatters.count(sets),
                            label: 'Sets',
                            emphasis: measure == TrainingMeasure.sets,
                          ),
                          StatTile(
                            value: formatters.volume(volume),
                            label: 'Volume',
                            emphasis: measure == TrainingMeasure.volume,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final option in TrainingMeasure.values)
                            ChoiceChip(
                              label: Text(option.label),
                              selected: measure == option,
                              onSelected: (_) => ref
                                  .read(trainingMeasureChoiceProvider.notifier)
                                  .choose(option),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SimpleBarChart(
                        values: values,
                        labels: labels,
                        labelEvery: labelEvery,
                        valueLabel: valueLabel,
                        lastUnfinished: true,
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
        SectionHeader(
          'Sets per spiergroep',
          action: IconButton(
            tooltip: 'Over sets per spiergroep',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () => showAppSheet<void>(
              context: context,
              title: 'Sets per spiergroep',
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Je werksets per week in deze periode, bij de spiergroep '
                  'die de oefening vooral traint. Opwarmsets tellen niet '
                  'mee, en een deloadweek ook niet. Het streepje is wat je '
                  'per week deed in een even lange periode ervoor; wat daar '
                  'duidelijk onder zakte, minder dan zeven tiende ervan, '
                  'staat in het oranje.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
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
                      // What the numbers are; how to read the marks is
                      // behind the i, for whoever wants it once.
                      Text('Werksets per week', style: muted),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// The way in to everything else that tracks progress, each saying in
/// passing how it stands, the way Herstel always did.
///
/// What you did comes first - every workout, then this week - then what is
/// about your body. A list on the page rather than in a card: these are ways
/// in, and a card made them look like something to read. Your records are
/// on Profiel, with the rest of what is about you.
class _More extends ConsumerWidget {
  const _More({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(finishedWorkoutDatesProvider).value;
    final week = ref.watch(thisWeekStatsProvider).value;
    final photos = ref.watch(progressPhotosProvider).value;
    String last(DateTime at) =>
        'laatste ${Formatters.relativeDay(at).toLowerCase()}';

    // Until the numbers are in, an empty line rather than none: the rows
    // keep their height instead of jumping when they arrive.
    final history = switch (dates) {
      null => '',
      [] => 'Nog geen workouts',
      [..., final newest] =>
        '${Formatters.amount(dates.length, 'workout', 'workouts')} · '
            '${last(newest)}',
    };
    final thisWeek = switch (week?.workouts) {
      null => '',
      0 => 'Deze week nog geen workout',
      final count =>
        'Deze week ${Formatters.amount(count, 'workout', 'workouts')}',
    };
    final pictures = switch (photos) {
      null => '',
      [] => "Nog geen foto's",
      [final newest, ...] =>
        "${Formatters.amount(photos.length, 'foto', "foto's")} · "
            '${last(DateTime.fromMillisecondsSinceEpoch(newest.takenAt))}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Meer'),
        _MoreTile(
          icon: Icons.history,
          title: 'Geschiedenis',
          subtitle: history,
          onTap: () => context.push(Routes.history),
        ),
        _MoreTile(
          icon: Icons.calendar_view_week_outlined,
          title: 'Weekoverzicht',
          subtitle: thisWeek,
          onTap: () => context.push(Routes.weekReview),
        ),
        const _RecoveryTile(),
        _MoreTile(
          icon: Icons.favorite_border,
          title: 'Gezondheid',
          subtitle: 'Slaap, HRV, hartslag en lopen',
          onTap: () => context.push(Routes.health),
        ),
        _WeightTile(period: period),
        _MoreTile(
          icon: Icons.photo_library_outlined,
          title: "Voortgangsfoto's",
          subtitle: pictures,
          onTap: () => context.push(Routes.photos),
        ),
      ],
    );
  }
}

/// One way in under Meer: an icon on a tint, what it is, and how it stands.
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colours.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, size: 22, color: colours.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// The way into Herstel, saying in passing how things stand.
class _RecoveryTile extends ConsumerWidget {
  const _RecoveryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(recoveryEstimatesProvider).value ?? const [];
    final now = DateTime.now();
    final recovering = estimates.where((e) => !e.isReadyAt(now)).length;

    return _MoreTile(
      icon: Icons.healing_outlined,
      title: 'Herstel',
      subtitle: recovering == 0
          ? 'Alles hersteld'
          : recovering == 1
          ? '1 spiergroep herstelt nog'
          : '$recovering spiergroepen herstellen nog',
      onTap: () => context.push(Routes.muscleRecovery),
    );
  }
}

/// The way into Lichaamsmetingen, with your latest weight and how far it
/// moved over the period - where a chart of it used to stand. The chart is
/// on Lichaamsmetingen, with the rest of your measurements.
class _WeightTile extends ConsumerWidget {
  const _WeightTile({required this.period});

  final ProgressPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final all = ref.watch(bodyWeightSeriesProvider).value;
    final from = period.start(DateTime.now());

    String line(List<ChartPoint> all) {
      final latest = all.last;
      final inPeriod = [
        for (final point in all)
          if (!point.at.isBefore(from)) point,
      ];
      // With one weighing in the period there is nothing to compare; when it
      // was says how much the number still means.
      if (inPeriod.length < 2) {
        return '${formatters.weight(latest.value)} · '
            '${Formatters.relativeDay(latest.at).toLowerCase()}';
      }
      final moved = formatters.toDisplayWeight(
        inPeriod.last.value - inPeriod.first.value,
      );
      final since = Formatters.dayMonth(inPeriod.first.at);
      final change = moved == 0
          ? 'gelijk'
          : '${moved > 0 ? '+' : '-'}'
                '${formatters.weight(formatters.fromDisplayWeight(moved.abs()))}';
      return '${formatters.weight(latest.value)} · $change sinds $since';
    }

    return _MoreTile(
      icon: Icons.monitor_weight_outlined,
      title: 'Gewicht en maten',
      subtitle: switch (all) {
        null => '',
        [] => 'Nog niets gemeten',
        _ => line(all),
      },
      onTap: () => context.push(Routes.measurements),
    );
  }
}
