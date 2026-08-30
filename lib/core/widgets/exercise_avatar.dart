import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/core_providers.dart';
import 'exercise_image.dart';

/// The list thumbnail for the screens that show a handful of exercises.
///
/// [ExerciseThumb] wants the manifest handed to it, which is right for the
/// catalogue: one watch at the top of a list that can run to hundreds of rows.
/// Everywhere else the rows are few, and threading the manifest down through
/// three widgets to reach them was enough friction that nobody did - which is
/// how a routine, a finished workout and the record list all ended up showing
/// the coloured fallback badge while the catalogue showed the illustration.
///
/// This reads the manifest itself so the call site only needs the exercise.
class ExerciseAvatar extends ConsumerWidget {
  const ExerciseAvatar({super.key, required this.exercise, this.size = 40});

  final ExerciseRow exercise;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ExerciseThumb(
    exercise: exercise,
    manifest: ref.watch(exerciseImagesProvider).value,
    size: size,
  );
}
