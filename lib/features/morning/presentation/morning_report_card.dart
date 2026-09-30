import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/morning_reporter.dart';
import 'morning_providers.dart';

/// Today's report at the top of the recovery screen, or the button that makes
/// one.
class MorningReportCard extends ConsumerWidget {
  const MorningReportCard({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moment = now ?? DateTime.now();
    final reports = ref.watch(morningReportsProvider).value ?? const [];
    final state = ref.watch(morningControllerProvider);
    final today = DateTime(moment.year, moment.month, moment.day);
    final report = reports.isNotEmpty && reports.first.facts.day == today
        ? reports.first
        : null;

    Widget makeButton(String label, {bool filled = false}) {
      final icon = state.busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome_outlined);
      void onPressed() =>
          ref.read(morningControllerProvider.notifier).makeNow();
      return filled
          ? FilledButton.icon(
              onPressed: state.busy ? null : onPressed,
              icon: icon,
              label: Text(label),
            )
          : TextButton.icon(
              onPressed: state.busy ? null : onPressed,
              icon: icon,
              label: Text(label),
            );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (report == null) ...[
              Text(
                'Nog geen rapport van vandaag',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Je nacht, je slaapscore en welke spiergroepen nog herstellen, '
                'in een paar zinnen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              makeButton('Rapport opstellen', filled: true),
            ] else ...[
              _ReportBody(report: report),
              Align(
                alignment: Alignment.centerRight,
                child: makeButton('Opnieuw opstellen'),
              ),
            ],
            if (state.error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: InfoBanner(
                  message: error,
                  icon: Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report});

  final MorningReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final facts = report.facts;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final coachOn = ref.watch(coachEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              facts.score == null ? '-' : '${facts.score}',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('slaapscore', style: theme.textTheme.labelMedium),
                    Text(
                      facts.night == null
                          ? 'geen nacht van vannacht'
                          : '${_length(facts.night!.length)} geslapen',
                      style: muted,
                    ),
                  ],
                ),
              ),
            ),
            Text('om ${Formatters.time(report.createdAt)}', style: muted),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _Pill(
              label: facts.recovering.isEmpty
                  ? 'niets in herstel'
                  : '${facts.recovering.length} in herstel',
              color: facts.recovering.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.tertiary,
            ),
            if (facts.ready.isNotEmpty)
              _Pill(
                label: '${facts.ready.length} klaar',
                color: theme.colorScheme.primary,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(report.text, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          report.coachText != null
              ? 'Geschreven door de coach, uit de cijfers van FitLog.'
              : report.coachError ??
                    (coachOn
                        ? 'Opgesteld door FitLog.'
                        : 'Opgesteld door FitLog. Met de AI-coach aan schrijft '
                              'de coach het in zijn woorden.'),
          style: muted,
        ),
        if (report.importError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error,
              style: muted?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

/// The earlier reports, folded away under the rest of the screen.
class EarlierReports extends ConsumerWidget {
  const EarlierReports({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moment = now ?? DateTime.now();
    final today = DateTime(moment.year, moment.month, moment.day);
    final earlier = [
      for (final report in ref.watch(morningReportsProvider).value ?? const [])
        if (report.facts.day != today) report,
    ];
    if (earlier.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          // No divider lines around the expansion: the card already frames it.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text('Eerdere rapporten'),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: [
              for (final report in earlier)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${Formatters.weekdayDayMonth(report.facts.day)}'
                        '${report.facts.score == null ? '' : '  ·  slaapscore ${report.facts.score}'}',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

String _length(Duration d) {
  final minutes = d.inMinutes.remainder(60);
  return minutes == 0 ? '${d.inHours} u' : '${d.inHours} u $minutes';
}
