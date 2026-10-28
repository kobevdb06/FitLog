import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../readiness/domain/training_check.dart';
import '../../readiness/presentation/check_sheet.dart';
import '../data/morning_reporter.dart';
import 'morning_providers.dart';

/// Today's report at the top of the recovery screen, or the button that makes
/// one - in words: the night and its score have their own line on Herstel,
/// and are not said twice.
class MorningReportCard extends ConsumerWidget {
  const MorningReportCard({super.key, this.now, this.leading});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  /// What stands above the report in the same card: on Herstel, the check
  /// of the next session.
  final Widget? leading;

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

    // Every report is on its own screen, a week at a time: this card stays
    // one report long however many mornings there have been.
    final earlier = MoreLink(
      'Alle rapporten',
      onTap: () => context.push(Routes.reportWeeks),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?leading,
            // A line and a button: on Herstel the check above it is what
            // the day is about, and a big button under a title outshouted it.
            if (report == null) ...[
              Text(
                'Nog geen rapport van vandaag',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  makeButton('Rapport opstellen'),
                  if (reports.isNotEmpty) earlier,
                ],
              ),
            ] else ...[
              _TodayReport(report: report),
              // Side by side where they fit, the one under the other where
              // they do not: on a narrow phone with large text the row ran
              // off the screen.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [makeButton('Opnieuw opstellen'), earlier],
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

/// One report: the score, the night, the pills, the words, and who wrote
/// them.
class ReportBody extends ConsumerWidget {
  const ReportBody({super.key, required this.report, this.showDay = false});

  final MorningReport report;

  /// Whether the day is named with the time - on the screen that lists a
  /// whole week of them.
  final bool showDay;

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
            Text(
              showDay
                  ? '${Formatters.weekdayDayMonth(report.createdAt)}\n'
                        'om ${Formatters.time(report.createdAt)}'
                  : 'om ${Formatters.time(report.createdAt)}',
              textAlign: TextAlign.end,
              style: muted,
            ),
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
            if (facts.check case final check?)
              _Pill(
                label: switch (check.verdict) {
                  CheckVerdict.ready => '${check.session}: klaar',
                  CheckVerdict.note => '${check.session}: let op',
                  CheckVerdict.wait => '${check.session}: beter wachten',
                },
                color: checkColor(check.verdict),
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

/// Today's report on Herstel: what it says, and who wrote it when.
class _TodayReport extends ConsumerWidget {
  const _TodayReport({required this.report});

  final MorningReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(report.text, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ochtendrapport om ${Formatters.time(report.createdAt)} · '
          '${report.coachText != null ? 'door de coach' : 'door FitLog'}',
          style: muted,
        ),
        if (report.coachError case final error?) Text(error, style: muted),
        if (report.importError case final error?)
          Text(error, style: muted?.copyWith(color: theme.colorScheme.error)),
      ],
    );
  }
}
