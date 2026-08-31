import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/colour_picker.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';
import 'history_providers.dart';

/// Everything you have logged: a month calendar on top, the sessions below.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// The day the calendar is filtered to, or null for the whole history.
  DateTime? _day;

  void _goToMonth(DateTime month) {
    setState(() {
      _month = month;
      // A day in a month you are no longer looking at would filter the list to
      // something the calendar cannot show you.
      _day = null;
    });
  }

  bool _isOn(DateTime day, int millis) {
    final at = DateTime.fromMillisecondsSinceEpoch(millis);
    return at.year == day.year && at.month == day.month && at.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider());
    final pending = ref.watch(pendingWorkoutDeletionsProvider);
    final monthWorkouts = ref
        .watch(workoutsInMonthProvider(_month.year, _month.month))
        .value ?? const [];
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geschiedenis')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (all) {
          // A workout inside its undo window is hidden, not gone.
          final workouts = all
              .where((w) => !pending.contains(w.workout.id))
              .toList();

          if (workouts.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'Nog geen workouts',
              message: 'Zodra je een sessie afrondt, verschijnt ze hier.',
              actionLabel: 'Naar routines',
              onAction: () => context.go(Routes.train),
            );
          }

          final day = _day;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _MonthCalendar(
                month: _month,
                workouts: monthWorkouts,
                selected: _day,
                onSelect: (day) => setState(
                  () => _day = _day != null && _isOn(_day!, day.millisecondsSinceEpoch)
                      ? null
                      : day,
                ),
                onPrevious: () => _goToMonth(
                  DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => _goToMonth(
                  DateTime(_month.year, _month.month + 1),
                ),
              ),
              SectionHeader(
                _day == null
                    ? 'Sessies'
                    : Formatters.relativeDay(_day!),
                action: _day == null
                    ? null
                    : TextButton(
                        onPressed: () => setState(() => _day = null),
                        child: const Text('Alles'),
                      ),
              ),
              for (final summary in day == null
                  ? workouts
                  : workouts
                        .where((w) => _isOn(day, w.workout.startedAt))
                        .toList())
                _WorkoutTile(
                  key: ValueKey(summary.workout.id),
                  summary: summary,
                  formatters: formatters,
                ),
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
    required this.selected,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final List<WorkoutRow> workouts;

  /// The day the list below is filtered to, or null for all of it.
  final DateTime? selected;

  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Volume per day, so a heavy day shows up darker than a light one, and
    // the colour of the session that ran that day, so you can tell a leg day
    // from a push day without opening anything.
    final byDay = <int, double>{};
    final colourByDay = <int, Color>{};
    for (final w in workouts) {
      final day = DateTime.fromMillisecondsSinceEpoch(w.startedAt).day;
      byDay.update(
        day,
        (v) => v + w.totalVolumeKg,
        ifAbsent: () => w.totalVolumeKg,
      );
      // Two sessions in one day and different colours: the first one wins,
      // rather than a colour that belongs to neither.
      final colour = AppColors.routineColor(w.colorIndex);
      if (colour != null) colourByDay.putIfAbsent(day, () => colour);
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
                final isSelected =
                    selected != null &&
                    selected!.year == month.year &&
                    selected!.month == month.month &&
                    selected!.day == day;

                // Only a day that has something to show responds. A tap that
                // empties the list below is worse than a tap that does
                // nothing.
                final cell = Container(
                  decoration: BoxDecoration(
                    color: volume == null
                        ? Colors.transparent
                        : (colourByDay[day] ?? AppColors.accent).withValues(
                            alpha: maxVolume <= 0
                                ? 0.3
                                : (0.25 + 0.55 * (volume / maxVolume))
                                      .clamp(0.25, 0.8),
                          ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 2,
                          )
                        : isToday
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

                if (volume == null) return cell;
                return GestureDetector(
                  onTap: () => onSelect(
                    DateTime(month.year, month.month, day),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: cell,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({
    super.key,
    required this.summary,
    required this.formatters,
  });

  final WorkoutSummary summary;
  final Formatters formatters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('dismiss-${summary.workout.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: AppColors.danger.withValues(alpha: 0.20),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) => confirmWorkoutDeletion(context),
      onDismissed: (_) =>
          deleteWorkoutWithUndo(context, ref, summary.workout),
      child: _tile(context, ref),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref) {
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
      leading: ColourDot(colorIndex: workout.colorIndex, size: 10),
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
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          if (value == 'repeat') {
            await repeatWorkout(context, ref, workout.id);
            return;
          }
          if (value != 'delete') return;
          if (!await confirmWorkoutDeletion(context)) return;
          if (context.mounted) {
            deleteWorkoutWithUndo(context, ref, workout);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'repeat', child: Text('Opnieuw doen')),
          PopupMenuItem(value: 'delete', child: Text('Verwijderen')),
        ],
      ),
    );
  }
}

/// Starts the same session again and opens it.
///
/// Refuses while another workout is running rather than quietly starting a
/// second one: the app has exactly one running session by design.
Future<void> repeatWorkout(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) async {
  try {
    await ref.read(workoutControllerProvider).repeat(workoutId);
    if (!context.mounted) return;
    context.push(Routes.workout);
  } on StateError {
    if (!context.mounted) return;
    showSnack(
      context,
      'Er loopt al een workout. Rond die eerst af.',
      isError: true,
    );
  }
}

Future<bool> confirmWorkoutDeletion(BuildContext context) => confirm(
  context,
  title: 'Workout verwijderen?',
  message:
      'De sessie verdwijnt uit je geschiedenis en je records worden opnieuw '
      'berekend. Je kunt dit nog vijf seconden ongedaan maken.',
  confirmLabel: 'Verwijderen',
  destructive: true,
);

/// Hides the workout, tells the user, and only really deletes it once the undo
/// window has passed.
void deleteWorkoutWithUndo(
  BuildContext context,
  WidgetRef ref,
  WorkoutRow workout,
) {
  final notifier = ref.read(pendingWorkoutDeletionsProvider.notifier);
  notifier.schedule(workout.id);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('"${workout.name}" verwijderd'),
        duration: PendingWorkoutDeletions.grace,
        action: SnackBarAction(
          label: 'Ongedaan maken',
          onPressed: () => notifier.undo(workout.id),
        ),
      ),
    );
}
