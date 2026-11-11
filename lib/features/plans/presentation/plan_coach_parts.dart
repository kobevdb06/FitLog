import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../chat/domain/coach_proposal.dart';
import '../../chat/presentation/coach_plan_parts.dart';
import '../../chat/presentation/coach_session.dart';
import '../data/plan_actions.dart';
import 'plan_build_cards.dart';
import 'plan_card.dart';
import 'plan_panel.dart';
import 'plan_providers.dart';
import 'plans_view.dart' show planProgress;

/// The schema's in the coach: their cards in a conversation, the strip
/// and panel of a schema's conversation, and the Schema's list in the
/// drawer (DECISIONS 301).
class PlanCoachParts implements CoachPlanParts {
  const PlanCoachParts();

  @override
  Widget? card(ChatMessageRow message, int index, CoachProposal proposal) {
    if (proposal.kind == ProposalKind.plan) {
      return PlanProposalCard(proposal: proposal);
    }
    if (proposal.outline case final outline?) {
      return PlanOutlineCard(
        message: message,
        outline: outline,
        proposal: proposal,
      );
    }
    if (proposal.session case final session?) {
      return PlanSessionCard(
        message: message,
        session: session,
        proposal: proposal,
      );
    }
    if (proposal.kind == ProposalKind.planChange) {
      return PlanChangeCard(message: message, index: index, proposal: proposal);
    }
    return null;
  }

  @override
  Widget strip(String planId, {required VoidCallback onOpen}) =>
      PlanStrip(planId: planId, onOpen: onOpen);

  @override
  Future<void> showPanel(
    BuildContext context,
    String planId, {
    required ValueChanged<String> onStart,
    required ValueChanged<String> onOpen,
    required ValueChanged<RoutineRow> onDiscuss,
  }) => showPlanPanel(
    context,
    planId: planId,
    onStart: onStart,
    onOpen: onOpen,
    onDiscuss: onDiscuss,
  );

  @override
  Widget shelf({
    required String? shown,
    required ValueChanged<ChatThreadRow> onOpen,
    required Widget Function(String label) heading,
  }) => _PlanShelf(shown: shown, onOpen: onOpen, heading: heading);
}

/// Lopend, In voorbereiding and Afgerond, each schema with where it is and
/// how many proposals wait in its conversation.
class _PlanShelf extends ConsumerWidget {
  const _PlanShelf({
    required this.shown,
    required this.onOpen,
    required this.heading,
  });

  final String? shown;
  final ValueChanged<ChatThreadRow> onOpen;
  final Widget Function(String label) heading;

  /// Stoppen, for the one being followed, and Verwijderen - the schema with
  /// its conversation. What was done in its sessions stays in the history.
  Future<void> _actions(
    BuildContext context,
    WidgetRef ref,
    TrainingPlanRow plan,
    ChatThreadRow? thread,
  ) async {
    final theme = Theme.of(context);
    final running = plan.state == PlanStatus.running;
    final picked = await showAppSheet<String>(
      context: context,
      title: plan.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('Stoppen'),
              onTap: () => Navigator.of(context).pop('stop'),
            ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Verwijderen',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || picked == null) return;
    final db = ref.read(databaseProvider);

    if (picked == 'stop') {
      final ok = await confirm(
        context,
        title: 'Schema stoppen?',
        message:
            '"${plan.name}" komt bij je eerdere schema\'s, met wat je erin '
            'deed. Opnieuw starten kan niet.',
        confirmLabel: 'Stoppen',
      );
      if (ok) await PlanActions.stop(db, plan.id);
      return;
    }

    final ok = await confirm(
      context,
      title: 'Schema verwijderen?',
      message:
          '"${plan.name}", zijn sessies en het gesprek erover verdwijnen. '
          'Wat je al trainde, blijft in je geschiedenis.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok) return;
    await PlanActions.delete(db, plan.id);
    if (thread != null) {
      await db.chatDao.deleteThread(thread.id);
      if (ref.read(coachSessionControllerProvider).threadId == thread.id) {
        ref.read(coachSessionControllerProvider.notifier).startNew();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final plans = ref.watch(plansProvider).value ?? const [];
    final planThreads = ref.watch(planThreadsProvider).value ?? const [];

    Widget planTile(TrainingPlanRow plan) {
      final thread = planThreads.where((t) => t.planId == plan.id).firstOrNull;
      final week = plan.weekAt(now);
      final where = switch (plan.state) {
        PlanStatus.draft => planProgress(
          plan,
          ref.watch(planSessionsProvider(plan.id)).value ?? const [],
        ),
        PlanStatus.running when plan.isOverAt(now) => 'Alle weken voorbij',
        PlanStatus.running when week == 0 => 'Begint maandag',
        PlanStatus.running =>
          'Week $week${plan.weeks == null ? '' : ' van ${plan.weeks}'}',
        PlanStatus.done => switch (plan.endedAt) {
          final at? =>
            'Afgerond ${Formatters.dayMonth(DateTime.fromMillisecondsSinceEpoch(at))}',
          null => 'Afgerond',
        },
      };
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.only(left: AppSpacing.sm),
        selected: thread != null && thread.id == shown,
        selectedTileColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          plan.state == PlanStatus.running
              ? Icons.event_available
              : Icons.calendar_month_outlined,
          size: 18,
        ),
        minLeadingWidth: 20,
        title: Text(
          plan.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          switch (ref.watch(planOpenChangesProvider(plan.id)).value ?? 0) {
            0 => where,
            1 => '$where · 1 voorstel wacht',
            final n => '$where · $n voorstellen wachten',
          },
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          tooltip: 'Meer',
          icon: const Icon(Icons.more_vert, size: 18),
          onPressed: () => _actions(context, ref, plan, thread),
        ),
        onTap: thread == null ? null : () => onOpen(thread),
        onLongPress: () => _actions(context, ref, plan, thread),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      children: [
        for (final (label, state) in const [
          ('Lopend', PlanStatus.running),
          ('In voorbereiding', PlanStatus.draft),
          ('Afgerond', PlanStatus.done),
        ])
          if (plans.where((p) => p.state == state).toList() case final some
              when some.isNotEmpty) ...[
            heading(label),
            for (final plan in some) planTile(plan),
          ],
        if (plans.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              'Nog geen schema\'s. Met Nieuw schema maakt de coach er een, op '
              'jouw doel.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
