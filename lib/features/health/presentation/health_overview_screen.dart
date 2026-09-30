import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../progress/presentation/recovery_providers.dart';
import '../domain/health_overview.dart';
import 'health_providers.dart';

/// Gezondheid: everything from the watch and everything you filled in about
/// yourself, in one place - the nights with their score, HRV, resting heart
/// rate, the heart rate during your sessions, weight, runs and rides.
///
/// Over the last month. What a watch alone can measure is only shown with
/// Health Connect connected; without it, the screen says how to get it.
class HealthOverviewScreen extends ConsumerWidget {
  const HealthOverviewScreen({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = now ?? DateTime.now();
    final connected = ref.watch(healthConnectEnabledProvider);
    final vitals = ref.watch(vitalsDaysProvider).value ?? const [];
    final sleep = sleepOverview(
      ref.watch(sleepEntriesProvider).value ?? const [],
      vitals,
      now: moment,
    );
    final hrv = readingOverview(vitals, (d) => d.hrvMs, now: moment);
    final resting = readingOverview(vitals, (d) => d.restingHr, now: moment);
    final hearts = ref.watch(workoutHeartRatesProvider).value ?? const [];
    final since = moment.subtract(kHealthWindow);
    final cardio = <CardioSession>[
      for (final session
          in ref.watch(cardioSessionsProvider).value ?? const <CardioSession>[])
        if (!session.start.isBefore(since)) session,
    ].reversed.toList();
    final weight = <ChartPoint>[
      for (final point
          in ref.watch(bodyWeightSeriesProvider).value ?? const <ChartPoint>[])
        if (!point.at.isBefore(since)) point,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gezondheid'),
        actions: [
          IconButton(
            tooltip: 'Health Connect',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.healthConnect),
          ),
        ],
      ),
      body: RefreshIndicator(
        // Pulling down fetches from the watch, like the button does.
        onRefresh: () =>
            ref.read(healthSyncProvider.notifier).sync(force: true),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: connected ? const _Synced() : const _NotConnected(),
            ),
            const SectionHeader('Slaap'),
            _SleepCard(sleep: sleep),
            if (connected || hrv.series.isNotEmpty) ...[
              const SectionHeader('HRV'),
              _ReadingCard(
                reading: hrv,
                unit: 'ms',
                usualLabel: 'gewoonlijk',
                empty: 'Nog geen HRV van je horloge.',
                explanation:
                    'Hoger dan gewoonlijk is meestal goed nieuws; een paar '
                    'ochtenden duidelijk lager rekt je herstelschatting.',
              ),
              const SectionHeader('Rusthartslag'),
              _ReadingCard(
                reading: resting,
                unit: 'bpm',
                usualLabel: 'gewoonlijk',
                empty: 'Nog geen rusthartslag van je horloge.',
                explanation:
                    'Een paar slagen hoger dan gewoonlijk, een paar ochtenden '
                    'na elkaar, is een teken dat je lichaam nog bezig is.',
              ),
            ],
            if (connected || hearts.isNotEmpty) ...[
              const SectionHeader('Hartslag tijdens trainingen'),
              _WorkoutHeartRates(workouts: hearts),
            ],
            const SectionHeader('Gewicht'),
            _WeightCard(points: weight),
            if (connected || cardio.isNotEmpty) ...[
              const SectionHeader('Lopen en fietsen'),
              _CardioCard(sessions: cardio),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                'De laatste 30 dagen. Wat van je horloge komt, haalt FitLog '
                'uit Health Connect; wat je zelf invult, staat er ook bij. '
                'Een aanwijzing over je lichaam, geen medische meting.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle? _muted(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

String _length(Duration d) {
  final minutes = d.inMinutes.remainder(60);
  return minutes == 0 ? '${d.inHours} u' : '${d.inHours} u $minutes';
}

String _number(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

class _Synced extends ConsumerWidget {
  const _Synced();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final synced = ref.watch(settingsProvider).value?.healthConnectSyncedAt;
    final busy = ref.watch(healthSyncProvider).busy;
    final at = synced == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(synced);

    return Row(
      children: [
        const Icon(Icons.watch_outlined, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            at == null
                ? 'Verbonden met Health Connect.'
                : 'Laatst opgehaald ${Formatters.weekdayDayMonth(at)} om '
                      '${Formatters.time(at)}.',
            style: _muted(context),
          ),
        ),
        IconButton(
          tooltip: 'Nu ophalen',
          onPressed: busy
              ? null
              : () => ref.read(healthSyncProvider.notifier).sync(force: true),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
        ),
      ],
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.watch_outlined,
          message:
              'Verbind Health Connect om hier ook je HRV, rusthartslag, je '
              'hartslag tijdens trainingen en je lopen te zien. Wat je zelf '
              'invult, staat er ook zonder.',
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => context.push(Routes.healthConnect),
          child: const Text('Health Connect verbinden'),
        ),
      ],
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.sleep});

  final SleepOverview sleep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = sleep.last;
    // Two weeks of bars stay readable on a phone; the average is the month.
    final shown = sleep.nights.length > 14
        ? sleep.nights.sublist(sleep.nights.length - 14)
        : sleep.nights;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        onTap: () => context.push(Routes.muscleRecovery),
        child: last == null
            ? Text(
                'Nog geen nachten. Vul ze in onder Herstel, of laat ze van je '
                'horloge komen.',
                style: _muted(context),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${last.score}',
                          label:
                              'Slaapscore, '
                              '${Formatters.weekday(last.morning)}',
                          emphasis: true,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: _length(last.length),
                          label: 'Geslapen',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: _length(sleep.average!),
                          label: 'Gemiddeld',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SimpleBarChart(
                    height: 120,
                    color: theme.colorScheme.primary,
                    values: [for (final n in shown) n.length.inMinutes / 60],
                    labels: [for (final n in shown) '${n.morning.day}'],
                    valueLabel: (hours) =>
                        _length(Duration(minutes: (hours * 60).round())),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.reading,
    required this.unit,
    required this.usualLabel,
    required this.empty,
    required this.explanation,
  });

  final ReadingOverview reading;
  final String unit;
  final String usualLabel;
  final String empty;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final latest = reading.latest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: latest == null
            ? Text(empty, style: _muted(context))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${_number(latest)} $unit',
                          label: Formatters.weekdayDayMonth(reading.latestDay!),
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${_number(reading.usual!)} $unit',
                          label:
                              usualLabel[0].toUpperCase() +
                              usualLabel.substring(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TrendLineChart(
                    points: reading.series,
                    height: 140,
                    valueLabel: _number,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(explanation, style: _muted(context)),
                ],
              ),
      ),
    );
  }
}

class _WorkoutHeartRates extends StatelessWidget {
  const _WorkoutHeartRates({required this.workouts});

  final List<WorkoutRow> workouts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: workouts.isEmpty
            ? const EdgeInsets.all(AppSpacing.lg)
            : const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: workouts.isEmpty
            ? Text(
                'Nog geen hartslag bij een training. Draag je horloge tijdens '
                'een training in FitLog; bij het volgende ophalen staat ze '
                'erbij.',
                style: _muted(context),
              )
            : Column(
                children: [
                  for (final workout in workouts)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.favorite_border),
                      title: Text(workout.name),
                      // On the second line, not beside the name: on a
                      // narrow phone the numbers would push the name out.
                      subtitle: Text(
                        '${Formatters.weekdayDayMonth(DateTime.fromMillisecondsSinceEpoch(workout.startedAt))}'
                        '  ·  gem. ${workout.avgHeartRate} · '
                        'max. ${workout.maxHeartRate ?? workout.avgHeartRate} '
                        'bpm',
                      ),
                      onTap: () =>
                          context.push(Routes.workoutDetail(workout.id)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        onTap: () => context.push(Routes.measurements),
        child: points.isEmpty
            ? Text(
                'Geen weging in de laatste 30 dagen.',
                style: _muted(context),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatTile(
                    value: formatters.weight(points.last.value),
                    label: Formatters.weekdayDayMonth(points.last.at),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TrendLineChart(
                    height: 140,
                    points: [
                      for (final p in points)
                        ChartPoint(p.at, formatters.toDisplayWeight(p.value)),
                    ],
                    valueLabel: (v) => v.toStringAsFixed(1),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CardioCard extends StatelessWidget {
  const _CardioCard({required this.sessions});

  final List<CardioSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: sessions.isEmpty
            ? const EdgeInsets.all(AppSpacing.lg)
            : const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: sessions.isEmpty
            ? Text(
                'Geen lopen of ritten in de laatste 30 dagen.',
                style: _muted(context),
              )
            : Column(
                children: [
                  for (final session in sessions)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        session.kind == CardioKind.running
                            ? Icons.directions_run
                            : Icons.directions_bike,
                      ),
                      title: Text(
                        '${session.kind.label[0].toUpperCase()}'
                        '${session.kind.label.substring(1)}',
                      ),
                      subtitle: Text(Formatters.weekdayDayMonth(session.start)),
                      trailing: Text('${session.duration.inMinutes} min'),
                    ),
                ],
              ),
      ),
    );
  }
}
