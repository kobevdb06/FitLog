import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// A workout's set count, as its volume: without the warm-ups. They counted,
/// and the coach got the number as its working sets (DECISIONS 284).
void main() {
  test('a warm-up does not count as a set of the workout', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await db.settingsDao.ensureInitialized();
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'squat',
            name: 'Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );
    final workout = await db.workoutsDao.startWorkout(
      name: 'Been',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(workout, [
      'squat',
    ], defaultRestSeconds: 90);
    final exercise = (await db.workoutsDao.getWorkoutDetail(workout))!
        .exercises
        .single
        .workoutExercise
        .id;
    await db.workoutsDao.addSet(exercise, weightKg: 100, reps: 5);
    final sets = (await db.workoutsDao.getWorkoutDetail(workout))!
        .exercises
        .single
        .sets;
    await (db.update(
      db.workoutSetsTable,
    )..where((t) => t.id.equals(sets[0].id))).write(
      const WorkoutSetsTableCompanion(
        setType: Value('warmup'),
        weightKg: Value(60),
        reps: Value(5),
        isCompleted: Value(true),
      ),
    );
    await (db.update(db.workoutSetsTable)
          ..where((t) => t.id.equals(sets[1].id)))
        .write(const WorkoutSetsTableCompanion(isCompleted: Value(true)));

    await db.workoutsDao.recalculateTotals(workout);

    final row = (await db.workoutsDao.getWorkoutDetail(workout))!.workout;
    expect(row.totalSets, 1);
    expect(row.totalVolumeKg, 500);
  });
}
