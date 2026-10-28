import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/recovery.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../routines/presentation/routine_start.dart';
import '../domain/training_check.dart';
import '../../../core/formatting/formatters.dart';

/// The colour of a verdict: green when ready, amber otherwise.
Color checkColor(CheckVerdict verdict) =>
    verdict == CheckVerdict.ready ? AppColors.success : AppColors.record;

/// The check's one line on a card, with a tap for where it comes from.
class CheckLine extends StatelessWidget {
  const CheckLine({super.key, required this.check, required this.onTap});

  final TrainingCheck check;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = checkColor(check.verdict);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Semantics(
        button: true,
        hint: 'Toont de check',
        child: Row(
          children: [
            Icon(
              check.verdict == CheckVerdict.ready
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 16,
              color: colour,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                check.line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: colour),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What can be done from the check.
sealed class _Choice {
  const _Choice();
}

class _Start extends _Choice {
  const _Start(this.routineId, {this.lighter = false});

  final String routineId;
  final bool lighter;
}

class _Ask extends _Choice {
  const _Ask(this.question);

  final String question;
}

/// The check of [today]'s session in full: each muscle it works, your night
/// and your watch, against your usual - and what to do about it.
Future<void> showCheckSheet(
  BuildContext context,
  WidgetRef ref,
  TodayCheck today,
) async {
  final choice = await showAppSheet<_Choice>(
    context: context,
    title: 'Check voor ${today.lead.routineName}',
    builder: (context) => _CheckSheet(today: today),
  );
  if (!context.mounted) return;
  switch (choice) {
    case _Start(:final routineId, :final lighter):
      await startSession(context, ref, routineId: routineId, lighter: lighter);
    case _Ask(:final question):
      ref.read(coachDraftProvider.notifier).put(question);
      context.go(Routes.chat);
    case null:
      break;
  }
}

/// The question "Waarom?" puts ready for the coach - not sent: a question
/// is the user's to send.
String checkQuestion(TrainingCheck check) {
  final reasons = check.reasons.join(', ');
  return check.verdict == CheckVerdict.wait
      ? 'Waarom kan ${check.routineName} vandaag beter wachten? De check zegt: '
            '$reasons.'
      : 'De check voor ${check.routineName} zegt: $reasons. Wat betekent dat '
            'voor vandaag?';
}

class _CheckSheet extends ConsumerWidget {
  const _CheckSheet({required this.today});

  final TodayCheck today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final check = today.lead;
    final body = check.body;
    final verdict = check.verdict;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    void pick(_Choice choice) => Navigator.of(context).pop(choice);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );

    final instead = today.instead;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            switch (verdict) {
              CheckVerdict.ready => 'Klaar',
              CheckVerdict.note => 'Je kan gaan, met één sein',
              CheckVerdict.wait => 'Beter wachten',
            },
            style: theme.textTheme.titleSmall?.copyWith(
              color: checkColor(verdict),
            ),
          ),
          if (today.noneReady) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Geen sessie van deze week is vandaag klaar: een rustdag, of '
              'lichter.',
              style: muted,
            ),
          ],
          heading('Spieren in deze sessie'),
          if (check.muscles.isEmpty)
            Text(
              'Geen spier krijgt hier $kCheckMinSets werksets of meer.',
              style: muted,
            )
          else
            for (final muscle in check.muscles)
              _CheckRow(
                label: Formatters.muscle(muscle.muscle),
                detail: '${muscle.sets} sets',
                value: muscle.left == Duration.zero
                    ? 'hersteld'
                    : '${(muscle.progress * 100).round()}% · nog '
                          '${(muscle.left.inMinutes / 60).ceil()} u',
                colour: muscle.left == Duration.zero
                    ? AppColors.success
                    : muscle.holdsBack
                    ? AppColors.record
                    : null,
              ),
          heading('Jij, vannacht'),
          _CheckRow(
            label: 'Slaap',
            detail: switch (body.usualSleep) {
              final usual? => 'gewoonlijk ${checkHours(usual)}',
              null => null,
            },
            value: switch (body.slept) {
              final slept? => [
                checkHours(slept),
                if (body.score case final score?) 'score $score',
              ].join(' · '),
              null => 'geen nacht bekend',
            },
            colour: body.shortNight ? AppColors.record : null,
          ),
          if (body.hrvMs case final hrv?)
            _CheckRow(
              label: 'HRV',
              detail: 'gewoonlijk ${body.usualHrvMs!.round()}',
              value: '${hrv.round()} ms',
              colour: (body.hrvDrop ?? 0) > kHrvDropNoEffect
                  ? AppColors.record
                  : null,
            ),
          if (body.restingHr case final heart?)
            _CheckRow(
              label: 'Rusthartslag',
              detail: 'gewoonlijk ${body.usualRestingHr!.round()}',
              value: '${heart.round()}',
              colour: (body.restingHrRise ?? 0) > kRestingHrRiseNoEffect
                  ? AppColors.record
                  : null,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Een sein is een spier van deze sessie die nog meer dan '
            '${kCheckMuscleSlack.inHours} uur nodig heeft, een nacht korter '
            'dan ${kCheckShortNight.inHours} uur of met een score onder '
            '$kCheckLowScore, of een HRV of rusthartslag die van je gewone '
            'afwijkt. Eén sein: gewoon gaan. Twee of meer: beter wachten.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (instead != null) ...[
            FilledButton.icon(
              onPressed: () => pick(_Start(instead.routineId)),
              icon: const Icon(Icons.play_arrow),
              label: Text('Doe vandaag ${instead.routineName}'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (verdict == CheckVerdict.wait) ...[
            OutlinedButton.icon(
              onPressed: () => pick(_Start(check.routineId, lighter: true)),
              icon: const Icon(Icons.battery_3_bar),
              label: Text('${check.routineName}, lichter'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => pick(_Start(check.routineId)),
              icon: const Icon(Icons.play_arrow),
              label: Text('Toch ${check.routineName}'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => pick(_Start(check.routineId)),
              icon: const Icon(Icons.play_arrow),
              label: Text('Start ${check.routineName}'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => pick(_Start(check.routineId, lighter: true)),
              icon: const Icon(Icons.battery_3_bar),
              label: Text('${check.routineName}, lichter'),
            ),
          ],
          if (verdict != CheckVerdict.ready &&
              ref.watch(coachEnabledProvider)) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => pick(_Ask(checkQuestion(check))),
              icon: const Icon(Icons.smart_toy_outlined, size: 18),
              label: const Text('Waarom? Vraag de coach'),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the check: what, a word under it, and how it stands.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    this.detail,
    this.colour,
  });

  final String label;
  final String? detail;
  final String value;

  /// Green when it is fine, amber when it is a sign; plain otherwise.
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (detail case final detail?)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
