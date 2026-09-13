import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/streak.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/colour_picker.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../backup/domain/backup_reminder.dart';
import '../../backup/presentation/backup_providers.dart';
import '../../progress/presentation/recovery_providers.dart';
import '../../progress/presentation/recovery_view.dart';
import '../../../routing/routes.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../workout/presentation/workout_providers.dart';
import '../domain/home_layout.dart';
import 'home_grid.dart';
import '../domain/today_plan.dart';
import 'today_providers.dart';

/// The Start tab: where you are, what is next, and one big button.
///
/// The blocks below it are the user's own list, in the user's own order. Only
/// the greeting and the backup warning are fixed: the first is the page's
/// heading, and the second is a warning you should not be able to switch off.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Arranging mode, the way a phone's own home screen has one: hold a block
  /// to get in, and everything that was a button becomes something you move.
  bool _editing = false;

  Future<void> _save(HomeLayout next) => ref
      .read(databaseProvider)
      .settingsDao
      .updateSettings(
        AppSettingsTableCompanion(homeLayout: Value(encodeHomeLayout(next))),
      );

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final streak = ref.watch(streakProvider).value;
    final layout = ref.watch(homeLayoutProvider);

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
              child: _editing
                  ? _ArrangeBar(
                      hidden: layout.blocks
                          .where((b) => !layout.shows(b))
                          .toList(),
                      onDone: () => setState(() => _editing = false),
                      onShow: (block) =>
                          _save(layout.withVisible(block, visible: true)),
                    )
                  : _Greeting(name: profile?.displayName, streak: streak),
            ),
            if (!_editing) const _BackupReminderBanner(),
            const SizedBox(height: AppSpacing.lg),
            // Holding anything on the grid starts arranging, which is the
            // gesture people already know from their launcher. The blocks
            // themselves take taps, so it cannot be a tap.
            GestureDetector(
              onLongPress: _editing
                  ? null
                  : () => setState(() => _editing = true),
              child: HomeGrid(
                layout: layout,
                editing: _editing,
                blockBuilder: (block, size) =>
                    _HomeBlockView(block: block, size: size),
                onMove: (block, onto) => _save(layout.movedOnto(block, onto)),
                onResize: (block) => _save(layout.resized(block)),
                onHide: (block) =>
                    _save(layout.withVisible(block, visible: false)),
              ),
            ),
            if (layout.visible.isEmpty && !_editing) const _EmptyHomeNotice(),
          ],
        ),
      ),
    );
  }
}

/// What the greeting turns into while you are arranging.
///
/// Also where a block you switched off comes back from: hidden blocks have no
/// place on the grid to drag them out of, so they wait here.
class _ArrangeBar extends StatelessWidget {
  const _ArrangeBar({
    required this.hidden,
    required this.onDone,
    required this.onShow,
  });

  final List<HomeBlock> hidden;
  final VoidCallback onDone;
  final void Function(HomeBlock block) onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Indelen', style: theme.textTheme.headlineSmall),
            ),
            FilledButton(onPressed: onDone, child: const Text('Klaar')),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sleep om te verplaatsen, tik om groot of klein te maken.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final block in hidden)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(block.label),
                  onPressed: () => onShow(block),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One block of the Start tab, at the size the layout gave it.
class _HomeBlockView extends StatelessWidget {
  const _HomeBlockView({required this.block, required this.size});

  final HomeBlock block;
  final HomeBlockSize size;

  @override
  Widget build(BuildContext context) => switch (block) {
    HomeBlock.today => _TodayCard(size: size),
    HomeBlock.favourites => _FavouritesBlock(size: size),
    HomeBlock.week => _WeekBlock(size: size),
    HomeBlock.recovery => _RecoveryBlock(size: size),
    HomeBlock.records => _RecordsBlock(size: size),
    HomeBlock.volume => _VolumeBlock(size: size),
  };
}

/// The frame every block sits in: a card with its name along the top.
///
/// The names used to be section headers spanning the screen, which only works
/// while every block is full width. Two blocks side by side need their name
/// inside them.
class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.title,
    required this.child,
    this.action,
    this.onTap,
  });

  final String title;
  final Widget child;

  /// The "Alles" or "Meer" link, which has no room on a small block.
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// What is left when you switch everything off.
///
/// An empty screen with no way back would be the app overruling you; this says
/// what happened and where to undo it.
class _EmptyHomeNotice extends StatelessWidget {
  const _EmptyHomeNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: EmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'Je startscherm is leeg',
        message:
            'Je hebt alle blokken uitgezet. Zet er weer een aan om hier '
            'iets te zien.',
        actionLabel: 'Startscherm indelen',
        onAction: () => context.push(Routes.settingsHome),
      ),
    );
  }
}

/// Your starred routines, one tap from starting.
///
/// Off unless you ask for it, and silent when the block above is already
/// showing them: with no schedule, "Vandaag" falls through to your favourites,
/// and the same three routines twice is not a layout choice anybody made.
class _FavouritesBlock extends ConsumerWidget {
  const _FavouritesBlock({required this.size});

  final HomeBlockSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouriteRoutinesProvider).value ?? const [];
    if (favourites.isEmpty) return const SizedBox.shrink();

    final layout = ref.watch(homeLayoutProvider);
    final alreadyShown =
        layout.shows(HomeBlock.today) &&
        ref.watch(todayPlanProvider).kind == TodayPlanKind.favourites;
    if (alreadyShown) return const SizedBox.shrink();

    // Half a screen has room for one, and one you can actually read beats
    // three you cannot.
    final shown = size == HomeBlockSize.small ? favourites.take(1) : favourites;

    return _BlockCard(
      title: 'Favorieten',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final routine in shown)
            _FavouriteRow(
              routine: routine,
              compact: size == HomeBlockSize.small,
            ),
        ],
      ),
    );
  }
}

class _FavouriteRow extends ConsumerWidget {
  const _FavouriteRow({required this.routine, required this.compact});

  final RoutineRow routine;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> start() async {
      await ref.read(workoutControllerProvider).startFromRoutine(routine.id);
      if (context.mounted) context.push(Routes.workout);
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            routine.name,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: start,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start'),
            ),
          ),
        ],
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push(Routes.routineDetail(routine.id)),
      leading: ColourDot(colorIndex: routine.colorIndex),
      title: Text(routine.name),
      subtitle: Text(
        routine.lastPerformedAt == null
            ? 'Nog nooit gedaan'
            : Formatters.relativeDay(
                DateTime.fromMillisecondsSinceEpoch(routine.lastPerformedAt!),
              ),
      ),
      trailing: IconButton(
        tooltip: 'Starten',
        icon: const Icon(Icons.play_arrow),
        onPressed: start,
      ),
    );
  }
}

class _WeekBlock extends ConsumerWidget {
  const _WeekBlock({required this.size});

  final HomeBlockSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(thisWeekStatsProvider).value;
    final formatters = ref.watch(formattersProvider);

    // Three numbers do not fit in half a screen without becoming unreadable,
    // and volume is the one that says most about a week.
    if (size == HomeBlockSize.small) {
      return _BlockCard(
        title: 'Deze week',
        child: StatTile(
          value: formatters.volume(week?.volumeKg ?? 0),
          label: '${week?.workouts ?? 0} workouts',
          emphasis: true,
        ),
      );
    }

    return _BlockCard(
      title: 'Deze week',
      child: Row(
        children: [
          Expanded(
            child: StatTile(value: '${week?.workouts ?? 0}', label: 'Workouts'),
          ),
          Expanded(
            child: StatTile(value: '${week?.sets ?? 0}', label: 'Sets'),
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
    );
  }
}

class _RecordsBlock extends ConsumerWidget {
  const _RecordsBlock({required this.size});

  final HomeBlockSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(latestRecordsProvider()).value ?? const [];
    if (records.isEmpty) return const SizedBox.shrink();

    final formatters = ref.watch(formattersProvider);
    final theme = Theme.of(context);

    if (size == HomeBlockSize.small) {
      final newest = records.first;
      return _BlockCard(
        title: 'Laatste record',
        onTap: () => context.push(Routes.exerciseDetail(newest.exercise.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _recordValue(newest, formatters),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.record,
              ),
            ),
            Text(
              newest.exercise.name,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return _BlockCard(
      title: 'Laatste records',
      action: TextButton(
        onPressed: () => context.push(Routes.records),
        child: const Text('Alles'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final record in records)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () =>
                  context.push(Routes.exerciseDetail(record.exercise.id)),
              leading: ExerciseAvatar(exercise: record.exercise, size: 32),
              title: Text(record.exercise.name),
              subtitle: Text(
                '${record.type.label} · '
                '${Formatters.relativeDay(DateTime.fromMillisecondsSinceEpoch(record.record.achievedAt)).toLowerCase()}',
              ),
              trailing: Text(
                _recordValue(record, formatters),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.record,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
    case PrType.maxDuration:
      return Formatters.duration(record.record.value.round());
    case PrType.maxDistance:
      return formatters.distance(record.record.value);
  }
}

class _VolumeBlock extends ConsumerWidget {
  const _VolumeBlock({required this.size});

  final HomeBlockSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = ref.watch(weeklyBucketsProvider()).value ?? const [];
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final chart = MiniBarChart(values: [for (final b in buckets) b.volumeKg]);

    // The dates under the bars are the first thing to go: at half width they
    // would sit on top of each other.
    if (size == HomeBlockSize.small) {
      return _BlockCard(
        title: 'Volume, 8 weken',
        onTap: () => context.go(Routes.progress),
        child: chart,
      );
    }

    return _BlockCard(
      title: 'Volume, laatste 8 weken',
      action: TextButton(
        onPressed: () => context.go(Routes.progress),
        child: const Text('Meer'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          chart,
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                buckets.isEmpty
                    ? ''
                    : Formatters.dayMonth(buckets.first.weekStart),
                style: muted,
              ),
              Text('nu', style: muted),
            ],
          ),
        ],
      ),
    );
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
            // The line grows with your streak - "3 weken op rij · laatste
            // workout 5 dagen geleden" - and without a flex it simply ran off
            // a narrow phone. Trimmed rather than wrapped: it is one line
            // under a heading, and two would push the first block down.
            Expanded(
              child: Text(
                streak == null || !streak!.isActive
                    ? 'Nog geen reeks. Begin er een.'
                    : '${streak!.weeks} '
                          '${streak!.weeks == 1 ? 'week' : 'weken'} op rij'
                          '${streak!.daysSinceLast == null ? '' : ' · laatste workout ${Formatters.daysAgoWords(streak!.daysSinceLast!)}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The card at the top of the Start tab: what today is for.
///
/// It used to say "Workout van vandaag" above whichever routine had been left
/// alone longest, which was a claim the app could not back up - nothing told it
/// what happens on a Tuesday. Now the heading says which rung of
/// [buildTodayPlan] is talking, so the card never promises more than it knows.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.size});

  final HomeBlockSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).value;
    if (active != null) return _RunningCard(active: active);

    final plan = ref.watch(todayPlanProvider);
    if (size == HomeBlockSize.small) return _CompactPlanCard(plan: plan);

    return switch (plan.kind) {
      TodayPlanKind.none => const _NoRoutinesCard(),
      TodayPlanKind.rest => _RestCard(plan: plan),
      _ => _PlanCard(plan: plan),
    };
  }
}

/// What today is for, in half a screen.
///
/// The name and one button. Everything the wide card adds - when you last did
/// it, the routine behind it, what else is on today - needs room this does not
/// have, and a squeezed version of all of it would say none of it clearly.
class _CompactPlanCard extends ConsumerWidget {
  const _CompactPlanCard({required this.plan});

  final TodayPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lead = plan.lead;

    if (lead == null) {
      return _BlockCard(
        title: plan.kind == TodayPlanKind.rest ? 'Rustdag' : 'Vandaag',
        onTap: () => context.go(Routes.train),
        child: Text(
          plan.kind == TodayPlanKind.rest
              ? 'Niets ingepland.'
              : 'Nog geen routine.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return _BlockCard(
      title: 'Vandaag',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lead.routine.name,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(workoutControllerProvider)
                    .startFromRoutine(lead.routine.id);
                if (context.mounted) context.push(Routes.workout);
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(lead.doneToday ? 'Nog een keer' : 'Start'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({required this.active});

  final WorkoutDetail active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

class _NoRoutinesCard extends ConsumerWidget {
  const _NoRoutinesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nog geen routine', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Maak er een en plan hem op je trainingsdagen, of start meteen '
            'een lege workout.',
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
                    await ref.read(workoutControllerProvider).startEmpty();
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
}

/// A day your own schedule leaves empty.
///
/// It says so rather than reaching for something to offer: a rest day is an
/// answer, and pushing a workout onto it would undo the plan you made. What it
/// does say is when the next one is, and it leaves the door open.
class _RestCard extends ConsumerWidget {
  const _RestCard({required this.plan});

  final TodayPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bedtime_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Rustdag', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _next(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(Routes.train),
              child: const Text('Toch trainen'),
            ),
          ),
        ],
      ),
    );
  }

  String _next() {
    final weekday = plan.nextWeekday;
    if (weekday == null || plan.nextRoutines.isEmpty) {
      return 'Er staat verder niets in je week.';
    }
    final names = [for (final routine in plan.nextRoutines) routine.name];
    return '${Formatters.nextDayWords(plan.daysUntilNext!, weekday)}: ${names.join(', ')}';
  }
}

/// One or more routines to start, whichever rung of the ladder they came from.
class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final TodayPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lead = plan.lead!;
    final others = plan.rest;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _heading(plan.kind),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(lead.routine.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _subtitle(lead),
            style: theme.textTheme.bodySmall?.copyWith(
              color: lead.doneToday
                  ? AppColors.success
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _start(context, ref, lead.routine.id),
              icon: const Icon(Icons.play_arrow),
              label: Text(lead.doneToday ? 'Nog een keer' : 'Start workout'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () =>
                  context.push(Routes.routineDetail(lead.routine.id)),
              child: const Text('Bekijk de routine'),
            ),
          ),
          if (others.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            Text(
              plan.kind == TodayPlanKind.favourites
                  ? 'Of een van deze'
                  : 'Ook vandaag',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final planned in others)
              _OtherRoutineRow(
                planned: planned,
                onStart: () => _start(context, ref, planned.routine.id),
              ),
          ],
        ],
      ),
    );
  }

  String _heading(TodayPlanKind kind) => switch (kind) {
    TodayPlanKind.scheduled => 'Vandaag',
    TodayPlanKind.allDone => 'Vandaag - alles gedaan',
    TodayPlanKind.favourites => 'Je favorieten',
    // Nothing planned and nothing starred, so the card says what is really
    // going on rather than suggesting today had anything to do with it.
    _ => 'Hier was je het langst niet mee bezig',
  };

  String _subtitle(PlannedRoutine planned) {
    if (planned.doneToday) return 'Vandaag al gedaan';
    final last = planned.routine.lastPerformedAt;
    if (last == null) return 'Nog nooit gedaan';
    final at = DateTime.fromMillisecondsSinceEpoch(last);
    return 'Laatst gedaan ${Formatters.relativeDay(at).toLowerCase()}';
  }

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    String routineId,
  ) async {
    await ref.read(workoutControllerProvider).startFromRoutine(routineId);
    if (context.mounted) context.push(Routes.workout);
  }
}

class _OtherRoutineRow extends StatelessWidget {
  const _OtherRoutineRow({required this.planned, required this.onStart});

  final PlannedRoutine planned;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push(Routes.routineDetail(planned.routine.id)),
      title: Text(planned.routine.name),
      subtitle: planned.doneToday
          ? Text(
              'Gedaan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
              ),
            )
          : null,
      trailing: planned.doneToday
          ? const Icon(Icons.check_circle_outline, color: AppColors.success)
          : IconButton(
              tooltip: 'Starten',
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
            ),
    );
  }
}

/// Which muscle groups are still recovering, and how much longer.
///
/// Hidden entirely until there is something to say: an empty card on the first
/// screen of the app is worse than no card.
class _RecoveryBlock extends ConsumerWidget {
  const _RecoveryBlock({required this.size});

  final HomeBlockSize size;

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

    final theme = Theme.of(context);

    // Half a screen has no room for a list of muscles and how long each has
    // left, so it says the one thing you would have read off it anyway.
    if (size == HomeBlockSize.small) {
      return _BlockCard(
        title: 'Herstel',
        onTap: () => context.go(Routes.progress),
        child: recovering.isEmpty
            ? Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Alles hersteld',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${recovering.length}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Text(
                    recovering.length == 1
                        ? 'spier herstelt nog'
                        : 'spieren herstellen nog',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      );
    }

    return _BlockCard(
      title: 'Herstel',
      child: recovering.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Alles hersteld volgens je logboek.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final estimate in recovering.take(maxRows))
                  RecoveryRow(estimate: estimate, now: now),
                if (recovering.length > maxRows)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'en nog ${recovering.length - maxRows} andere',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One line when the backup is old or missing, and nothing at all otherwise.
///
/// Everything the app knows sits in one file on this phone. It will not nag on
/// an empty install - there is nothing to lose yet - but once there is history
/// it says so rather than letting the user find out the hard way.
class _BackupReminderBanner extends ConsumerWidget {
  const _BackupReminderBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(backupReminderProvider);
    if (reminder == BackupReminder.none) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final last = ref.watch(lastBackupAtProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: InkWell(
        onTap: () => context.push(Routes.settingsBackup),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AppCard(
          child: Row(
            children: [
              Icon(
                Icons.backup_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder == BackupReminder.never
                          ? 'Nog geen back-up'
                          : 'Je back-up is ${Formatters.daysAgoWords(DateTime.now().difference(last!).inDays)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'Alles staat alleen op dit toestel.',
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
        ),
      ),
    );
  }
}
