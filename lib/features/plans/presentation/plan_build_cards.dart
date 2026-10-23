/// The cards of a schema being built step by step: its outline, and one
/// session at a time - each with Goedkeuren, which asks the coach for the
/// next, and Aanpassen, which tells it what to change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../chat/domain/coach_proposal.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/plan_builder.dart';
import 'plan_providers.dart';
import 'plan_start_sheet.dart';

/// Goedkeuren, then the next question to the coach, in the same
/// conversation.
Future<void> _approveThen(
  WidgetRef ref,
  String threadId,
  Future<String?> Function() approve,
) async {
  final next = await approve();
  if (next == null) return;
  await ref
      .read(coachControllerProvider.notifier)
      .ask(threadId: threadId, question: next);
}

/// Aanpassen: what should change, in the user's words, to the coach.
Future<void> _askChange(
  BuildContext context,
  WidgetRef ref, {
  required String threadId,
  required String what,
}) async {
  final wish = await promptForText(
    context,
    title: 'Wat moet er anders aan $what?',
    hintText: 'Vervang de leg press door hack squats',
    confirmLabel: 'Vraag het de coach',
    maxLines: 4,
    maxLength: 400,
  );
  if (wish == null || wish.trim().isEmpty) return;
  await ref
      .read(coachControllerProvider.notifier)
      .ask(threadId: threadId, question: 'Pas $what aan: ${wish.trim()}');
}

class _CardHead extends StatelessWidget {
  const _CardHead(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.calendar_month_outlined,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

/// Goedkeuren and Aanpassen, as high as each other, also with large text on
/// a narrow phone.
class _Decide extends StatelessWidget {
  const _Decide({
    required this.busy,
    required this.onApprove,
    required this.onChange,
  });

  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: busy ? null : onApprove,
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Goedkeuren'),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: busy ? null : onChange,
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Aanpassen'),
          ),
        ),
      ),
    ],
  );
}

class _Done extends StatelessWidget {
  const _Done(this.text, {this.ok = true});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.history,
          size: 18,
          color: ok ? AppColors.success : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

/// The outline of a schema: its weeks, its sessions with their day and
/// focus, and the working sets per muscle group a week.
class PlanOutlineCard extends ConsumerStatefulWidget {
  const PlanOutlineCard({
    super.key,
    required this.message,
    required this.outline,
    required this.proposal,
  });

  final ChatMessageRow message;
  final OutlineProposal outline;
  final CoachProposal proposal;

  @override
  ConsumerState<PlanOutlineCard> createState() => _PlanOutlineCardState();
}

class _PlanOutlineCardState extends ConsumerState<PlanOutlineCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() step) async {
    setState(() => _busy = true);
    try {
      await step();
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
    final outline = widget.outline;
    final plan = ref.watch(planProvider(outline.planId));
    final deloads = [
      for (final (i, week) in outline.weeks.indexed)
        if (week.isDeload) i + 1,
    ];
    final threadId = widget.message.threadId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CardHead('Opzet van je schema'),
            const SizedBox(height: AppSpacing.xs),
            Text(outline.name, style: theme.textTheme.titleMedium),
            Text(
              [
                Formatters.amount(outline.weeks.length, 'week', 'weken'),
                '${Formatters.amount(outline.sessions.length, 'sessie', 'sessies')} '
                    'per week',
                if (deloads.isNotEmpty)
                  'deload in week ${deloads.join(' en ')}',
              ].join(' · '),
              style: muted,
            ),
            if (widget.proposal.change case final why?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(why, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final session in outline.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${session.weekday == null ? '' : '${Formatters.weekdayShort(session.weekday!)} · '}'
                            '${session.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (session.focus case final focus?)
                        TextSpan(text: ': $focus'),
                    ],
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (outline.volume.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Werksets per week: '
                '${[for (final MapEntry(:key, :value) in outline.volume.entries) '$key $value'].join(' · ')}',
                style: muted,
              ),
            ],
            for (final (i, week) in outline.weeks.indexed)
              if (week.note != null)
                Text('Week ${i + 1}: ${week.note}', style: muted),
            const SizedBox(height: AppSpacing.sm),
            switch (plan) {
              AsyncData(value: null) => Text(
                'Dit schema bestaat niet meer.',
                style: muted,
              ),
              AsyncData(value: final plan?) when plan.outlineAt != outline.at =>
                const _Done('Er is een nieuwere opzet.', ok: false),
              AsyncData(value: final plan?)
                  when plan.state == PlanStatus.draft &&
                      !plan.outlineApproved =>
                _Decide(
                  busy: _busy,
                  onApprove: () => _run(
                    () => _approveThen(
                      ref,
                      threadId,
                      () => PlanBuilder.approveOutline(
                        ref.read(databaseProvider),
                        outline.planId,
                      ),
                    ),
                  ),
                  onChange: () => _run(
                    () => _askChange(
                      context,
                      ref,
                      threadId: threadId,
                      what: 'de opzet',
                    ),
                  ),
                ),
              AsyncData(value: final plan?) => _Done(
                plan.state == PlanStatus.draft ? 'Goedgekeurd' : 'Opgeslagen',
              ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

/// One session of a schema, every exercise with its numbers.
class PlanSessionCard extends ConsumerStatefulWidget {
  const PlanSessionCard({
    super.key,
    required this.message,
    required this.session,
    required this.proposal,
  });

  final ChatMessageRow message;
  final SessionProposal session;
  final CoachProposal proposal;

  @override
  ConsumerState<PlanSessionCard> createState() => _PlanSessionCardState();
}

class _PlanSessionCardState extends ConsumerState<PlanSessionCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() step) async {
    setState(() => _busy = true);
    try {
      await step();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(TrainingPlanRow plan) async {
    final started = await showPlanStartSheet(context, ref, plan);
    if (started && mounted) await sayPlanStarted(context, ref, plan.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final format = ref.watch(formattersProvider);
    final session = widget.session;
    final plan = ref.watch(planProvider(session.planId)).value;
    final sessions = ref.watch(planSessionsProvider(session.planId)).value;
    final row = sessions?.where((s) => s.id == session.routineId).firstOrNull;
    final threadId = widget.message.threadId;

    String numbers(SessionExercise e) => [
      if (e.warmups > 0)
        Formatters.amount(e.warmups, 'warming-up', 'warming-ups'),
      '${e.sets}'
          '${e.reps != null
              ? '×${e.reps}'
              : e.seconds != null
              ? '×${e.seconds} s'
              : ' sets'}'
          '${e.weightKg == null ? '' : ' @ ${format.weight(e.weightKg)}'}',
      if (e.restSeconds case final rest?)
        'rust ${rest >= 60 && rest % 60 == 0 ? '${rest ~/ 60} min' : '$rest s'}',
    ].join(' · ');

    final Widget footer;
    if (plan == null || sessions == null) {
      footer = const SizedBox.shrink();
    } else if (row == null) {
      footer = Text('Deze sessie bestaat niet meer.', style: muted);
    } else if (row.updatedAt != session.savedAt) {
      footer = const _Done('Er is een nieuwere versie hieronder.', ok: false);
    } else if (plan.state == PlanStatus.draft &&
        row.sessionState == PlanSessionState.proposed) {
      footer = _Decide(
        busy: _busy,
        onApprove: () => _run(
          () => _approveThen(
            ref,
            threadId,
            () => PlanBuilder.approveSession(
              ref.read(databaseProvider),
              session.planId,
              session.routineId,
            ),
          ),
        ),
        onChange: () => _run(
          () =>
              _askChange(context, ref, threadId: threadId, what: session.name),
        ),
      );
    } else if (plan.state == PlanStatus.draft &&
        planComplete(plan, sessions) &&
        sessions.last.id == row.id) {
      // The last one approved: the schema is whole, and can begin.
      footer = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Done('Goedgekeurd. Alle sessies zijn klaar.'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _start(plan),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start schema'),
            ),
          ),
        ],
      );
    } else {
      footer = _Done(
        plan.state == PlanStatus.draft ? 'Goedgekeurd' : 'Opgeslagen',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardHead(
              session.weekday == null
                  ? 'Sessie van je schema'
                  : 'Sessie van je schema · '
                        '${Formatters.weekdayName(session.weekday!)}',
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(session.name, style: theme.textTheme.titleMedium),
            if (session.focus case final focus?) Text(focus, style: muted),
            if (widget.proposal.change case final why?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(why, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final exercise in session.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: theme.textTheme.titleSmall),
                    Text(numbers(exercise), style: theme.textTheme.bodySmall),
                    if (exercise.notes case final notes?)
                      Text(notes, style: muted),
                  ],
                ),
              ),
            footer,
          ],
        ),
      ),
    );
  }
}
