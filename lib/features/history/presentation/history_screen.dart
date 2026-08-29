import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import 'history_providers.dart';

/// Everything you have logged: a month calendar on top, the sessions below.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider());
    final monthWorkouts = ref
        .watch(workoutsInMonthProvider(_month.year, _month.month))
        .value ?? const [];
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geschiedenis')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'Nog geen workouts',
              message: 'Zodra je een sessie afrondt, verschijnt ze hier.',
              actionLabel: 'Naar routines',
              onAction: () => context.go(Routes.train),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _MonthCalendar(
                month: _month,
                workouts: monthWorkouts,
                onPrevious: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
              const SectionHeader('Sessies'),
              for (final summary in workouts)
                _WorkoutTile(summary: summary, formatters: formatters),
            ],
          );
        },
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.workouts,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final List<WorkoutRow> workouts;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Volume per day, so a heavy day shows up darker than a light one.
    final byDay = <int, double>{};
    for (final w in workouts) {
      final day = DateTime.fromMillisecondsSinceEpoch(w.startedAt).day;
      byDay.update(
        day,
        (v) => v + w.totalVolumeKg,
        ifAbsent: () => w.totalVolumeKg,
      );
    }
    final maxVolume = byDay.values.isEmpty
        ? 0.0
        : byDay.values.reduce((a, b) => a > b ? a : b);

    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    Formatters.monthYear(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final label in const ['M', 'D', 'W', 'D', 'V', 'Z', 'Z'])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: firstWeekday - 1 + daysInMonth,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) return const SizedBox.shrink();
                final day = index - firstWeekday + 2;
                final volume = byDay[day];
                final isToday =
                    today.year == month.year &&
                    today.month == month.month &&
                    today.day == day;

                return Container(
                  decoration: BoxDecoration(
                    color: volume == null
                        ? Colors.transparent
                        : AppColors.accent.withValues(
                            alpha: maxVolume <= 0
                                ? 0.3
                                : (0.25 + 0.55 * (volume / maxVolume))
                                      .clamp(0.25, 0.8),
                          ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: isToday
                        ? Border.all(color: AppColors.accent, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: volume == null
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.white,
                      fontWeight: volume == null
                          ? FontWeight.w400
                          : FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.summary, required this.formatters});

  final WorkoutSummary summary;
  final Formatters formatters;

  @override
  Widget build(BuildContext context) {
    final workout = summary.workout;
    return ListTile(
      onTap: () => context.push(Routes.workoutDetail(workout.id)),
      title: Row(
        children: [
          Expanded(child: Text(workout.name)),
          if (summary.prCount > 0)
            PrBadge(label: '${summary.prCount}', compact: true),
        ],
      ),
      subtitle: Text(
        [
          Formatters.date(
            DateTime.fromMillisecondsSinceEpoch(workout.startedAt),
          ),
          Formatters.durationWords(workout.durationSeconds),
          formatters.volume(workout.totalVolumeKg),
          '${workout.totalSets} sets',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
