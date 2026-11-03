/// The schema of a conversation, in a panel from the right - the way
/// Claude's Cowork keeps what a conversation works on beside it - and the
/// strip under the bar that opens it.
///
/// Over the tabs, what the coach proposes and waits for Aanvaarden or
/// Houden. Then the week, the sessions, every week, and the settings: what
/// changes there is saved at once, without asking the coach.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plan_weeks.dart';
import '../../../core/calc/schedule.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../routines/presentation/routine_providers.dart';
import 'plan_card.dart';
import 'plan_new_screen.dart';
import 'plan_providers.dart';
import 'plans_view.dart';

/// Opens the panel of [planId]. What it starts, opens or puts up for
/// discussion is done by the screen under it, once the panel is gone.
Future<void> showPlanPanel(
  BuildContext context, {
  required String planId,
  required ValueChanged<String> onStart,
  required ValueChanged<String> onOpen,
  required ValueChanged<RoutineRow> onDiscuss,
}) => showGeneralDialog<void>(
  context: context,
  useRootNavigator: true,
  barrierDismissible: true,
  barrierLabel: 'Sluiten',
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (context, _, _) => _PlanPanel(
    planId: planId,
    onStart: onStart,
    onOpen: onOpen,
    onDiscuss: onDiscuss,
  ),
  transitionBuilder: (context, animation, _, child) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    ),
    child: child,
  ),
);

/// Where a schema stands, in a line: the week and how much of it is done,
/// how far its building is, or when it ended.
String planStanding(
  TrainingPlanRow plan,
  List<RoutineRow> sessions,
  PlanWeekStanding? week,
  DateTime now,
) {
  final at = plan.weekAt(now);
  return switch (plan.state) {
    PlanStatus.draft => planProgress(plan, sessions),
    PlanStatus.done => switch (plan.endedAt) {
      final ended? =>
        'Afgerond ${Formatters.dayMonth(DateTime.fromMillisecondsSinceEpoch(ended))}',
      null => 'Afgerond',
    },
    PlanStatus.running when plan.isOverAt(now) => 'Alle weken voorbij',
    PlanStatus.running when at == 0 =>
      'Begint ${Formatters.weekdayDayMonthShort(plan.from!)}',
    PlanStatus.running =>
      'Week $at${plan.weeks == null ? '' : ' van ${plan.weeks}'} · '
          '${week?.doneCount ?? 0} van ${sessions.length} gedaan',
  };
}

/// What a week asks on top of the sessions, in words; null for a week that
/// is the sessions as they stand.
String? planWeekChange(PlanWeek week) {
  if (week.isDeload) return 'Deload: elke sessie lichter';
  String step(int value, String one, String many) =>
      '${value > 0 ? '+' : '−'}${Formatters.amount(value.abs(), one, many)}';
  final parts = [
    if (week.sets != 0) '${step(week.sets, 'set', 'sets')} per oefening',
    if (week.reps != 0)
      '${step(week.reps, 'herhaling', 'herhalingen')} per set',
    ?week.note,
  ];
  if (parts.isEmpty) return null;
  final line = parts.join(' · ');
  return '${line[0].toUpperCase()}${line.substring(1)}';
}

/// Under the bar of a schema's conversation: the schema, where it stands,
/// and what the coach proposes. A tap opens the panel.
class PlanStrip extends ConsumerWidget {
  const PlanStrip({super.key, required this.planId, required this.onOpen});

  final String planId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(planProvider(planId)).value;
    if (plan == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final sessions = ref.watch(planSessionsProvider(planId)).value ?? const [];
    final week = ref
        .watch(planWeekStandingProvider(planId, plan.weekAt(now)))
        .value;
    final waiting = ref.watch(planOpenChangesProvider(planId)).value ?? 0;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      // A line under it, where the conversation scrolls away.
      shape: Border(
        bottom: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      planStanding(plan, sessions, week, now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (waiting > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Text(
                    waiting == 1 ? '1 voorstel' : '$waiting voorstellen',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanPanel extends ConsumerWidget {
  const _PlanPanel({
    required this.planId,
    required this.onStart,
    required this.onOpen,
    required this.onDiscuss,
  });

  final String planId;
  final ValueChanged<String> onStart;
  final ValueChanged<String> onOpen;
  final ValueChanged<RoutineRow> onDiscuss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(400.0, size.width * 0.92);
    final plan = ref.watch(planProvider(planId)).value;
    final waiting =
        ref.watch(planWaitingChangesProvider(planId)).value ?? const [];

    /// Closes the panel, and then does [then] on the screen under it.
    void after<T>(ValueChanged<T> then, T value) {
      Navigator.of(context).pop();
      then(value);
    }

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Semantics(
        label: 'Schema',
        explicitChildNodes: true,
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: SafeArea(
              left: false,
              child: plan == null
                  ? const SizedBox.shrink()
                  : DefaultTabController(
                      length: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.sm,
                              AppSpacing.xs,
                              0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SCHEMA',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              letterSpacing: 0.8,
                                            ),
                                      ),
                                      Text(
                                        plan.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sluiten',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ),
                          // What waits for a yes or no, above whichever tab
                          // is open: it is what the panel is opened for.
                          if (waiting.isNotEmpty)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: size.height * 0.4,
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  AppSpacing.sm,
                                  AppSpacing.md,
                                  0,
                                ),
                                child: Column(
                                  children: [
                                    for (final change in waiting)
                                      PlanChangeCard(
                                        message: change.message,
                                        index: change.index,
                                        proposal: change.proposal,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          // All four in sight, also on a narrow phone with
                          // large letters: a name gets smaller rather than a
                          // tab sliding off the edge.
                          TabBar(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            tabs: [
                              for (final name in const [
                                'Week',
                                'Sessies',
                                'Weken',
                                'Instellen',
                              ])
                                Tab(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(name),
                                  ),
                                ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _WeekTab(
                                  plan: plan,
                                  onStart: (id) => after(onStart, id),
                                ),
                                _SessionsTab(
                                  plan: plan,
                                  onOpen: (id) => after(onOpen, id),
                                  onDiscuss: (session) =>
                                      after(onDiscuss, session),
                                ),
                                _WeeksTab(plan: plan),
                                _SettingsTab(plan: plan),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A line in a tab where there is nothing to show yet.
class _Nothing extends StatelessWidget {
  const _Nothing(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// One week at a time: each session on its day, done, open or missed, what
/// the week asks, and Start for what is still to do this week.
class _WeekTab extends ConsumerStatefulWidget {
  const _WeekTab({required this.plan, required this.onStart});

  final TrainingPlanRow plan;
  final ValueChanged<String> onStart;

  @override
  ConsumerState<_WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends ConsumerState<_WeekTab> {
  /// The week browsed to; null is this one.
  int? _week;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final start = plan.from;
    final count = plan.weeks ?? plan.planWeeks.length;
    if (start == null || count == 0) {
      return const _Nothing(
        'Het schema loopt nog niet. Als de opzet en elke sessie goedgekeurd '
        'zijn, start je het in het gesprek.',
      );
    }

    final now = DateTime.now();
    final current = plan.weekAt(now);
    final week = (_week ?? current).clamp(1, count);
    final running = plan.state == PlanStatus.running && !plan.isOverAt(now);
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    final done =
        ref.watch(planWeekStandingProvider(plan.id, week)).value?.done ??
        const <String>{};
    final first = planWeekStart(start, week);
    final last = DateTime(first.year, first.month, first.day + 6);
    final change = planWeekChange(plan.weekPlan(week));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Vorige week',
              icon: const Icon(Icons.chevron_left),
              onPressed: week > 1
                  ? () => setState(() => _week = week - 1)
                  : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Week $week van $count',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    week == current
                        ? 'Deze week'
                        : '${Formatters.dayMonth(first)} – '
                              '${Formatters.dayMonth(last)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Volgende week',
              icon: const Icon(Icons.chevron_right),
              onPressed: week < count
                  ? () => setState(() => _week = week + 1)
                  : null,
            ),
          ],
        ),
        if (change != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              change,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: plan.weekPlan(week).isDeload ? AppColors.record : null,
              ),
            ),
          ),
        for (final session in sessions)
          _WeekSession(
            session: session,
            done: done.contains(session.id),
            past: week < current,
            now: week == current,
            onStart: running && week == current && !done.contains(session.id)
                ? () => widget.onStart(session.id)
                : null,
          ),
      ],
    );
  }
}

class _WeekSession extends StatelessWidget {
  const _WeekSession({
    required this.session,
    required this.done,
    required this.past,
    required this.now,
    this.onStart,
  });

  final RoutineRow session;
  final bool done;

  /// The week is behind: what was not done, was missed.
  final bool past;

  /// The week is this one: what is not done, is open.
  final bool now;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (icon, color, state) = done
        ? (Icons.check_circle, AppColors.success, 'gedaan')
        : past
        ? (Icons.cancel_outlined, AppColors.danger, 'gemist')
        : (Icons.radio_button_unchecked, muted, now ? 'open' : null);
    final line = [
      if (session.planWeekday case final weekday?)
        Formatters.weekdayShort(weekday),
      ?state,
    ].join(' · ');
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(session.name),
      subtitle: line.isEmpty
          ? null
          : Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
      trailing: onStart == null
          ? null
          : FilledButton.tonal(onPressed: onStart, child: const Text('Start')),
    );
  }
}

/// Every session with its focus and how many exercises: Bespreek puts it
/// above the field, Openen opens it in the editor.
class _SessionsTab extends ConsumerWidget {
  const _SessionsTab({
    required this.plan,
    required this.onOpen,
    required this.onDiscuss,
  });

  final TrainingPlanRow plan;
  final ValueChanged<String> onOpen;
  final ValueChanged<RoutineRow> onDiscuss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    if (sessions.isEmpty) {
      return const _Nothing(
        'Nog geen sessies: de coach maakt ze in het gesprek.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final session in sessions)
          _SessionTile(
            session: session,
            onOpen: () => onOpen(session.id),
            onDiscuss: () => onDiscuss(session),
          ),
      ],
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({
    required this.session,
    required this.onOpen,
    required this.onDiscuss,
  });

  final RoutineRow session;
  final VoidCallback onOpen;
  final VoidCallback onDiscuss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final exercises = ref
        .watch(routineDetailProvider(session.id))
        .value
        ?.exercises
        .length;
    final line = [
      ?session.planFocus,
      if (exercises != null)
        // A session the coach has yet to make, not one of no exercises.
        exercises == 0
            ? 'nog geen oefeningen'
            : Formatters.amount(exercises, 'oefening', 'oefeningen'),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(session.name, style: theme.textTheme.titleSmall),
              ),
              if (session.planWeekday case final weekday?)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    Formatters.weekdayShort(weekday),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
            ],
          ),
          if (line.isNotEmpty)
            Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                onPressed: onDiscuss,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Bespreek'),
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Openen'),
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

/// The whole schema, week by week: what each asks, the deload marked, this
/// week in bold.
class _WeeksTab extends StatelessWidget {
  const _WeeksTab({required this.plan});

  final TrainingPlanRow plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final weeks = plan.planWeeks;
    if (weeks.isEmpty) {
      return const _Nothing(
        'Nog geen weken: de coach legt ze vast in de opzet.',
      );
    }
    final current = plan.state == PlanStatus.running
        ? plan.weekAt(DateTime.now())
        : 0;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final (i, week) in weeks.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: i + 1 == current ? FontWeight.w600 : null,
                      color: i + 1 == current
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    planWeekChange(week) ?? 'De sessies zoals ze staan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: week.isDeload
                          ? AppColors.record
                          : planWeekChange(week) == null
                          ? muted
                          : null,
                      fontWeight: i + 1 == current ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                if (i + 1 == current)
                  Text(
                    'nu',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The goal, the days and who sets the numbers, changed here and saved at
/// once - and Stoppen. A schema that ended is only looked at.
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.plan});

  final TrainingPlanRow plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final open = plan.state != PlanStatus.done;
    final plans = ref.read(databaseProvider).plansDao;
    final days = WeekdaySet(plan.days);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        if (!open)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(
              'Dit schema is afgerond: je kunt het nog bekijken.',
              style: muted,
            ),
          ),
        heading('Doel'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(plan.goal, style: theme.textTheme.bodyMedium)),
            if (open)
              IconButton(
                tooltip: 'Doel aanpassen',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final goal = await promptForText(
                    context,
                    title: 'Je doel',
                    initialValue: plan.goal,
                    maxLength: kPlanGoalLength,
                    maxLines: 4,
                  );
                  if (goal != null) {
                    await plans.setGoal(plan.id, goal, DateTime.now());
                  }
                },
              ),
          ],
        ),
        heading('Trainingsdagen'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              FilterChip(
                label: Text(Formatters.weekdayShort(d)),
                selected: days.has(d),
                onSelected: !open
                    ? null
                    : (_) {
                        final chosen = days.toggle(d);
                        if (chosen.isEmpty) {
                          showSnack(context, 'Kies minstens één dag.');
                          return;
                        }
                        plans.setDays(plan.id, chosen, DateTime.now());
                      },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Een richtlijn: een sessie op een andere dag telt gewoon mee. De '
          'sessies volgen de dagen, in hun volgorde.',
          style: muted,
        ),
        heading('Gewichten en herhalingen bijstellen'),
        SegmentedButton<PlanProgression>(
          segments: const [
            ButtonSegment(value: PlanProgression.app, label: Text('FitLog')),
            ButtonSegment(value: PlanProgression.coach, label: Text('Coach')),
          ],
          selected: {plan.progressionKind},
          onSelectionChanged: !open
              ? null
              : (picked) =>
                    plans.setProgression(plan.id, picked.first, DateTime.now()),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(planProgressionAbout(plan.progressionKind), style: muted),
        if (plan.state == PlanStatus.running) ...[
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => stopPlan(context, ref, plan),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Schema stoppen'),
          ),
        ],
      ],
    );
  }
}
