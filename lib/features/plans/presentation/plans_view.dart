import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/coach_session.dart';
import '../../routines/presentation/routine_start.dart';
import '../data/plan_actions.dart';
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
        return ListView(
          // Room under the last row for the button that floats over it.
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            if (running != null) _RunningPlan(plan: running),
            if (drafts.isNotEmpty) ...[
              const SectionHeader('In voorbereiding'),
              for (final plan in drafts)
                _PlanTile(
                  plan: plan,
                  subtitle: 'Verder in het gesprek met de coach',
                ),
            ],
            if (done.isNotEmpty) ...[
              const SectionHeader("Eerdere schema's"),
              for (final plan in done)
                _PlanTile(
                  plan: plan,
                  subtitle: [
                    if (plan.weeks case final weeks?)
                      Formatters.amount(weeks, 'week', 'weken'),
                    if (plan.endedAt case final at?)
                      'afgerond ${Formatters.dayMonth(DateTime.fromMillisecondsSinceEpoch(at))}',
                  ].join(' · '),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan, required this.subtitle});

  final TrainingPlanRow plan;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.calendar_month_outlined),
    title: Text(plan.name),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: ref.watch(coachEnabledProvider)
        ? () => openPlanConversation(context, ref, plan.id)
        : null,
  );
}

/// The schema being followed: where it is, and this week of it.
class _RunningPlan extends ConsumerWidget {
  const _RunningPlan({required this.plan});

  final TrainingPlanRow plan;

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = DateTime.now();
    final week = plan.weekAt(now);
    final weeks = plan.weeks ?? plan.planWeeks.length;
    final over = plan.isOverAt(now);
    final sessions = ref.watch(planSessionsProvider(plan.id)).value ?? const [];
    final standing = ref.watch(planThisWeekProvider(plan.id)).value;
    final coach = ref.watch(coachEnabledProvider);
    final thisWeek = plan.weekPlan(week);
    final waiting = ref.watch(planOpenChangesProvider(plan.id)).value ?? 0;

    final where = switch (week) {
      _ when over => 'Alle weken voorbij',
      0 => 'Begint ${Formatters.weekdayDayMonthShort(plan.from!)}',
      _ => 'Week $week van $weeks',
    };

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
          AppCard(
            borderColor: theme.colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    _Chip(text: where, color: theme.colorScheme.primary),
                    PopupMenuButton<String>(
                      tooltip: 'Meer',
                      onSelected: (_) => _finish(context, ref),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'stop', child: Text('Stoppen')),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${plan.splitKind == PlanSplit.custom
                      ? 'Eigen split'
                      : plan.splitKind == PlanSplit.coach
                      ? 'Split van de coach'
                      : plan.splitKind.label}'
                  ' · cijfers: ${plan.progressionKind.label}',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                _WeekStrip(plan: plan, current: over ? weeks + 1 : week),
                if (!over && week >= 1 && thisWeek.isDeload) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Deloadweek: elke sessie lichter.',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else if (!over && week >= 1 && thisWeek.note != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Deze week: ${thisWeek.note}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
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
                ] else if (coach) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          openPlanConversation(context, ref, plan.id),
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: const Text('Gesprek met de coach'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (over) ...[
            const SizedBox(height: AppSpacing.md),
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
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            // Side by side where there is room, the hint under it where
            // there is not: large text on a narrow phone.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  week == 0
                      ? 'WEEK 1'
                      : 'DEZE WEEK · ${standing?.doneCount ?? 0} VAN '
                            '${sessions.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                Text('dagen zijn een richtlijn', style: muted),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final session in sessions)
              _SessionRow(
                session: session,
                done: standing?.done.contains(session.id) ?? false,
                next: week >= 1 && standing?.next == session.id,
              ),
          ],
        ],
      ),
    );
  }
}

/// The weeks of a schema in a row: the ones behind it ticked, this one
/// outlined, a deload in its own colour.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.plan, required this.current});

  final TrainingPlanRow plan;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = plan.planWeeks;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var n = 1; n <= weeks.length; n++)
          Semantics(
            label:
                'Week $n${weeks[n - 1].isDeload ? ', deload' : ''}'
                '${n < current
                    ? ', voorbij'
                    : n == current
                    ? ', nu'
                    : ''}',
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minWidth: 40),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: n < current
                    ? AppColors.success.withValues(alpha: 0.18)
                    : weeks[n - 1].isDeload
                    ? AppColors.record.withValues(alpha: 0.18)
                    : null,
                border: Border.all(
                  color: n == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: n == current ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$n',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({
    required this.session,
    required this.done,
    required this.next,
  });

  final RoutineRow session;
  final bool done;
  final bool next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = switch (session.planWeekday) {
      final weekday? => Formatters.weekdayShort(weekday),
      null => null,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        session.name,
        style: next
            ? theme.textTheme.titleSmall
            : theme.textTheme.bodyLarge?.copyWith(
                color: done ? theme.colorScheme.onSurfaceVariant : null,
              ),
      ),
      subtitle: day == null ? null : Text(day),
      onTap: () => context.push(Routes.routineDetail(session.id)),
      trailing: done
          ? _Chip(text: 'Gedaan', color: AppColors.success)
          : next
          ? FilledButton.icon(
              onPressed: () =>
                  startSession(context, ref, routineId: session.id),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            )
          : null,
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
