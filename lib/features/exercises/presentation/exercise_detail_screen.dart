import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/exercise_image.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/pr_attempt_screen.dart';
import 'custom_exercise_screen.dart';
import 'exercise_providers.dart';

/// Info, history, charts and records for one exercise.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  /// Changes how this exercise is done, and with it what a set asks for.
  ///
  /// Works on catalogue exercises too. The bundled types are not always right -
  /// the plank came typed as a body-weight exercise, counted in repetitions -
  /// and being able to put that right in ten seconds beats waiting for a new
  /// version of the app.
  Future<void> _changeCategory(
    BuildContext context,
    WidgetRef ref,
    ExerciseRow row,
  ) async {
    final current = ExerciseCategory.fromWire(row.category);
    final picked = await pickExerciseCategory(context, current: current);
    if (picked == null || picked == current) return;

    await ref.read(databaseProvider).exercisesDao.setCategory(row.id, picked);
    if (!context.mounted) return;
    showSnack(
      context,
      '${row.name} wordt nu gelogd in '
      '${exerciseCategoryDescription(picked).toLowerCase()}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));

    return exercise.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (row) {
        if (row == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.help_outline,
              title: 'Oefening niet gevonden',
              message: 'Deze oefening bestaat niet meer.',
            ),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                final started = await PrAttemptScreen.open(
                  context,
                  exercise: row,
                );
                if (started && context.mounted) {
                  context.push(Routes.workout);
                }
              },
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('PR-poging'),
            ),
            appBar: AppBar(
              title: Text(row.name),
              actions: [
                if (row.isCustom)
                  IconButton(
                    tooltip: 'Bewerken',
                    onPressed: () => CustomExerciseScreen.open(
                      context,
                      exerciseId: exerciseId,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'category') _changeCategory(context, ref, row);
                  },
                  itemBuilder: (context) => [
                    menuItem(
                      value: 'category',
                      icon: Icons.tune,
                      label: 'Type wijzigen',
                    ),
                  ],
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Info'),
                  Tab(text: 'Geschiedenis'),
                  Tab(text: 'Grafieken'),
                  Tab(text: 'Records'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _InfoTab(exercise: row),
                _HistoryTab(exerciseId: exerciseId),
                _ChartsTab(
                  exerciseId: exerciseId,
                  category: ExerciseCategory.fromWire(row.category),
                ),
                _RecordsTab(exerciseId: exerciseId),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.exercise});

  final ExerciseRow exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final category = ExerciseCategory.fromWire(exercise.category);
    final secondary = decodeSecondaryMuscles(exercise.secondaryMuscles);
    final images = ref.watch(exerciseImagesProvider).value;
    final paths = ref.watch(appPathsProvider).value;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ExerciseAnimation(exercise: exercise, manifest: images, paths: paths),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            ExerciseThumb(
              exercise: exercise,
              manifest: images,
              paths: paths,
              size: 56,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${category.label}'
                    '${exercise.equipment == null ? '' : ' · ${exercise.equipment}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SectionHeader(
          'Spiergroepen',
          padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Chip(
              avatar: CircleAvatar(
                backgroundColor: AppColors.forMuscle(exercise.primaryMuscle),
                radius: 6,
              ),
              label: Text('${exercise.primaryMuscle} (primair)'),
            ),
            for (final muscle in secondary)
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: AppColors.forMuscle(muscle),
                  radius: 6,
                ),
                label: Text(muscle),
              ),
          ],
        ),
        if (exercise.instructions != null &&
            exercise.instructions!.trim().isNotEmpty) ...[
          const SectionHeader(
            'Uitvoering',
            padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
          ),
          Text(exercise.instructions!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(exerciseSessionsProvider(exerciseId));
    final formatters = ref.watch(formattersProvider);

    return sessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'Nog niet gedaan',
            message: 'Zodra je deze oefening logt, zie je hier elke sessie.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final session = list[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.date(session.date),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (session.workoutExercise.notes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          session.workoutExercise.notes!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < session.sets.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                SetType.fromWire(session.sets[i].setType)
                                        .marker ??
                                    '${i + 1}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                            Text(
                              formatters.setSummary(
                                weightKg: session.sets[i].weightKg,
                                reps: session.sets[i].reps,
                                durationSeconds:
                                    session.sets[i].durationSeconds,
                                distanceM: session.sets[i].distanceM,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChartsTab extends ConsumerStatefulWidget {
  const _ChartsTab({required this.exerciseId, required this.category});

  final String exerciseId;
  final ExerciseCategory category;

  @override
  ConsumerState<_ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends ConsumerState<_ChartsTab> {
  ExerciseMetric _metric = ExerciseMetric.oneRm;
  ChartRange _range = ChartRange.quarter;

  @override
  Widget build(BuildContext context) {
    final sessions = ref
        .watch(exerciseSessionsProvider(widget.exerciseId))
        .value;
    final formatters = ref.watch(formattersProvider);

    if (sessions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Nog geen grafiek',
        message: 'Log deze oefening een paar keer om je lijn te zien.',
      );
    }

    // Which lines make sense here follows the exercise: a plank has no
    // one-rep max, a run has no volume in kilograms. If the exercise has since
    // been re-typed the chosen metric may no longer be on offer, so fall back
    // to the first rather than draw an empty chart.
    final metrics = ExerciseMetric.forSessions(widget.category, sessions);
    final metric = metrics.contains(_metric) ? _metric : metrics.first;

    final points = buildExerciseSeries(
      sessions: sessions,
      metric: metric,
      range: _range,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final option in metrics) ...[
                ChoiceChip(
                  label: Text(option.label),
                  selected: metric == option,
                  onSelected: (_) => setState(() => _metric = option),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ChartRange>(
          segments: [
            for (final range in ChartRange.values)
              ButtonSegment(value: range, label: Text(range.label)),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        TrendLineChart(
          points: points,
          height: 240,
          valueLabel: (value) =>
              formatExerciseMetric(metric, value, formatters),
        ),
        if (points.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: _format(metric, points.last.value, formatters),
                  label: 'Laatste',
                ),
              ),
              Expanded(
                child: StatTile(
                  value: _format(
                    metric,
                    points.map((p) => p.value).reduce((a, b) => a > b ? a : b),
                    formatters,
                  ),
                  label: 'Beste',
                  emphasis: true,
                ),
              ),
              Expanded(
                child: StatTile(value: '${points.length}', label: 'Sessies'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _format(ExerciseMetric metric, double value, Formatters formatters) =>
      formatExerciseMetric(metric, value, formatters, withUnit: true);
}

class _RecordsTab extends ConsumerWidget {
  const _RecordsTab({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(exerciseRecordsProvider(exerciseId));
    final formatters = ref.watch(formattersProvider);

    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Nog geen records',
            message:
                'Je eerste afgevinkte set van deze oefening levert meteen '
                'records op.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final record in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.record,
                ),
                title: Text(PrType.fromWire(record.recordType).label),
                subtitle: Text(
                  Formatters.date(
                    DateTime.fromMillisecondsSinceEpoch(record.achievedAt),
                  ),
                ),
                trailing: Text(
                  _value(record, formatters),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
          ],
        );
      },
    );
  }

  String _value(PersonalRecordRow record, Formatters formatters) {
    switch (PrType.fromWire(record.recordType)) {
      case PrType.maxReps:
        return '${record.value.round()}';
      case PrType.maxSetVolume:
        return formatters.volume(record.value);
      case PrType.maxWeight:
      case PrType.est1rm:
        return formatters.weight(record.value);
      case PrType.maxDuration:
        return Formatters.duration(record.value.round());
      case PrType.maxDistance:
        return formatters.distance(record.value);
    }
  }
}
