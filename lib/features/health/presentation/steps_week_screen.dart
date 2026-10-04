import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/week_navigator.dart';
import 'health_providers.dart';

/// `8.432`: steps with the thousands apart, the Dutch way.
String formatSteps(int steps) =>
    NumberFormat.decimalPattern('nl').format(steps);

/// The steps of every day, a week at a time.
class StepsWeekScreen extends StatelessWidget {
  const StepsWeekScreen({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stappen')),
      body: WeekPager(
        now: now,
        builder: (context, start, end) =>
            _Steps(start: start, now: now ?? DateTime.now()),
      ),
    );
  }
}

class _Steps extends ConsumerWidget {
  const _Steps({required this.start, required this.now});

  final DateTime start;
  final DateTime now;

  static const _days = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(stepsInWeekProvider(start)).value;
    if (rows == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final byDay = <int, int>{
      for (final DailyVitalsRow row in rows)
        DateTime.fromMillisecondsSinceEpoch(row.day).weekday: ?row.steps,
    };
    final counted = byDay.values.toList();
    final total = counted.fold<int>(0, (sum, s) => sum + s);
    final best = counted.isEmpty ? 0 : counted.reduce((a, b) => a > b ? a : b);
    final today = DateTime(now.year, now.month, now.day);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        32,
      ),
      children: [
        StatRow(
          children: [
            StatTile(value: formatSteps(total), label: 'Deze week'),
            StatTile(
              value: counted.isEmpty
                  ? '-'
                  : formatSteps((total / counted.length).round()),
              label: 'Gemiddeld per dag',
            ),
            StatTile(
              value: counted.isEmpty ? '-' : formatSteps(best),
              label: 'Beste dag',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: counted.isEmpty
              ? Text(
                  'Geen stappen in deze week.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : SimpleBarChart(
                  height: 160,
                  values: [
                    for (var d = 1; d <= 7; d++) (byDay[d] ?? 0).toDouble(),
                  ],
                  labels: _days,
                  valueLabel: (v) => formatSteps(v.round()),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var d = 1; d <= 7; d++)
                if (DateTime(start.year, start.month, start.day + d - 1)
                    case final day when !day.isAfter(today))
                  ListTile(
                    dense: true,
                    title: Text(DateFormat('EEEE d MMMM', 'nl').format(day)),
                    trailing: Text(
                      byDay[d] == null ? '-' : formatSteps(byDay[d]!),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
