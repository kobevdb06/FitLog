import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc/recovery.dart';
import '../../../core/db/enums.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import 'recovery_providers.dart';
import 'recovery_view.dart';
import 'sleep_section.dart';

/// Herstel: how far each muscle is, and the place to say how it feels.
///
/// Everything else in the estimate is a reason to expect soreness. This
/// screen is where the user says whether there was any - the one thing the app
/// can observe rather than work out - so it asks for it next to the estimate
/// it changes, not tucked away in a setting.
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

    final recent = [
      for (final estimate in estimates)
        if (!estimate.isReadyAt(now) ||
            now.difference(estimate.trainedAt) < askFor)
          estimate,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Herstel')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: InfoBanner(
              icon: Icons.touch_app_outlined,
              message:
                  'Hoe voelen je spieren vandaag? Tik het per spiergroep aan. '
                  'Dat is het enige wat de app echt meet - de rest leidt ze af '
                  'uit je logboek - en na een paar keer leert ze hoe snel jij '
                  'herstelt.',
            ),
          ),
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
          else
            for (final estimate in recent)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: _MuscleCard(estimate: estimate, now: now),
              ),
          const SectionHeader('Slaap'),
          const SleepSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: RecoveryDisclaimer(),
          ),
        ],
      ),
    );
  }
}

/// One muscle: the estimate, why it says what it says, and the three answers.
class _MuscleCard extends ConsumerWidget {
  const _MuscleCard({required this.estimate, required this.now});

  final RecoveryEstimate estimate;
  final DateTime now;

  bool get _saidToday {
    final at = estimate.checkedAt;
    return at != null &&
        at.year == now.year &&
        at.month == now.month &&
        at.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = _saidToday ? estimate.check : null;
    final reasons = recoveryReasons(estimate, now: now);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecoveryRow(estimate: estimate, now: now),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                reasons.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final level in SorenessLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: today == level,
                  onSelected: (selected) {
                    final actions = ref.read(recoveryActionsProvider);
                    // Tapping the answer you already gave takes it back.
                    if (today == level) {
                      actions.unfeel(estimate.muscle);
                    } else {
                      actions.feel(estimate.muscle, level);
                    }
                  },
                ),
            ],
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

  if (estimate.sleepFactor > 1 && estimate.averageSleep != null) {
    reasons.add('korte nachten (${nightLength(estimate.averageSleep!)})');
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
          ? 'vandaag ${level.label.toLowerCase()}'
          : '${level.label.toLowerCase()} gezegd',
    );
  }
  return reasons;
}
