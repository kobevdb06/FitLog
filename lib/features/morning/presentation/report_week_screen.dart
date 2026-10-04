import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/week_navigator.dart';
import 'morning_providers.dart';
import 'morning_report_card.dart';

/// Every morning report, a week at a time, newest first.
class ReportWeekScreen extends StatelessWidget {
  const ReportWeekScreen({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapporten')),
      body: WeekPager(
        now: now,
        builder: (context, start, end) => _Reports(start: start),
      ),
    );
  }
}

class _Reports extends ConsumerWidget {
  const _Reports({required this.start});

  final DateTime start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reports = ref.watch(reportsInWeekProvider(start)).value;

    if (reports == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Geen rapporten in deze week.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        32,
      ),
      children: [
        for (final report in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(child: ReportBody(report: report, showDay: true)),
          ),
      ],
    );
  }
}
