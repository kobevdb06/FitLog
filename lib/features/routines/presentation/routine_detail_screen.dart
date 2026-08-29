import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';
import 'routine_providers.dart';

/// One routine with its planned sets, and the button that turns it into a
/// running session.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({super.key, required this.routineId});

  final String routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(routineDetailProvider(routineId));
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.routine.name ?? 'Routine'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _onMenu(context, ref, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Bewerken')),
              PopupMenuItem(value: 'duplicate', child: Text('Dupliceren')),
              PopupMenuItem(value: 'delete', child: Text('Verwijderen')),
            ],
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (routine) {
          if (routine == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Routine niet gevonden',
              message: 'Deze routine bestaat niet meer.',
            );
          }
          if (routine.exercises.isEmpty) {
            return EmptyState(
              icon: Icons.playlist_add,
              title: 'Nog geen oefeningen',
              message: 'Voeg oefeningen toe voordat je deze routine start.',
              actionLabel: 'Routine bewerken',
              onAction: () => context.push(Routes.routineEdit(routineId)),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              if (routine.routine.notes != null &&
                  routine.routine.notes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: InfoBanner(
                    icon: Icons.sticky_note_2_outlined,
                    message: routine.routine.notes!,
                  ),
                ),
              for (final exercise in routine.exercises)
                _ExerciseBlock(detail: exercise, formatters: formatters),
            ],
          );
        },
      ),
      floatingActionButton: detail.value == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _start(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
            ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final active = ref.read(activeWorkoutProvider).value;
    if (active != null) {
      final resume = await confirm(
        context,
        title: 'Er loopt al een workout',
        message:
            'Je kunt maar een sessie tegelijk loggen. Ga verder met '
            '"${active.workout.name}" of rond die eerst af.',
        confirmLabel: 'Ga verder',
      );
      if (resume && context.mounted) context.push(Routes.workout);
      return;
    }

    await ref.read(workoutControllerProvider).startFromRoutine(routineId);
    if (context.mounted) context.push(Routes.workout);
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final actions = ref.read(routineActionsProvider);
    switch (value) {
      case 'edit':
        context.push(Routes.routineEdit(routineId));
      case 'duplicate':
        final id = await actions.duplicate(routineId);
        if (context.mounted) {
          showSnack(context, 'Kopie gemaakt');
          context.pushReplacement(Routes.routineDetail(id));
        }
      case 'delete':
        final ok = await confirm(
          context,
          title: 'Routine verwijderen?',
          message:
              'De routine verdwijnt. Workouts die je er al mee logde blijven '
              'in je geschiedenis staan.',
          confirmLabel: 'Verwijderen',
          destructive: true,
        );
        if (!ok) return;
        await actions.delete(routineId);
        if (context.mounted) context.pop();
    }
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.detail, required this.formatters});

  final RoutineExerciseDetail detail;
  final Formatters formatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = detail.routineExercise.supersetGroup;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: AppCard(
        onTap: () => context.push(Routes.exerciseDetail(detail.exercise.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MuscleAvatar(muscle: detail.exercise.primaryMuscle, size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.exercise.name,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        [
                          '${detail.sets.length} sets',
                          if (detail.routineExercise.restSeconds != null)
                            '${detail.routineExercise.restSeconds}s rust',
                          if (group != null)
                            'superset ${String.fromCharCode(65 + group)}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (detail.routineExercise.notes != null &&
                detail.routineExercise.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail.routineExercise.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < detail.sets.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        SetType.fromWire(detail.sets[i].setType).marker ??
                            '${i + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      formatters.setSummary(
                        weightKg: detail.sets[i].targetWeightKg,
                        reps: detail.sets[i].targetReps,
                        durationSeconds:
                            detail.sets[i].targetDurationSeconds,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
