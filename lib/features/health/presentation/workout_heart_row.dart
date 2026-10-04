import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../routing/routes.dart';

/// One session with the heart rate a watch measured during it, opening that
/// session on a tap.
class WorkoutHeartRow extends StatelessWidget {
  const WorkoutHeartRow({super.key, required this.workout});

  final WorkoutRow workout;

  @override
  Widget build(BuildContext context) {
    final average = workout.avgHeartRate;
    final when = Formatters.weekdayDayMonth(
      DateTime.fromMillisecondsSinceEpoch(workout.startedAt),
    );
    return ListTile(
      dense: true,
      leading: Icon(
        average == null ? Icons.heart_broken_outlined : Icons.favorite_border,
      ),
      title: Text(workout.name),
      // On the second line, not beside the name: on a narrow phone the
      // numbers would push the name out.
      subtitle: Text(
        average == null
            ? '$when  ·  geen hartslag gemeten'
            : '$when  ·  gem. $average · '
                  'max. ${workout.maxHeartRate ?? average} bpm',
      ),
      onTap: () => context.push(Routes.workoutDetail(workout.id)),
    );
  }
}
