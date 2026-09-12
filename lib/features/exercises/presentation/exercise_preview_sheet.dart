/// A quick look at an exercise, without leaving what you were doing.
///
/// Meant for the moment you are building a routine and cannot remember which
/// row is which: the picture moving, the muscles it works, and how it is done.
/// Deliberately not the exercise page - no records, no charts, no history. You
/// are picking, not studying, and anything more would be another screen to
/// come back from.
library;

import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/paths.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/exercise_image.dart';
import 'exercise_providers.dart';

Future<void> showExercisePreview(
  BuildContext context, {
  required ExerciseRow exercise,
  required ExerciseImageManifest? manifest,
  required AppPaths? paths,
  VoidCallback? onOpenFull,
}) {
  return showAppSheet<void>(
    context: context,
    title: exercise.name,
    builder: (context) => _Preview(
      exercise: exercise,
      manifest: manifest,
      paths: paths,
      onOpenFull: onOpenFull,
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.exercise,
    required this.manifest,
    required this.paths,
    this.onOpenFull,
  });

  final ExerciseRow exercise;
  final ExerciseImageManifest? manifest;
  final AppPaths? paths;

  /// Offered where the full exercise page is still worth reaching - during a
  /// workout, say. Left off in the picker, where leaving the list would lose
  /// what you had selected.
  final VoidCallback? onOpenFull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = ExerciseCategory.fromWire(exercise.category);
    final instructions = exercise.instructions?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ExerciseAnimation(
              exercise: exercise,
              manifest: manifest,
              paths: paths,
              height: 180,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            [
              category.label,
              if (exercise.equipment != null) exercise.equipment!,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MuscleChip(muscle: exercise.primaryMuscle, primary: true),
              for (final muscle in decodeSecondaryMuscles(
                exercise.secondaryMuscles,
              ))
                _MuscleChip(muscle: muscle, primary: false),
            ],
          ),
          if (instructions != null && instructions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Uitvoering', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(instructions, style: theme.textTheme.bodyMedium),
          ],
          if (onOpenFull != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenFull!();
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Records en grafieken'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.muscle, required this.primary});

  final String muscle;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: CircleAvatar(
        backgroundColor: AppColors.forMuscle(muscle),
        radius: 6,
      ),
      label: Text(primary ? '$muscle (primair)' : muscle),
    );
  }
}
