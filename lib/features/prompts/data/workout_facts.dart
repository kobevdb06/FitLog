import 'package:drift/drift.dart';

import '../../../core/db/database.dart';

/// A finished workout as the coach is given it after the summary opens: set
/// by set, with what the routine asked and what each exercise was the time
/// before. Null for a workout that is gone or still running.
///
/// [health] is whether the coach may see the watch: the heart rate during
/// the workout comes from Health Connect.
Future<Map<String, Object?>?> buildWorkoutFacts(
  AppDatabase db,
  String workoutId, {
  required bool health,
}) async {
  final detail = await db.workoutsDao.getWorkoutDetail(workoutId);
  if (detail == null || detail.isActive) return null;
  final workout = detail.workout;

  final routine = workout.routineId == null
      ? null
      : await db.routinesDao.getRoutine(workout.routineId!);
  final targets = await _targetReps(db, workoutId);
  final records = await db.recordsDao.recordsForWorkout(workoutId);

  return {
    'name': workout.name,
    'date': _day(workout.startedAt),
    'minutes': workout.durationSeconds ~/ 60,
    'volume_kg': workout.totalVolumeKg.round(),
    'working_sets': workout.totalSets,
    'from_routine': ?routine?.name,
    'felt': ?PerceivedEffort.fromWire(workout.perceivedEffort)?.label,
    if (workout.isDeload) 'deload': true,
    if (workout.isLight) 'light': true,
    'notes': ?_text(workout.notes),
    if (workout.avgHeartRate case final average? when health)
      'heart_rate': {'average': average, 'highest': workout.maxHeartRate},
    if (records.isNotEmpty)
      'records': [
        for (final record in records)
          {
            'exercise': record.exercise.name,
            'record': record.type.label,
            'value': double.parse(record.record.value.toStringAsFixed(1)),
          },
      ],
    'exercises': [
      for (final item in detail.exercises)
        {
          'name': item.exercise.name,
          'notes': ?_text(item.workoutExercise.notes),
          'superset': ?item.workoutExercise.supersetGroup,
          if (item.workoutExercise.isUnilateral) 'per_side': true,
          'target_reps': ?targets[item.exercise.id],
          'sets': [
            for (final set in item.sets)
              {
                'type': set.setType,
                'status': set.isCompleted
                    ? 'done'
                    : set.isSkipped
                    ? 'skipped'
                    : 'open',
                ..._numbers(set),
              },
          ],
          'last_time': ?await lastTimeOf(
            db,
            exerciseId: item.exercise.id,
            before: workout.startedAt,
            unilateral: item.workoutExercise.isUnilateral,
          ),
        },
    ],
  };
}

Map<String, Object?> _numbers(WorkoutSetRow set) => {
  'weight_kg': ?set.weightKg,
  'reps': ?set.reps,
  'seconds': ?set.durationSeconds,
  'meters': ?set.distanceM,
  'rpe': ?set.rpe,
  'side': ?set.side,
};

/// What the session's routine asks per exercise: the most repetitions of
/// its working sets. The same reading as the hint's.
Future<Map<String, int>> _targetReps(AppDatabase db, String workoutId) async {
  final rows = await db
      .customSelect(
        'SELECT re.exercise_id AS exercise_id, MAX(rs.target_reps) AS reps '
        'FROM workouts w '
        'JOIN routine_exercises re ON re.routine_id = w.routine_id '
        'JOIN routine_sets rs ON rs.routine_exercise_id = re.id '
        'WHERE w.id = ? AND rs.set_type != ? AND rs.target_reps > 0 '
        'GROUP BY re.exercise_id',
        variables: [
          Variable.withString(workoutId),
          Variable.withString(SetType.warmup.wire),
        ],
      )
      .get();
  return {
    for (final row in rows)
      row.read<String>('exercise_id'): row.read<int>('reps'),
  };
}

/// The working sets of the last finished session of the exercise before
/// this one, done the same way: one arm at a time or both. Before, not the
/// newest: asked about an older workout, a later session is not "last time".
/// A deload is looked past, as the hint does.
Future<Map<String, Object?>?> lastTimeOf(
  AppDatabase db, {
  required String exerciseId,
  required int before,
  required bool unilateral,
}) async {
  final found = await db
      .customSelect(
        'SELECT we.id AS we_id, w.started_at AS started_at '
        'FROM workout_exercises we '
        'JOIN workouts w ON w.id = we.workout_id '
        'WHERE we.exercise_id = ? AND w.ended_at IS NOT NULL '
        'AND w.is_deload = 0 AND w.started_at < ? AND we.is_unilateral = ? '
        'ORDER BY w.started_at DESC LIMIT 1',
        variables: [
          Variable.withString(exerciseId),
          Variable.withInt(before),
          Variable.withBool(unilateral),
        ],
      )
      .getSingleOrNull();
  if (found == null) return null;

  final sets = await db
      .customSelect(
        'SELECT * FROM workout_sets WHERE workout_exercise_id = ? '
        'AND set_type != ? AND is_completed = 1 ORDER BY sort_order',
        variables: [
          Variable.withString(found.read<String>('we_id')),
          Variable.withString(SetType.warmup.wire),
        ],
      )
      .get();
  if (sets.isEmpty) return null;
  return {
    'date': _day(found.read<int>('started_at')),
    'sets': [
      for (final row in sets) _numbers(db.workoutSetsTable.map(row.data)),
    ],
  };
}

String? _text(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

String _day(int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
