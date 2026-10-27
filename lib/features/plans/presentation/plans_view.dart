import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/coach_session.dart';
import '../../readiness/domain/training_check.dart';
import '../../readiness/presentation/check_providers.dart';
import '../../readiness/presentation/check_sheet.dart';
import '../../routines/presentation/routine_providers.dart';
import '../../routines/presentation/routine_start.dart';
import '../data/plan_actions.dart';
import 'plan_start_sheet.dart';
import 'plan_providers.dart';

/// Opens the conversation of [planId] in the Chat tab: where it was made,
/// and where the coach says what it would change.
Future<void> openPlanConversation(
  BuildContext context,
  WidgetRef ref,
  String planId,
) async {
  final thread = await ref.read(databaseProvider).chatDao.threadForPlan(planId);
  if (thread == null || !context.mounted) return;
  ref.read(coachSessionControllerProvider.notifier).show(thread.id);
  context.go(Routes.chat);
}

/// The Schema's half of Trainen: the one being followed and this week of
/// it, the ones still talked over, and the ones that were.
class PlansView extends ConsumerWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return plans.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (all) {
        if (all.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'Nog geen schema',
            message:
                'Vertel de coach wat je wil bereiken. Hij maakt een schema '
                'van een paar weken en past het onderweg aan.',
            actionLabel: 'Nieuw schema',
            onAction: () => context.push(Routes.planNew),
          );
        }
        final running = all
            .where((p) => p.state == PlanStatus.running)
            .firstOrNull;
        final drafts = [
          for (final plan in all)
            if (plan.state == PlanStatus.draft) plan,
        ];
        final done = [
          for (final plan in all)
            if (plan.state == PlanStatus.done) plan,
        ];
        if (running != null) {
          // No button floats over it: a new schema is under ⋮ while one is
          // followed, and the others are a line each below it.
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              _RunningPlan(plan: running, drafts: drafts, earlier: done),
            ],
          );
        }
        return ListView(
          // Room under the last row for the button that floats over it.
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            if (drafts.isNotEmpty) ...[
              const SectionHeader('In voorbereiding'),
              for (final plan in drafts) _DraftTile(plan: plan),
            ],
            if (done.isNotEmpty) ...[
              const SectionHeader("Eerdere schema's"),
              for (final plan in done) _EarlierTile(plan: plan),
            ],
          ],
        );
      },
    );
  }
}

/// A schema that was: how long, and when it ended.
class _EarlierTile extends ConsumerWidget {
  const _EarlierTile({required this.plan});

  final TrainingPlanRow plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.calendar_month_outlined),
    title: Text(plan.name),
    subtitle: Text(
      [
        if (plan.weeks case final weeks?)
          Formatters.amount(weeks, 'week', 'weken'),
        if (plan.endedAt case final at?)
          'afgerond ${Formatters.dayMonth(DateTime.fromMillisecondsSinceEpoch(at))}',
      ].join(' · '),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: ref.watch(coachEnabledProvider)
        ? () => openPlanConversation(context, ref, plan.id)
        : null,
  );
}

/// A schema still being built: how far, and Start schema once it is whole.
class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.plan});

  final TrainingPlanRow plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    final complete = planComplete(plan, sessions);
    return ListTile(
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(plan.name),
      subtitle: Text(planProgress(plan, sessions)),
      trailing: complete
          ? FilledButton(
              onPressed: () async {
                final started = await showPlanStartSheet(context, ref, plan);
                if (started && context.mounted) {
                  await sayPlanStarted(context, ref, plan.id);
                }
              },
              child: const Text('Start'),
            )
          : const Icon(Icons.chevron_right),
      onTap: ref.watch(coachEnabledProvider)
          ? () => openPlanConversation(context, ref, plan.id)
          : null,
    );
  }
}

/// How far a schema being built is: `Opzet wacht op akkoord`, `2 van 5
/// sessies goedgekeurd`, `Klaar om te starten`.
String planProgress(TrainingPlanRow plan, List<RoutineRow> sessions) {
  if (sessions.isEmpty) return 'De coach maakt de opzet';
  if (!plan.outlineApproved) return 'Opzet wacht op je akkoord';
  if (planComplete(plan, sessions)) return 'Klaar om te starten';
  final approved = sessions
      .where((s) => s.sessionState == PlanSessionState.approved)
      .length;
  return '$approved van ${sessions.length} sessies goedgekeurd';
}

/// Asks, and stops [plan]: it joins the earlier schema's.
Future<void> _stopPlan(
  BuildContext context,
  WidgetRef ref,
  TrainingPlanRow plan,
) async {
  final ok = await confirm(
    context,
    title: 'Schema stoppen?',
    message:
        '"${plan.name}" komt bij je eerdere schema\'s, met wat je erin '
        'deed. Opnieuw starten kan niet.',
    confirmLabel: 'Stoppen',
  );
  if (!ok) return;
  await PlanActions.stop(ref.read(databaseProvider), plan.id);
}

enum _PlanMenu { newPlan, about, stop }

/// The bar of Schema's while a schema is followed: its conversation - with
/// a dot when the coach proposes something - and under ⋮ a new schema,
/// what this one is, and stopping it. Nothing without one: then the button
/// at the bottom makes a schema.
class PlanShelfActions extends ConsumerWidget {
  const PlanShelfActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(runningPlanProvider).value;
    if (plan == null) return const SizedBox.shrink();
    final waiting = ref.watch(planOpenChangesProvider(plan.id)).value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ref.watch(coachEnabledProvider))
          IconButton(
            tooltip: 'Gesprek met de coach',
            onPressed: () => openPlanConversation(context, ref, plan.id),
            icon: Badge(
              isLabelVisible: waiting > 0,
              child: const Icon(Icons.forum_outlined),
            ),
          ),
        PopupMenuButton<_PlanMenu>(
          tooltip: 'Meer',
          onSelected: (item) => switch (item) {
            _PlanMenu.newPlan => context.push(Routes.planNew),
            _PlanMenu.about => showAppSheet<void>(
              context: context,
              title: plan.name,
              builder: (context) => _AboutPlan(plan: plan),
            ),
            _PlanMenu.stop => _stopPlan(context, ref, plan),
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _PlanMenu.newPlan,
              child: ListTile(
                leading: Icon(Icons.add),
                title: Text('Nieuw schema'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _PlanMenu.about,
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Over dit schema'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: _PlanMenu.stop,
              child: ListTile(
                leading: Icon(Icons.stop_circle_outlined),
                title: Text('Stoppen'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What a schema is, beyond this week: its split, who sets the numbers,
/// since when, and every week with what it is about.
class _AboutPlan extends StatelessWidget {
  const _AboutPlan({required this.plan});

  final TrainingPlanRow plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final current = plan.weekAt(DateTime.now());

    // The label as wide as it is, the value the rest and against the right
    // edge: shared halves broke "De coach zet ze elke week" over two lines
    // and left a short value standing in the middle.
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A value, not a sentence: no capital, as the split is said.
          fact('Split', switch (plan.splitKind) {
            PlanSplit.custom => 'eigen split',
            PlanSplit.coach => 'gekozen door de coach',
            final split => split.label.toLowerCase(),
          }),
          fact('Cijfers', switch (plan.progressionKind) {
            PlanProgression.app => 'FitLog stelt ze bij',
            PlanProgression.coach => 'De coach zet ze elke week',
          }),
          if (plan.from case final from?)
            fact(
              current >= 1 ? 'Begonnen' : 'Begint',
              Formatters.weekdayDayMonthShort(from),
            ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              'WEKEN',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final (i, week) in plan.planWeeks.indexed)
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
                      week.isDeload
                          ? 'Deload: elke sessie lichter'
                          : week.note == null
                          ? '-'
                          : _capital(week.note!),
                      style: week.isDeload
                          ? theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.record,
                            )
                          : week.note == null
                          ? muted
                          : theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _capital(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// The schema being followed: how far it is, and this week of it as a
/// list - the session to do now open, with what is in it and Start.
///
/// Each thing once: the weeks are the ring, this week's focus and how much
/// of it is done the line under the name. The split, who sets the numbers,
/// every week, stopping and a new schema are under ⋮ in the bar, the
/// conversation is the icon beside it.
class _RunningPlan extends ConsumerStatefulWidget {
  const _RunningPlan({
    required this.plan,
    required this.drafts,
    required this.earlier,
  });

  final TrainingPlanRow plan;
  final List<TrainingPlanRow> drafts;
  final List<TrainingPlanRow> earlier;

  @override
  ConsumerState<_RunningPlan> createState() => _RunningPlanState();
}

class _RunningPlanState extends ConsumerState<_RunningPlan> {
  /// The session tapped open; until then, the one to do now.
  String? _tapped;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = DateTime.now();
    final week = plan.weekAt(now);
    final over = plan.isOverAt(now);
    final current = week >= 1 && !over;
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    final standing = ref.watch(planThisWeekProvider(plan.id)).value;
    final done = standing?.done ?? const <String>{};
    final coach = ref.watch(coachEnabledProvider);
    final thisWeek = plan.weekPlan(week);
    final waiting = ref.watch(planOpenChangesProvider(plan.id)).value ?? 0;
    // Open is where Start goes: the session that was next, or when that one
    // had better wait, the readiest of the week - unless you opened another.
    final start = current
        ? ref.watch(todayCheckProvider)?.start.routineId ?? standing?.next
        : null;
    final tapped = _tapped;
    final open =
        current &&
            tapped != null &&
            !done.contains(tapped) &&
            sessions.any((s) => s.id == tapped)
        ? tapped
        : start;

    final line = [
      if (over)
        'Alle weken voorbij'
      else if (week == 0)
        'Begint ${Formatters.weekdayDayMonthShort(plan.from!)}'
      else if (thisWeek.isDeload)
        'Deloadweek: elke sessie lichter'
      else if (thisWeek.note case final note?)
        _capital(note),
      if (current) '${standing?.doneCount ?? 0} van ${sessions.length} gedaan',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _WeekRing(plan: plan, week: week, over: over),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: theme.textTheme.titleMedium),
                    if (line.isNotEmpty) Text(line, style: muted),
                  ],
                ),
              ),
            ],
          ),
          if (coach && waiting > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(
                  waiting == 1
                      ? 'De coach stelt iets voor'
                      : 'De coach stelt $waiting dingen voor',
                ),
                subtitle: const Text('Aanvaarden of houden'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPlanConversation(context, ref, plan.id),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (over) ...[
            Text(
              'Alle weken van dit schema zijn voorbij. Rond het af, of laat '
              'de coach een volgend maken.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        PlanActions.stop(ref.read(databaseProvider), plan.id),
                    child: const Text('Afronden'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push(Routes.planNew),
                    child: const Text('Nieuw schema'),
                  ),
                ),
              ],
            ),
          ] else
            AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Column(
                  children: [
                    for (final (i, session) in sessions.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      if (session.id == open)
                        _OpenSession(session: session)
                      else
                        _SessionRow(
                          session: session,
                          done: done.contains(session.id),
                          checked: current,
                          onOpen: current && !done.contains(session.id)
                              ? () => setState(() => _tapped = session.id)
                              : null,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          if (widget.drafts.isNotEmpty || widget.earlier.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          if (widget.drafts.isNotEmpty)
            _Shelf(
              title: 'In voorbereiding',
              children: [
                for (final draft in widget.drafts) _DraftTile(plan: draft),
              ],
            ),
          if (widget.earlier.isNotEmpty)
            _Shelf(
              title: "Eerdere schema's",
              children: [
                for (final plan in widget.earlier) _EarlierTile(plan: plan),
              ],
            ),
        ],
      ),
    );
  }
}

/// The weeks of a schema in a ring: the ones up to this one filled, the
/// ones to come faint, a deload in its own colour - and this week in the
/// middle.
class _WeekRing extends StatelessWidget {
  const _WeekRing({required this.plan, required this.week, required this.over});

  final TrainingPlanRow plan;
  final int week;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = plan.planWeeks;
    final count = weeks.isEmpty ? plan.weeks ?? 0 : weeks.length;
    final reached = over ? count : week;
    final size = MediaQuery.textScalerOf(context).scale(48).clamp(48.0, 72.0);
    return Semantics(
      label: over
          ? 'Alle weken voorbij'
          : week == 0
          ? 'Nog niet begonnen, $count weken'
          : 'Week $week van $count',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _WeekRingPainter(
            deloads: [
              for (var n = 1; n <= count; n++)
                n <= weeks.length && weeks[n - 1].isDeload,
            ],
            reached: reached,
            done: theme.colorScheme.primary,
            ahead: theme.colorScheme.outlineVariant,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  week == 0 && !over ? '–' : '$reached/$count',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekRingPainter extends CustomPainter {
  _WeekRingPainter({
    required this.deloads,
    required this.reached,
    required this.done,
    required this.ahead,
  });

  /// Per week, whether it is a deload.
  final List<bool> deloads;
  final int reached;
  final Color done;
  final Color ahead;

  @override
  void paint(Canvas canvas, Size size) {
    if (deloads.isEmpty) return;
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final gap = deloads.length > 1 ? 0.14 : 0.0;
    final sweep = 2 * math.pi / deloads.length;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final (i, deload) in deloads.indexed) {
      final behind = i < reached;
      paint.color = deload
          ? AppColors.record.withValues(alpha: behind ? 1 : 0.4)
          : behind
          ? done
          : ahead;
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WeekRingPainter old) =>
      old.reached != reached ||
      old.done != done ||
      old.ahead != ahead ||
      old.deloads.length != deloads.length;
}

/// `Deadlift 3 × 5 · Pull-up 4 × 8 · Plank 3 sets`: what a session holds,
/// in a line.
String sessionSummary(RoutineDetail detail) {
  String one(RoutineExerciseDetail exercise) {
    final working = [
      for (final set in exercise.sets)
        if (SetType.fromWire(set.setType) != SetType.warmup) set,
    ];
    final name = exercise.exercise.name.replaceAll(' ', ' ');
    if (working.isEmpty) return name;
    final reps = working.first.targetReps;
    // Hard spaces: a line breaks between exercises, not inside "Face Pull"
    // or "3 × 15".
    return reps == null
        ? '$name ${working.length} '
              '${working.length == 1 ? 'set' : 'sets'}'
        : '$name ${working.length} × $reps';
  }

  if (detail.exercises.isEmpty) return 'Nog geen oefeningen';
  return [for (final exercise in detail.exercises) one(exercise)].join(' · ');
}

/// The session to do now, open: what is in it, Start, and lighter.
class _OpenSession extends ConsumerWidget {
  const _OpenSession({required this.session});

  final RoutineRow session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detail = ref.watch(routineDetailProvider(session.id)).value;
    final check = ref.watch(trainingCheckProvider(session.id));
    return ColoredBox(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(session.name, style: theme.textTheme.titleMedium),
                ),
                if (check != null && check.informed) _CheckChip(check: check),
              ],
            ),
            if (detail != null)
              InkWell(
                onTap: () => context.push(Routes.routineDetail(session.id)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    40,
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    sessionSummary(detail),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        startSession(context, ref, routineId: session.id),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => startSession(
                    context,
                    ref,
                    routineId: session.id,
                    lighter: true,
                  ),
                  icon: const Icon(Icons.battery_3_bar),
                  label: const Text('Lichter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A session of this week, closed: done, or what the check says of it. A
/// tap opens one still to do; a done one, or one before the schema began,
/// opens its routine.
class _SessionRow extends ConsumerWidget {
  const _SessionRow({
    required this.session,
    required this.done,
    this.checked = false,
    this.onOpen,
  });

  final RoutineRow session;
  final bool done;

  /// Whether the session is checked: in a week of the schema, not done yet.
  final bool checked;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final day = switch (session.planWeekday) {
      final weekday? => Formatters.weekdayShort(weekday),
      null => null,
    };
    final check = checked && !done
        ? ref.watch(trainingCheckProvider(session.id))
        : null;
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? AppColors.success : muted,
        semanticLabel: done ? 'Gedaan' : null,
      ),
      title: Text(
        session.name,
        style: done ? theme.textTheme.bodyLarge?.copyWith(color: muted) : null,
      ),
      onTap: onOpen ?? () => context.push(Routes.routineDetail(session.id)),
      trailing: check != null && check.informed
          ? _CheckChip(check: check)
          : day == null
          ? null
          : Text(day, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
    );
  }
}

/// What the check says of a session, with a tap for where it comes from.
class _CheckChip extends ConsumerWidget {
  const _CheckChip({required this.check});

  final TrainingCheck check;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: () => showCheckSheet(context, ref, TodayCheck(lead: check)),
    borderRadius: BorderRadius.circular(8),
    child: _Chip(
      text: switch (check.verdict) {
        CheckVerdict.ready => 'klaar',
        CheckVerdict.note => 'let op',
        CheckVerdict.wait => 'beter wachten',
      },
      color: checkColor(check.verdict),
    ),
  );
}

/// Schema's besides the one followed, one line per kind, open on a tap.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      childrenPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(child: Text(title)),
          Text(
            '${children.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      children: children,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    ),
  );
}
