import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc/recovery.dart';
import '../../../core/db/enums.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/providers/core_providers.dart';
import '../../morning/presentation/morning_report_card.dart';
import '../../readiness/presentation/check_providers.dart';
import '../../readiness/presentation/check_sheet.dart';
import 'alcohol_section.dart';
import 'recovery_providers.dart';
import 'recovery_view.dart';
import 'sleep_section.dart';

/// Herstel: today. Whether the next session can go and this morning's
/// report, last night in a line, and how far each muscle is - a tap on one
/// says how it feels.
///
/// Gezondheid is the other half: the last 30 days. A night is said once
/// here, its trend there. What this screen is and how far to trust it is
/// behind the i in the bar, not in front of everything every time.
class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  /// A muscle is worth asking about for as long as any session could still
  /// be keeping it busy.
  static const Duration askFor = Duration(hours: 96);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estimates = ref.watch(recoveryEstimatesProvider).value ?? const [];
    final now = DateTime.now();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final recent = [
      for (final estimate in estimates)
        if (!estimate.isReadyAt(now) ||
            now.difference(estimate.trainedAt) < askFor)
          estimate,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herstel'),
        actions: [
          IconButton(
            tooltip: 'Over Herstel',
            onPressed: () => _about(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 32),
        children: [
          const MorningReportCard(leading: _NextSession()),
          const SizedBox(height: AppSpacing.md),
          const SleepSection(),
          const SectionHeader('Per spiergroep'),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                estimates.isEmpty
                    ? 'Nog niets om te herstellen. Na je eerste workout staat '
                          'hier per spiergroep hoe ver je bent.'
                    : 'Alles hersteld volgens je logboek.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    for (final (i, estimate) in recent.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      _MuscleRow(estimate: estimate, now: now),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                'Tik op een spier om te zeggen hoe ze voelt.',
                style: muted,
              ),
            ),
          ],
          // Only for whoever asked for it: a drinks counter is not something
          // to put in front of everyone who opens a training log.
          if (ref.watch(settingsProvider).value?.trackAlcohol ?? false) ...[
            const SectionHeader('Alcohol'),
            const AlcoholSection(),
          ],
        ],
      ),
    );
  }

  /// What Herstel is, and how far to trust it: said once, on request.
  Future<void> _about(BuildContext context) => showAppSheet<void>(
    context: context,
    title: 'Over Herstel',
    builder: (context) => const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoe lang elke spiergroep nog nodig heeft, leidt FitLog af uit je '
            'logboek: hoe zwaar een sessie was tegenover wat je gewoon bent, '
            'en hoe je ze beoordeelde. Hoe je spieren voelen, is het enige '
            'wat het echt meet: tik op een spier om het te zeggen, en na een '
            'paar keer leert het hoe snel jij herstelt.',
          ),
          SizedBox(height: AppSpacing.md),
          RecoveryDisclaimer(),
        ],
      ),
    ),
  );
}

/// The check of the session Vandaag leads with, at the top of the day's
/// card: the answer to "can I train today". Nothing when there is nothing
/// to check.
class _NextSession extends ConsumerWidget {
  const _NextSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final check = ref.watch(todayCheckProvider);
    if (check == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOLGENDE SESSIE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(check.lead.routineName, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        CheckLine(
          check: check.lead,
          onTap: () => showCheckSheet(context, ref, check),
        ),
        const Divider(height: AppSpacing.xl),
      ],
    );
  }
}

/// What you said about [estimate]'s muscle today, if anything.
SorenessLevel? _saidToday(RecoveryEstimate estimate, DateTime now) {
  final at = estimate.checkedAt;
  return at != null &&
          at.year == now.year &&
          at.month == now.month &&
          at.day == now.day
      ? estimate.check
      : null;
}

/// One muscle in a line: how far, how long still, and what you said about
/// it today. A tap opens the rest.
class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.estimate, required this.now});

  final RecoveryEstimate estimate;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final said = _saidToday(estimate, now);
    return InkWell(
      onTap: () => _showMuscle(context, estimate.muscle),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecoveryRow(estimate: estimate, now: now),
            if (said != null)
              Text(
                'vandaag ${said.label.toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.forMuscle(estimate.muscle)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One muscle in full: why the estimate is what it is, and how it feels.
Future<void> _showMuscle(BuildContext context, String muscle) =>
    showAppSheet<void>(
      context: context,
      title: Formatters.muscle(muscle),
      builder: (context) => _MuscleSheet(muscle: muscle),
    );

class _MuscleSheet extends ConsumerWidget {
  const _MuscleSheet({required this.muscle});

  final String muscle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    RecoveryEstimate? estimate;
    for (final e in ref.watch(recoveryEstimatesProvider).value ?? const []) {
      if (e.muscle == muscle) estimate = e;
    }
    final found = estimate;
    if (found == null) return const SizedBox.shrink();
    final said = _saidToday(found, now);
    final reasons = recoveryReasons(found, now: now);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The name is the sheet's title: here only how far, and how long.
          Text(
            [
              if (found.isReadyAt(now))
                'klaar'
              else
                Formatters.remainingWords(found.remainingAt(now)),
              '${(found.progressAt(now) * 100).round()}% hersteld',
            ].join(' · '),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: found.progressAt(now),
              minHeight: 4,
              backgroundColor: AppColors.forMuscle(muscle)
                  .withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(AppColors.forMuscle(muscle)),
            ),
          ),
          if (found.provisional)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Nog te weinig sessies voor deze spiergroep om met je eigen '
                'gemiddelde te vergelijken.',
                style: muted,
              ),
            ),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(reasons.join(' · '), style: muted),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Hoe voelt ze vandaag?', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final level in SorenessLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: said == level,
                  onSelected: (_) {
                    final actions = ref.read(recoveryActionsProvider);
                    // Tapping the answer you already gave takes it back.
                    if (said == level) {
                      actions.unfeel(muscle);
                    } else {
                      actions.feel(muscle, level);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Wat je voelt, is het enige wat FitLog echt meet. Na een paar '
            'keer leert het hoe snel jij herstelt.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// Why an estimate is longer or shorter than the plain table would say, in
/// the words the screen shows under it.
///
/// Only what actually moved it: an estimate that is simply the table gets no
/// explanation, because there is nothing to explain.
List<String> recoveryReasons(RecoveryEstimate estimate, {DateTime? now}) {
  final reasons = <String>[];

  final carried = estimate.carryover.inHours;
  if (carried > 0) reasons.add('+$carried u van je vorige sessie');

  if (estimate.alcoholFactor > 1) {
    reasons.add(
      'alcohol op je trainingsdag '
      '(${estimate.drinks == 1 ? '1 glas' : '${estimate.drinks} glazen'})',
    );
  }

  // Short nights and a watch's bad morning count once, as the larger of the
  // two; the screen names the one that counted.
  final byVitals = estimate.vitalsFactor > estimate.sleepFactor;
  if (!byVitals && estimate.sleepFactor > 1 && estimate.averageSleep != null) {
    reasons.add('korte nachten (${nightLength(estimate.averageSleep!)})');
  }
  if (byVitals && estimate.vitalsFactor > 1) {
    final drop = estimate.hrvDrop;
    if (drop != null && drop > kHrvDropNoEffect) {
      reasons.add('HRV ${(drop * 100).round()}% onder je gewone');
    }
    final rise = estimate.restingHrRise;
    if (rise != null && rise > kRestingHrRiseNoEffect) {
      reasons.add('rusthartslag ${rise.round()} slagen hoger');
    }
  }

  if (estimate.cardio case final run?) {
    final moment = now ?? DateTime.now();
    final days = DateTime(
      moment.year,
      moment.month,
      moment.day,
    ).difference(DateTime(run.end.year, run.end.month, run.end.day)).inDays;
    final when = days == 0
        ? 'vandaag'
        : days < 7
        ? Formatters.weekday(run.end)
        : Formatters.dayMonth(run.end);
    reasons.add(
      'je ${run.kind.label} van $when (${run.duration.inMinutes} min)',
    );
  }

  final factor = estimate.personalFactor;
  if (factor > 1.05) {
    reasons.add('jij herstelt hier trager dan gemiddeld');
  } else if (factor < 0.95) {
    reasons.add('jij herstelt hier sneller dan gemiddeld');
  }

  if (estimate.check case final level?) {
    final at = estimate.checkedAt!;
    final moment = now ?? DateTime.now();
    final sameDay =
        at.year == moment.year &&
        at.month == moment.month &&
        at.day == moment.day;
    reasons.add(
      sameDay
          ? 'vandaag ${level.label.toLowerCase()} aangeduid'
          : 'heeft ${level.label.toLowerCase()} aangeduid',
    );
  }
  return reasons;
}
