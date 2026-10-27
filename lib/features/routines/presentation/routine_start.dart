import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';

/// Starts a session - the routine's, or an empty one without [routineId] -
/// and steps into it. With one already running it offers to go back to that
/// one instead: one session at a time is all the log knows. [lighter] makes
/// the routine's session lighter, as a deload would.
Future<void> startSession(
  BuildContext context,
  WidgetRef ref, {
  String? routineId,
  bool lighter = false,
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

  // Taken before the start: the session shows up while it is still being
  // set up - lighter takes a while - and the card that asked for it on
  // Vandaag gives way to "Je workout loopt". Its context is gone by then,
  // and the start would end on Start instead of in the session.
  final router = GoRouter.of(context);
  final controller = ref.read(workoutControllerProvider);
  if (routineId == null) {
    await controller.startEmpty();
  } else {
    await controller.startFromRoutine(routineId, lighter: lighter);
  }
  router.push(Routes.workout);
}
