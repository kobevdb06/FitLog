import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/week_navigator.dart';
import 'health_providers.dart';
import 'workout_heart_row.dart';

/// Every session, a week at a time, with the heart rate a watch measured
/// during it.
class HeartRateWeekScreen extends StatelessWidget {
  const HeartRateWeekScreen({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hartslag tijdens trainingen')),
      body: WeekPager(
        now: now,
        builder: (context, start, end) => _Workouts(start: start),
      ),
    );
  }
}

class _Workouts extends ConsumerWidget {
  const _Workouts({required this.start});

  final DateTime start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workouts = ref.watch(workoutsInWeekProvider(start)).value;

    if (workouts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (workouts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Geen trainingen in deze week.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final measured = [
      for (final w in workouts)
        if (w.avgHeartRate != null) w,
    ];

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
            StatTile(
              value: measured.isEmpty
                  ? '-'
                  : '${(measured.fold<int>(0, (sum, w) => sum + w.avgHeartRate!) / measured.length).round()} bpm',
              label: 'Gemiddelde hartslag',
            ),
            StatTile(
              value: measured.isEmpty
                  ? '-'
                  : '${measured.map((w) => w.maxHeartRate ?? w.avgHeartRate!).reduce((a, b) => a > b ? a : b)} bpm',
              label: 'Hoogste',
            ),
            StatTile(
              value: '${workouts.length}',
              label: workouts.length == 1 ? 'Training' : 'Trainingen',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final workout in workouts) WorkoutHeartRow(workout: workout),
            ],
          ),
        ),
      ],
    );
  }
}
