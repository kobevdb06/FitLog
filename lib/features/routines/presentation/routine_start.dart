import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';

/// Starts a session - the routine's, or an empty one without [routineId] -
/// and steps into it. With one already running it offers to go back to that
/// one instead: one session at a time is all the log knows.
Future<void> startSession(
  BuildContext context,
  WidgetRef ref, {
  String? routineId,
}) async {
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

  final controller = ref.read(workoutControllerProvider);
  if (routineId == null) {
    await controller.startEmpty();
  } else {
    await controller.startFromRoutine(routineId);
  }
  if (context.mounted) context.push(Routes.workout);
}
