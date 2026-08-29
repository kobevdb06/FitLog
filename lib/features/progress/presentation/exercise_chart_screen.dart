import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/common.dart';
import '../../exercises/presentation/exercise_library_screen.dart';
import '../../exercises/presentation/exercise_providers.dart';

/// Pick an exercise, then look at one metric over a chosen span.
class ExerciseChartScreen extends ConsumerStatefulWidget {
  const ExerciseChartScreen({super.key, this.exerciseId});

  final String? exerciseId;

  @override
  ConsumerState<ExerciseChartScreen> createState() =>
      _ExerciseChartScreenState();
}

class _ExerciseChartScreenState extends ConsumerState<ExerciseChartScreen> {
  String? _exerciseId;
  ExerciseMetric _metric = ExerciseMetric.oneRm;
  ChartRange _range = ChartRange.quarter;

  @override
  void initState() {
    super.initState();
    _exerciseId = widget.exerciseId;
  }

  Future<void> _pick() async {
    final picked = await ExerciseLibraryScreen.pick(
      context,
      single: true,
      title: 'Kies een oefening',
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _exerciseId = picked.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatters = ref.watch(formattersProvider);
    final exerciseId = _exerciseId;

    final ExerciseRow? exercise = exerciseId == null
        ? null
        : ref.watch(exerciseByIdProvider(exerciseId)).value;
    final sessions = exerciseId == null
        ? null
        : ref.watch(exerciseSessionsProvider(exerciseId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafiek per oefening'),
        actions: [
          if (exerciseId != null)
            IconButton(
              tooltip: 'Andere oefening',
              onPressed: _pick,
              icon: const Icon(Icons.swap_horiz),
            ),
        ],
      ),
      body: exerciseId == null
          ? EmptyState(
              icon: Icons.show_chart,
              title: 'Kies een oefening',
              message: 'Selecteer een oefening om haar verloop te zien.',
              actionLabel: 'Oefening kiezen',
              onAction: _pick,
            )
          : sessions == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  exercise?.name ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final metric in ExerciseMetric.values) ...[
                        ChoiceChip(
                          label: Text(metric.label),
                          selected: _metric == metric,
                          onSelected: (_) => setState(() => _metric = metric),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ChartRange>(
                  segments: [
                    for (final range in ChartRange.values)
                      ButtonSegment(value: range, label: Text(range.label)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: AppSpacing.xl),
                TrendLineChart(
                  points: buildExerciseSeries(
                    sessions: sessions,
                    metric: _metric,
                    range: _range,
                  ),
                  height: 260,
                  valueLabel: (value) => switch (_metric) {
                    ExerciseMetric.totalReps => value.round().toString(),
                    ExerciseMetric.volume => formatters.volume(value),
                    _ => formatters.weightValue(value),
                  },
                ),
              ],
            ),
    );
  }
}
