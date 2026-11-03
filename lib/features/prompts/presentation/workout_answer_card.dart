import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import 'prompt_providers.dart';

/// What the coach said about a workout, asked in the user's words
/// (Geplande prompts → Na je workout).
///
/// On the summary it asks by itself, once ([askNow]); in the history it shows
/// what was said, and asks on a tap. Nothing at all without a coach, or with
/// the prompt off and nothing asked.
class WorkoutAnswerCard extends ConsumerStatefulWidget {
  const WorkoutAnswerCard({
    super.key,
    required this.workoutId,
    this.askNow = false,
    this.padding = EdgeInsets.zero,
    this.actions = true,
  });

  final String workoutId;

  /// Around the card, and only when there is one: so a screen without it
  /// keeps no gap where it would be.
  final EdgeInsetsGeometry padding;

  /// Opnieuw and Verder vragen. Without them - where the settings try a
  /// prompt and have their own button - there is only an answer to show.
  final bool actions;

  /// Right after the workout: ask if it is due.
  final bool askNow;

  @override
  ConsumerState<WorkoutAnswerCard> createState() => _WorkoutAnswerCardState();
}

class _WorkoutAnswerCardState extends ConsumerState<WorkoutAnswerCard> {
  @override
  void initState() {
    super.initState();
    if (widget.askNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(workoutAskProvider(widget.workoutId).notifier).askIfDue();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(coachEnabledProvider)) return const SizedBox.shrink();
    final answer = ref.watch(workoutAnswerProvider(widget.workoutId));
    final state = ref.watch(workoutAskProvider(widget.workoutId));
    final prompt = ref.watch(momentPromptProvider(CoachMoment.workout));
    if (answer.isLoading || prompt == null) return const SizedBox.shrink();
    final row = answer.value;
    if (row == null && !state.busy && (!prompt.enabled || !widget.actions)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    void ask() => ref.read(workoutAskProvider(widget.workoutId).notifier).ask();

    final card = AppCard(
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Coach',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.busy)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('De coach leest je workout')),
              ],
            )
          else if (row == null)
            Text(
              'Vraag de coach wat hij van deze workout vindt, met je eigen '
              'prompt. Dat is één vraag.',
              style: muted,
            )
          else ...[
            if (row.coachText case final text?)
              Text(text, style: theme.textTheme.bodyMedium)
            else
              Text(
                row.coachError ?? 'De coach schreef niets.',
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Jouw prompt: ${row.prompt}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ],
          if (state.error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                error,
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (!state.busy && widget.actions)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              // Side by side where they fit, the one under the other on a
              // narrow phone with large text.
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  TextButton.icon(
                    onPressed: ask,
                    icon: Icon(
                      row == null ? Icons.smart_toy_outlined : Icons.refresh,
                      size: 18,
                    ),
                    label: Text(row == null ? 'Vraag de coach' : 'Opnieuw'),
                  ),
                  if (row?.coachText case final text?)
                    TextButton.icon(
                      onPressed: () => _askOn(row!, text),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Verder vragen'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    return Padding(padding: widget.padding, child: card);
  }

  /// A new conversation with what the coach said ready in the field, for the
  /// user to ask on from. Not sent: a question costs money, so the user
  /// sends it.
  Future<void> _askOn(WorkoutAnswerRow row, String text) async {
    final workout = await ref
        .read(databaseProvider)
        .workoutsDao
        .getWorkoutDetail(widget.workoutId);
    if (!mounted || workout == null) return;
    final day = Formatters.relativeDay(
      DateTime.fromMillisecondsSinceEpoch(workout.workout.startedAt),
    ).toLowerCase();
    ref
        .read(coachDraftProvider.notifier)
        .put(
          'Over mijn workout "${workout.workout.name}" van $day schreef je: '
          '"$text" ',
        );
    context.go(Routes.chat);
  }
}
