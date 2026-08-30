import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';
import 'history_providers.dart';
import 'history_screen.dart';

/// A finished session, with the sets still editable.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    final formatters = ref.watch(formattersProvider);
    final recordSetIds =
        ref.watch(workoutRecordSetIdsProvider(workoutId)).value ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.workout.name ?? 'Workout'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _onMenu(context, ref, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'repeat', child: Text('Opnieuw doen')),
              PopupMenuItem(value: 'rename', child: Text('Naam wijzigen')),
              PopupMenuItem(value: 'delete', child: Text('Verwijderen')),
            ],
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
              message: 'Deze sessie is verwijderd.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
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
              const SizedBox(height: AppSpacing.lg),
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
              if (workout.workout.notes != null &&
                  workout.workout.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                InfoBanner(
                  icon: Icons.sticky_note_2_outlined,
                  message: workout.workout.notes!,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              for (final exercise in workout.exercises)
                _ExerciseBlock(
                  workoutId: workoutId,
                  detail: exercise,
                  formatters: formatters,
                  recordSetIds: recordSetIds,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final actions = ref.read(historyActionsProvider);
    switch (value) {
      case 'repeat':
        await repeatWorkout(context, ref, workoutId);
      case 'rename':
        final name = await promptForText(
          context,
          title: 'Naam van de workout',
          initialValue: ref.read(workoutDetailProvider(workoutId)).value
              ?.workout
              .name,
        );
        if (name != null && name.trim().isNotEmpty) {
          await actions.rename(workoutId, name.trim());
        }
      case 'delete':
        final workout = ref.read(workoutDetailProvider(workoutId)).value;
        if (workout == null) return;
        if (!await confirmWorkoutDeletion(context)) return;
        if (!context.mounted) return;
        // Leave first, then schedule: the snackbar lives at app level, so the
        // undo stays reachable from the list we land on.
        context.pop();
        deleteWorkoutWithUndo(context, ref, workout.workout);
    }
  }
}

class _ExerciseBlock extends ConsumerWidget {
  const _ExerciseBlock({
    required this.workoutId,
    required this.detail,
    required this.formatters,
    required this.recordSetIds,
  });

  final String workoutId;
  final WorkoutExerciseDetail detail;
  final Formatters formatters;
  final Set<String> recordSetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actions = ref.read(historyActionsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  context.push(Routes.exerciseDetail(detail.exercise.id)),
              child: Row(
                children: [
                  ExerciseAvatar(exercise: detail.exercise, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      detail.exercise.name,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (detail.workoutExercise.notes != null &&
                detail.workoutExercise.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.workoutExercise.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < detail.sets.length; i++)
              _EditableSetRow(
                row: detail.sets[i],
                number: i + 1,
                formatters: formatters,
                isRecord: recordSetIds.contains(detail.sets[i].id),
                onEdit: () => _editSet(context, actions, detail.sets[i]),
                onDelete: () async {
                  final ok = await confirm(
                    context,
                    title: 'Set verwijderen?',
                    message:
                        'Het volume en je records worden opnieuw berekend.',
                    confirmLabel: 'Verwijderen',
                    destructive: true,
                  );
                  if (ok) {
                    await actions.deleteSet(workoutId, detail.sets[i].id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSet(
    BuildContext context,
    HistoryActions actions,
    WorkoutSetRow row,
  ) async {
    final weight = await showKeypadSheet(
      context: context,
      kind: KeypadFieldKind.weight,
      initialValue: KeypadValue.fromNumber(
        row.weightKg == null ? null : formatters.toDisplayWeight(row.weightKg!),
      ),
      unitLabel: formatters.weightUnitLabel,
      title: 'Gewicht',
    );
    if (weight == null || !context.mounted) return;

    final reps = await showKeypadSheet(
      context: context,
      kind: KeypadFieldKind.reps,
      initialValue: KeypadValue.fromNumber(row.reps, decimals: 0),
      title: 'Reps',
    );
    if (reps == null) return;

    await actions.updateSet(
      workoutId,
      row.id,
      weightKg: weight.number == null
          ? null
          : formatters.fromDisplayWeight(weight.number!),
      reps: reps.intValue,
    );
  }
}

class _EditableSetRow extends StatelessWidget {
  const _EditableSetRow({
    required this.row,
    required this.number,
    required this.formatters,
    required this.isRecord,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutSetRow row;
  final int number;
  final Formatters formatters;
  final bool isRecord;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setType = SetType.fromWire(row.setType);

    return InkWell(
      onTap: onEdit,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                setType.marker ?? '$number',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: setType == SetType.warmup
                      ? AppColors.record
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                formatters.setSummary(
                  weightKg: row.weightKg,
                  reps: row.reps,
                  durationSeconds: row.durationSeconds,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: row.isCompleted
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isRecord) const PrBadge(compact: true),
            if (!row.isCompleted)
              Text(
                'niet afgevinkt',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
