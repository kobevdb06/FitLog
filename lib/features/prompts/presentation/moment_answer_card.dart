import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../domain/coach_moments.dart';
import 'prompt_providers.dart';

/// What the coach said at a moment, asked in the user's words (Geplande
/// prompts), on the screen it is about.
///
/// Where the moment happens it asks by itself, once ([askNow]); elsewhere it
/// shows what was said, and asks on a tap. Nothing at all without a coach,
/// or with the prompt off and nothing asked.
class MomentAnswerCard extends ConsumerStatefulWidget {
  const MomentAnswerCard({
    super.key,
    required this.moment,
    required this.subject,
    this.askNow = false,
    this.padding = EdgeInsets.zero,
    this.actions = true,
    this.compact = false,
    this.about,
    this.title = 'Coach',
    this.onlyAnswered = false,
  });

  final CoachMoment moment;

  /// What it is about, as the moment reads it: a workout's id, a month.
  final String subject;

  /// Ask if it is due, the moment the card is shown.
  final bool askNow;

  /// Around the card, and only when there is one: so a screen without it
  /// keeps no gap where it would be.
  final EdgeInsetsGeometry padding;

  /// Opnieuw and Verder vragen. Without them - where the settings try a
  /// prompt and have their own button - there is only an answer to show.
  final bool actions;

  /// Three lines until tapped open: at the top of a workout, where the sets
  /// are what the screen is for.
  final bool compact;

  /// What the answer was about, in the question put ready in the chat:
  /// `mijn workout "Push" van vandaag`. The moment's name when null.
  final String? about;

  final String title;

  /// Nothing until something was asked: for what is not the moment itself,
  /// like an older schema in a list.
  final bool onlyAnswered;

  @override
  ConsumerState<MomentAnswerCard> createState() => _MomentAnswerCardState();
}

class _MomentAnswerCardState extends ConsumerState<MomentAnswerCard> {
  bool _open = false;

  MomentAskProvider get _ask =>
      momentAskProvider(widget.moment, widget.subject);

  @override
  void initState() {
    super.initState();
    if (widget.askNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(_ask.notifier).askIfDue();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(coachEnabledProvider)) return const SizedBox.shrink();
    final answer = ref.watch(
      momentAnswerProvider(widget.moment, widget.subject),
    );
    final state = ref.watch(_ask);
    final prompt = ref.watch(momentPromptProvider(widget.moment));
    if (answer.isLoading || prompt == null) return const SizedBox.shrink();
    final row = answer.value;
    if (row == null &&
        !state.busy &&
        (!prompt.enabled || !widget.actions || widget.onlyAnswered)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    void ask() => ref.read(_ask.notifier).ask();

    final card = AppCard(
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.4),
      onTap: widget.compact ? () => setState(() => _open = !_open) : null,
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
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (widget.compact && row?.coachText != null)
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
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
                Expanded(child: Text('De coach schrijft')),
              ],
            )
          else if (row == null)
            Text(
              'Vraag de coach, met je eigen prompt. Dat is één vraag.',
              style: muted,
            )
          else ...[
            if (row.coachText case final text?)
              Text(
                text,
                style: theme.textTheme.bodyMedium,
                maxLines: widget.compact && !_open ? 3 : null,
                overflow: widget.compact && !_open
                    ? TextOverflow.ellipsis
                    : null,
              )
            else
              Text(
                row.coachError ?? 'De coach schreef niets.',
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            if (!widget.compact || _open) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Jouw prompt: ${row.prompt}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ],
          ],
          if (state.error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                error,
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (!state.busy &&
              widget.actions &&
              (!widget.compact || _open || row == null))
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
                      onPressed: () => _askOn(text),
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
  void _askOn(String text) {
    final about = widget.about ?? '"${widget.moment.title}"';
    ref
        .read(coachDraftProvider.notifier)
        .put('Over $about schreef je: "$text" ');
    context.go(Routes.chat);
  }
}

/// Asks at [moment] about [subject] once it is shown, if it is due, and
/// shows nothing: for a place with no room for the answer, which is then
/// read elsewhere.
class MomentAsker extends ConsumerStatefulWidget {
  const MomentAsker({super.key, required this.moment, required this.subject});

  final CoachMoment moment;
  final String subject;

  @override
  ConsumerState<MomentAsker> createState() => _MomentAskerState();
}

class _MomentAskerState extends ConsumerState<MomentAsker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(momentAskProvider(widget.moment, widget.subject).notifier)
          .askIfDue();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
