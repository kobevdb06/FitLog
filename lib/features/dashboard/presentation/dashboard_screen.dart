import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/streak.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../progress/presentation/recovery_providers.dart';
import '../../progress/presentation/recovery_view.dart';
import '../../../routing/routes.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../routines/presentation/routine_providers.dart';
import '../../workout/presentation/workout_providers.dart';

/// The Start tab: where you are, what is next, and one big button.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final streak = ref.watch(streakProvider).value;
    final week = ref.watch(thisWeekStatsProvider).value;
    final buckets = ref.watch(weeklyBucketsProvider()).value ?? const [];
    final records = ref.watch(latestRecordsProvider()).value ?? const [];
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: _Greeting(
                name: profile?.displayName,
                streak: streak,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _TodayCard(),
            ),
            const SectionHeader('Deze week'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${week?.workouts ?? 0}',
                        label: 'Workouts',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${week?.sets ?? 0}',
                        label: 'Sets',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: formatters.volume(week?.volumeKg ?? 0),
                        label: 'Volume',
                        emphasis: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _RecoveryBlock(),
            if (records.isNotEmpty) ...[
              SectionHeader(
                'Laatste records',
                action: TextButton(
                  onPressed: () => context.push(Routes.records),
                  child: const Text('Alles'),
                ),
              ),
              for (final record in records)
                ListTile(
                  dense: true,
                  onTap: () =>
                      context.push(Routes.exerciseDetail(record.exercise.id)),
                  leading: ExerciseAvatar(
                    exercise: record.exercise,
                    size: 32,
                  ),
                  title: Text(record.exercise.name),
                  subtitle: Text(
                    '${record.type.label} · '
                    '${Formatters.relativeDay(DateTime.fromMillisecondsSinceEpoch(record.record.achievedAt)).toLowerCase()}',
                  ),
                  trailing: Text(
                    _recordValue(record, formatters),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.record,
                    ),
                  ),
                ),
            ],
            SectionHeader(
              'Volume, laatste 8 weken',
              action: TextButton(
                onPressed: () => context.go(Routes.progress),
                child: const Text('Meer'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MiniBarChart(
                      values: [for (final b in buckets) b.volumeKg],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          buckets.isEmpty
                              ? ''
                              : Formatters.dayMonth(buckets.first.weekStart),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Text(
                          'nu',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _recordValue(RecordWithExercise record, Formatters formatters) {
    switch (record.type) {
      case PrType.maxReps:
        return '${record.record.value.round()}';
      case PrType.maxSetVolume:
        return formatters.volume(record.record.value);
      case PrType.maxWeight:
      case PrType.est1rm:
        return formatters.weight(record.record.value);
    }
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.streak});

  final String? name;
  final StreakResult? streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final salutation = hour < 6
        ? 'Goedenacht'
        : hour < 12
        ? 'Goedemorgen'
        : hour < 18
        ? 'Goedemiddag'
        : 'Goedenavond';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name!.trim().isEmpty
              ? salutation
              : '$salutation, ${name!.trim()}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 16,
              color: (streak?.isActive ?? false)
                  ? AppColors.record
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              streak == null || !streak!.isActive
                  ? 'Nog geen reeks. Begin er een.'
                  : '${streak!.weeks} '
                        '${streak!.weeks == 1 ? 'week' : 'weken'} op rij'
                        '${streak!.daysSinceLast == null ? '' : ' · laatste workout ${Formatters.daysAgoWords(streak!.daysSinceLast!)}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = ref.watch(activeWorkoutProvider).value;
    final suggested = ref.watch(suggestedRoutineProvider).value;

    if (active != null) {
      return AppCard(
        borderColor: AppColors.accent,
        onTap: () => context.push(Routes.workout),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Je workout loopt', style: theme.textTheme.titleSmall),
                  Text(
                    active.workout.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    }

    if (suggested == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout van vandaag', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Je hebt nog geen routine. Maak er een, of start meteen een '
              'lege workout.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await ref
                          .read(workoutControllerProvider)
                          .startEmpty();
                      if (context.mounted) context.push(Routes.workout);
                    },
                    child: const Text('Lege workout'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go(Routes.train),
                    child: const Text('Routine maken'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout van vandaag',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(suggested.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            suggested.lastPerformedAt == null
                ? 'Nog nooit gedaan'
                : 'Laatst gedaan ${Formatters.relativeDay(DateTime.fromMillisecondsSinceEpoch(suggested.lastPerformedAt!)).toLowerCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(workoutControllerProvider)
                    .startFromRoutine(suggested.id);
                if (context.mounted) context.push(Routes.workout);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () =>
                  context.push(Routes.routineDetail(suggested.id)),
              child: const Text('Bekijk de routine'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which muscle groups are still recovering, and how much longer.
///
/// Hidden entirely until there is something to say: an empty card on the first
/// screen of the app is worse than no card.
class _RecoveryBlock extends ConsumerWidget {
  const _RecoveryBlock();

  /// More than this and the list stops being a glance.
  static const int maxRows = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(recoveryEstimatesProvider).value ?? const [];
    if (estimates.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final recovering = [
      for (final estimate in estimates)
        if (!estimate.isReadyAt(now)) estimate,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Herstel'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            child: recovering.isEmpty
                ? Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Alles hersteld volgens je logboek.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final estimate in recovering.take(maxRows))
                        RecoveryRow(estimate: estimate, now: now),
                      if (recovering.length > maxRows)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'en nog ${recovering.length - maxRows} andere',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
