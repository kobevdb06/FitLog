import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/recovery.dart';
import '../../../core/calc/volume.dart';
import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/muscle_map.dart';
import '../../../routing/routes.dart';
import '../../progress/presentation/recovery_providers.dart';
import '../../progress/presentation/recovery_view.dart';
import 'workout_providers.dart';

part 'workout_summary_screen.g.dart';

@riverpod
Future<WorkoutDetail?> finishedWorkout(Ref ref, String workoutId) =>
    ref.watch(databaseProvider).workoutsDao.getWorkoutDetail(workoutId);

/// Share of the workout's volume per muscle group, used by the silhouette.
Map<String, double> muscleIntensity(WorkoutDetail detail) {
  final totals = <String, double>{};
  var overall = 0.0;

  for (final exercise in detail.exercises) {
    final volume = workoutVolumeKg(
      exercise.sets.map(
        (s) => SetVolumeInput(
          weightKg: s.weightKg,
          reps: s.reps,
          isCompleted: s.isCompleted,
          setType: SetType.fromWire(s.setType),
        ),
      ),
    );
    // Bodyweight work has no volume but still trains the muscle, so a
    // completed set is worth a nominal share.
    final weight = volume > 0
        ? volume
        : exercise.sets.where((s) => s.isCompleted).length * 10.0;
    if (weight <= 0) continue;

    totals.update(
      exercise.exercise.primaryMuscle,
      (v) => v + weight,
      ifAbsent: () => weight,
    );
    overall += weight;

    for (final secondary in decodeMuscleList(
      exercise.exercise.secondaryMuscles,
    )) {
      final share = weight * kSecondaryMuscleShare;
      totals.update(secondary, (v) => v + share, ifAbsent: () => share);
      overall += share;
    }
  }

  if (overall <= 0) return const {};
  final max = totals.values.reduce((a, b) => a > b ? a : b);
  return {for (final e in totals.entries) e.key: e.value / max};
}

/// What the user sees the moment they hit "Klaar".
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(finishedWorkoutProvider(workoutId));
    final records = ref.watch(workoutRecordsProvider(workoutId)).value ?? const [];
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Samenvatting'),
        actions: [
          TextButton(
            onPressed: () => context.go(Routes.dashboard),
            child: const Text('Sluiten'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (workout) {
          if (workout == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Workout niet gevonden',
              message: 'Deze sessie bestaat niet meer.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                workout.workout.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                Formatters.relativeDayTime(
                  DateTime.fromMillisecondsSinceEpoch(
                    workout.workout.startedAt,
                  ),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: Formatters.durationWords(
                        workout.workout.durationSeconds,
                      ),
                      label: 'Duur',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: formatters.volume(workout.workout.totalVolumeKg),
                      label: 'Volume',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: '${workout.workout.totalSets}',
                      label: 'Sets',
                    ),
                  ),
                ],
              ),
              if (records.isNotEmpty) ...[
                const SectionHeader(
                  'Nieuwe records',
                  padding: EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
                ),
                for (final record in records)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const PrBadge(),
                    title: Text(record.exercise.name),
                    subtitle: Text(record.type.label),
                    trailing: Text(
                      _recordValue(record, formatters),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.record,
                      ),
                    ),
                  ),
              ],
              const SectionHeader(
                'Getrainde spiergroepen',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.sm,
                ),
              ),
              AppCard(
                child: Column(
                  children: [
                    MuscleMap(intensityByMuscle: muscleIntensity(workout)),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final muscle
                            in muscleIntensity(workout).keys.toList()..sort())
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: CircleAvatar(
                              backgroundColor: AppColors.forMuscle(muscle),
                              radius: 6,
                            ),
                            label: Text(muscle),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader(
                'Hoe zwaar was het?',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xs,
                ),
              ),
              Text(
                'Het enige aan een sessie dat de app niet kan meten. Je '
                'antwoord verschuift de hersteltijd hieronder.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _EffortPicker(
                workoutId: workoutId,
                initial: PerceivedEffort.fromWire(
                  workout.workout.perceivedEffort,
                ),
              ),
              const SectionHeader(
                'Herstel',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.sm,
                ),
              ),
              _RecoveryCard(workoutId: workoutId),
              const SectionHeader(
                'Notitie',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.sm,
                ),
              ),
              _NotesField(
                workoutId: workoutId,
                initial: workout.workout.notes ?? '',
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => _saveAsRoutine(context, ref, workout),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Opslaan als routine'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  final text = await ref
                      .read(workoutControllerProvider)
                      .shareText(workoutId);
                  if (text.isEmpty) return;
                  await SharePlus.instance.share(
                    ShareParams(text: text, subject: workout.workout.name),
                  );
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Delen als tekst'),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }

  String _recordValue(RecordWithExercise record, Formatters formatters) {
    switch (record.type) {
      case PrType.maxReps:
        return '${record.record.value.round()} reps';
      case PrType.maxWeight:
      case PrType.est1rm:
        return formatters.weight(record.record.value);
      case PrType.maxSetVolume:
        return formatters.volume(record.record.value);
    }
  }

  Future<void> _saveAsRoutine(
    BuildContext context,
    WidgetRef ref,
    WorkoutDetail workout,
  ) async {
    final name = await promptForText(
      context,
      title: 'Opslaan als routine',
      initialValue: workout.workout.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(workoutControllerProvider)
        .saveAsRoutine(workoutId, name.trim());
    if (context.mounted) showSnack(context, 'Routine opgeslagen');
  }
}

class _NotesField extends ConsumerStatefulWidget {
  const _NotesField({required this.workoutId, required this.initial});

  final String workoutId;
  final String initial;

  @override
  ConsumerState<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends ConsumerState<_NotesField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Hoe voelde het?',
      ),
      onChanged: (value) => ref
          .read(databaseProvider)
          .workoutsDao
          .setWorkoutNotes(
            widget.workoutId,
            value.trim().isEmpty ? null : value.trim(),
          ),
    );
  }
}

/// The five-step rating, written straight through on every tap.
///
/// It keeps its own copy of the choice so the chips answer immediately; the
/// recovery card below re-reads the database on its own.
class _EffortPicker extends ConsumerStatefulWidget {
  const _EffortPicker({required this.workoutId, required this.initial});

  final String workoutId;
  final PerceivedEffort? initial;

  @override
  ConsumerState<_EffortPicker> createState() => _EffortPickerState();
}

class _EffortPickerState extends ConsumerState<_EffortPicker> {
  late PerceivedEffort? _choice = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final effort in PerceivedEffort.values)
          ChoiceChip(
            label: Text(effort.label),
            selected: _choice == effort,
            onSelected: (selected) {
              // Tapping the chosen one again clears it, back to unrated.
              final next = selected ? effort : null;
              setState(() => _choice = next);
              unawaited(
                ref.read(recoveryActionsProvider).rate(widget.workoutId, next),
              );
            },
          ),
      ],
    );
  }
}

/// The estimate for the muscles this session left behind.
class _RecoveryCard extends ConsumerWidget {
  const _RecoveryCard({required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(workoutRecoveryProvider(workoutId));
    if (estimates == null) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (estimates.isEmpty) {
      return const InfoBanner(
        icon: Icons.info_outline,
        message:
            'Deze sessie leverde geen belasting op waar een schatting op te '
            'baseren valt.',
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final estimate in estimates)
            RecoveryRow(estimate: estimate),
          const SizedBox(height: AppSpacing.sm),
          const RecoveryDisclaimer(),
        ],
      ),
    );
  }
}
