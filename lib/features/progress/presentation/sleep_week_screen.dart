import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/week_navigator.dart';
import 'recovery_providers.dart';
import 'sleep_section.dart';
import 'sleep_stages_bar.dart';

/// Every night, a week at a time: when, how long, the score, the stages and
/// where it came from - and the way to correct one.
class SleepWeekScreen extends StatelessWidget {
  const SleepWeekScreen({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slaap')),
      body: WeekPager(
        now: now,
        builder: (context, start, end) => _Nights(start: start),
      ),
    );
  }
}

class _Nights extends ConsumerWidget {
  const _Nights({required this.start});

  final DateTime start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nights = ref.watch(nightsInWeekProvider(start)).value;
    final vitals = ref.watch(vitalsForWeekProvider(start)).value ?? const [];

    if (nights == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (nights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Geen nachten in deze week.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final minutes = nights.fold<int>(
      0,
      (sum, n) => sum + (n.wokeAt - n.fellAsleepAt) ~/ 60000,
    );
    final scores = [for (final n in nights) nightScore(n, vitals).value];

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
              value: stageLength(minutes ~/ nights.length),
              label: 'Gemiddeld per nacht',
            ),
            StatTile(
              value:
                  '${(scores.reduce((a, b) => a + b) / scores.length).round()}',
              label: 'Gemiddelde slaapscore',
            ),
            StatTile(
              value: '${nights.length}',
              label: nights.length == 1 ? 'Nacht' : 'Nachten',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final night in nights)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NightRow(
                    row: night,
                    score: nightScore(night, vitals),
                    showStages: false,
                    onTap: () => editNight(
                      context,
                      ref,
                      wakeDay: DateTime.fromMillisecondsSinceEpoch(
                        night.wokeAt,
                      ),
                      existing: night,
                    ),
                  ),
                  if (SleepStagesBar.hasStages(
                    light: night.lightMinutes,
                    rem: night.remMinutes,
                    deep: night.deepMinutes,
                  )) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SleepStagesBar(
                      length: Duration(
                        milliseconds: night.wokeAt - night.fellAsleepAt,
                      ),
                      light: night.lightMinutes,
                      rem: night.remMinutes,
                      deep: night.deepMinutes,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
