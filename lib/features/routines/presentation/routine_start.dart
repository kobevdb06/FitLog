import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';

/// Whether a start is under way: a second tap meanwhile does nothing.
bool _starting = false;

/// Starts a session - the routine's, or an empty one without [routineId] -
/// and steps into it. With one already running it offers to go back to that
/// one instead: one session at a time is all the log knows. [lighter] makes
/// the routine's session lighter, as a deload would.
///
/// Every start goes through here, and a second tap while it starts does
/// nothing: two quick taps made two running sessions (DECISIONS 245).
Future<void> startSession(
  BuildContext context,
  WidgetRef ref, {
  String? routineId,
  bool lighter = false,
}) async {
  if (_starting) return;
  _starting = true;
  try {
    await _start(context, ref, routineId: routineId, lighter: lighter);
  } finally {
    _starting = false;
  }
}

Future<void> _start(
  BuildContext context,
  WidgetRef ref, {
  String? routineId,
  bool lighter = false,
}) async {
  // Asked of the database, not of a provider that may not have answered
  // yet: Start never watched the running session before its first start.
  final running = await ref
      .read(databaseProvider)
      .workoutsDao
      .getActiveWorkoutRow();
  if (!context.mounted) return;
  final active = running == null ? null : (name: running.name);
  if (active != null) {
    final resume = await confirm(
      context,
      title: 'Er loopt al een workout',
      message:
          'Je kunt maar een sessie tegelijk loggen. Ga verder met '
          '"${active.name}" of rond die eerst af.',
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
