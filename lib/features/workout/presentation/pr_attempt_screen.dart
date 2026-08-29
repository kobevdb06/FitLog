import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc/plates.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../domain/pr_ramp.dart';
import 'pr_attempt_providers.dart';

/// Setting up a one-rep-max attempt.
///
/// Everything on this screen feeds the ladder underneath it, and the ladder is
/// rebuilt on every change so what you see is what you will lift.
class PrAttemptScreen extends ConsumerStatefulWidget {
  const PrAttemptScreen({
    super.key,
    required this.exercise,
    this.workoutExerciseId,
  });

  /// Opens the configuration and returns true when an attempt was started.
  static Future<bool> open(
    BuildContext context, {
    required ExerciseRow exercise,
    String? workoutExerciseId,
  }) async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PrAttemptScreen(
          exercise: exercise,
          workoutExerciseId: workoutExerciseId,
        ),
      ),
    );
    return started ?? false;
  }

  final ExerciseRow exercise;

  /// Set when converting an exercise that is already in the session.
  final String? workoutExerciseId;

  @override
  ConsumerState<PrAttemptScreen> createState() => _PrAttemptScreenState();
}

class _PrAttemptScreenState extends ConsumerState<PrAttemptScreen> {
  PrAttemptConfig? _config;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final settings = ref.watch(settingsProvider).value;
    final setup = ref.watch(barbellSetupProvider);
    final baseline = ref.watch(prBaselineProvider(widget.exercise.id)).value;

    if (settings == null || baseline == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PR-poging')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final config =
        _config ??= initialPrConfig(
          baseline: baseline,
          settings: settings,
          setup: setup,
        );
    final ramp = config.ramp;

    return Scaffold(
      appBar: AppBar(title: const Text('PR-poging')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(widget.exercise.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),

          _TargetField(
            config: config,
            formatters: formatters,
            onChanged: (value) => setState(
              () => _config = config.copyWith(targetKg: value),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _BaselineLine(baseline: baseline, formatters: formatters),

          if (baseline.hasEstimate &&
              jumpOverEstimate(
                    targetKg: config.targetKg,
                    estimatedOneRmKg: baseline.estimatedOneRmKg!,
                  ) >
                  kBigJumpThreshold) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              icon: Icons.trending_up,
              color: AppColors.record,
              message:
                  'Dat is ${((config.targetKg / baseline.estimatedOneRmKg! - 1) * 100).round()}% '
                  'boven je geschatte 1RM. Een grote sprong; kleiner mikken '
                  'lukt vaker.',
            ),
          ],

          if (baseline.trainedRecently) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              icon: Icons.history,
              message:
                  'Je deed deze oefening in de laatste 48 uur nog '
                  '${formatters.volume(baseline.recentVolumeKg)} aan volume. '
                  'Vermoeidheid speelt mee in wat er vandaag uit komt.',
            ),
          ],

          const SectionHeader(
            'Opbouw',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
          ),
          _Stepper(
            label: 'Opwarmsets',
            value: config.warmupSets,
            min: kMinPrWarmupSets,
            max: kMaxPrWarmupSets,
            onChanged: (value) => setState(
              () => _config = config.copyWith(warmupSets: value),
            ),
          ),
          _Stepper(
            label: 'Extra pogingen bij succes',
            value: config.extraAttempts,
            min: 0,
            max: 3,
            onChanged: (value) => setState(
              () => _config = config.copyWith(extraAttempts: value),
            ),
          ),

          const SectionHeader(
            'Stang en schijven',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gewicht van de stang'),
            subtitle: const Text('Alleen voor deze poging'),
            trailing: Text(
              formatters.weight(config.barKg),
              style: theme.textTheme.titleSmall,
            ),
            onTap: () async {
              final result = await showKeypadSheet(
                context: context,
                kind: KeypadFieldKind.weight,
                initialValue: KeypadValue.fromNumber(
                  formatters.toDisplayWeight(config.barKg),
                ),
                unitLabel: formatters.weightUnitLabel,
                title: 'Gewicht van de stang',
              );
              final value = result?.number;
              if (value == null) return;
              setState(
                () => _config = config.copyWith(
                  barKg: formatters.fromDisplayWeight(value),
                ),
              );
            },
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final plate in kDefaultPlatesKg)
                FilterChip(
                  label: Text(formatters.weight(plate)),
                  selected: config.platesKg.contains(plate),
                  onSelected: (selected) {
                    final next = [...config.platesKg];
                    selected ? next.add(plate) : next.remove(plate);
                    if (next.isEmpty) return;
                    setState(
                      () => _config = config.copyWith(platesKg: next),
                    );
                  },
                ),
            ],
          ),

          const SectionHeader(
            'Zo ziet je poging eruit',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
          ),
          if (ramp == null)
            const InfoBanner(
              icon: Icons.error_outline,
              color: AppColors.danger,
              message:
                  'Dit doelgewicht ligt onder het gewicht van de lege stang. '
                  'Kies iets zwaarders.',
            )
          else
            PrRampPreview(ramp: ramp, formatters: formatters),

          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: ramp == null || _busy ? null : () => _start(ramp),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              ramp == null
                  ? 'Kies een haalbaar doel'
                  : 'Start poging op ${formatters.weight(ramp.achievedTargetKg)}',
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _start(PrRamp ramp) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(prAttemptActionsProvider)
          .start(
            exerciseId: widget.exercise.id,
            config: _config!,
            existingWorkoutExerciseId: widget.workoutExerciseId,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Poging starten mislukte: $error', isError: true);
      }
    }
  }
}

class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.config,
    required this.formatters,
    required this.onChanged,
  });

  final PrAttemptConfig config;
  final Formatters formatters;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await showKeypadSheet(
          context: context,
          kind: KeypadFieldKind.weight,
          initialValue: KeypadValue.fromNumber(
            formatters.toDisplayWeight(config.targetKg),
          ),
          unitLabel: formatters.weightUnitLabel,
          title: 'Doelgewicht',
        );
        final value = result?.number;
        if (value != null) onChanged(formatters.fromDisplayWeight(value));
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Doelgewicht'),
        child: Text(
          formatters.weight(config.targetKg),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}

class _BaselineLine extends StatelessWidget {
  const _BaselineLine({required this.baseline, required this.formatters});

  final PrBaseline baseline;
  final Formatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!baseline.hasEstimate) {
      return Text(
        'Je hebt deze oefening nog niet gelogd, dus er is geen schatting om '
        'op te bouwen. Mik voorzichtig.',
        style: style,
      );
    }

    return Text(
      'Je geschatte 1RM is ${formatters.weight(baseline.estimatedOneRmKg!)} '
      '(Epley, uit ${formatters.weight(baseline.sourceWeightKg!)} × '
      '${baseline.sourceReps} op '
      '${Formatters.dayMonth(baseline.sourceDate!)})',
      style: style,
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

/// The live preview of the ladder, with the plates for each rung.
class PrRampPreview extends StatelessWidget {
  const PrRampPreview({
    super.key,
    required this.ramp,
    required this.formatters,
  });

  final PrRamp ramp;
  final Formatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          for (var i = 0; i < ramp.sets.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      ramp.sets[i].isAttempt ? 'PR' : 'W${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ramp.sets[i].isAttempt
                            ? AppColors.record
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${(ramp.sets[i].percentage * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatters.weight(ramp.sets[i].weightKg)} × '
                          '${ramp.sets[i].reps}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: ramp.sets[i].isAttempt
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        Text(
                          _platesLabel(ramp.sets[i].plates, formatters),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${ramp.sets[i].restSeconds}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _platesLabel(PlateSolution solution, Formatters formatters) {
    if (solution.perSide.isEmpty) return 'lege stang';
    final parts = solution.perSide
        .map(
          (stack) =>
              '${stack.count}× ${formatters.weightValue(stack.weightKg)}',
        )
        .join(' + ');
    return 'per zijde: $parts';
  }
}
