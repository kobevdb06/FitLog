import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../chat/domain/coach_proposal.dart';
import 'plan_providers.dart';
import 'plan_start_sheet.dart';

/// A schema the coach laid out or changed, in the conversation of that
/// schema.
///
/// The weeks and sessions are what the coach wrote at that moment; what is
/// at the bottom - Start schema, or how far it is - is the schema as it is
/// now, so an older card never offers to start a schema that is running.
class PlanProposalCard extends ConsumerStatefulWidget {
  const PlanProposalCard({super.key, required this.proposal});

  final CoachProposal proposal;

  @override
  ConsumerState<PlanProposalCard> createState() => _PlanProposalCardState();
}

class _PlanProposalCardState extends ConsumerState<PlanProposalCard> {
  bool _busy = false;

  Future<void> _start(TrainingPlanRow plan) async {
    setState(() => _busy = true);
    try {
      final started = await showPlanStartSheet(context, ref, plan);
      if (started && mounted) await sayPlanStarted(context, ref, plan.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final proposal = widget.proposal;
    final shown = proposal.plan!;
    final live = ref.watch(planProvider(proposal.appliedId!));
    final deloads = [
      for (final (i, week) in shown.weeks.indexed)
        if (week.isDeload) i + 1,
    ];
    final notes = [
      for (final (i, week) in shown.weeks.indexed)
        if (week.note != null) 'Week ${i + 1}: ${week.note}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    proposal.made ? 'Schema van de coach' : 'Schema aangepast',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(shown.name, style: theme.textTheme.titleMedium),
            Text(
              [
                Formatters.amount(shown.weeks.length, 'week', 'weken'),
                '${Formatters.amount(shown.sessions.length, 'sessie', 'sessies')} per week',
                if (deloads.isNotEmpty)
                  'deload in week ${deloads.join(' en ')}',
              ].join(' · '),
              style: muted,
            ),
            if (proposal.change case final why?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(why, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final session in shown.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${session.weekday == null ? '' : '${Formatters.weekdayShort(session.weekday!)} · '}'
                            '${session.name}: ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: [
                          for (final exercise in session.exercises)
                            '${exercise.name} ${exercise.sets}'
                                '${exercise.targetReps == null ? '' : '×${exercise.targetReps}'}',
                        ].join(', '),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final note in notes) Text(note, style: muted),
            const SizedBox(height: AppSpacing.sm),
            switch (live) {
              AsyncData(value: final plan?) => _footer(context, plan),
              AsyncData() => Text(
                'Dit schema bestaat niet meer.',
                style: muted,
              ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, TrainingPlanRow plan) {
    final theme = Theme.of(context);
    if (plan.state == PlanStatus.draft) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _start(plan),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start schema'),
        ),
      );
    }
    final now = DateTime.now();
    final week = plan.weekAt(now);
    final text = switch (plan.state) {
      PlanStatus.running when week == 0 && plan.from != null =>
        'Gestart · week 1 begint ${Formatters.weekdayDayMonth(plan.from!)}',
      PlanStatus.running when plan.isOverAt(now) => 'Alle weken zijn voorbij',
      PlanStatus.running =>
        'Loopt · week $week${plan.weeks == null ? '' : ' van ${plan.weeks}'}',
      _ => 'Afgelopen',
    };
    return Row(
      children: [
        Icon(
          plan.state == PlanStatus.running
              ? Icons.check_circle
              : Icons.flag_outlined,
          size: 18,
          color: plan.state == PlanStatus.running
              ? AppColors.success
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        if (plan.state == PlanStatus.running)
          TextButton(
            onPressed: () {
              ref
                  .read(trainShelfChoiceProvider.notifier)
                  .show(TrainShelf.plans);
              context.go(Routes.train);
            },
            child: const Text('Bekijken'),
          ),
      ],
    );
  }
}
