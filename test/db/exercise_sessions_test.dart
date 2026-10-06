import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The history of one exercise, as its Geschiedenis and Grafieken tabs read
/// it: the newest sessions, whatever else there is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  final start = DateTime(2024, 1, 1, 18);

  /// One session of bench press [day] days after [start], with one set.
  /// Unfinished when [running].
  Future<void> session(int day, {bool running = false}) async {
    final at = start.add(Duration(days: day)).millisecondsSinceEpoch;
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-$day',
            name: 'Push',
            startedAt: at,
            endedAt: Value(running ? null : at + 3600000),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$day',
            workoutId: 'w-$day',
            exerciseId: 'ex-bench',
            sortOrder: 0,
          ),
        );
    await db
        .into(db.workoutSetsTable)
        .insert(
          WorkoutSetsTableCompanion.insert(
            id: 'ws-$day',
            workoutExerciseId: 'we-$day',
            sortOrder: 0,
            weightKg: Value(60 + day / 10),
            reps: const Value(5),
            isCompleted: const Value(true),
          ),
        );
  }

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() => db.close());

  test('met meer dan 200 keer: de nieuwste 200, nieuwste eerst', () async {
    // Twee jaar lang, oudste eerst ingevoerd - zoals een echt logboek groeit.
    for (var day = 0; day < 205; day++) {
      await session(day * 3);
    }

    final sessions = await db.workoutsDao.exerciseSessions('ex-bench');

    expect(sessions, hasLength(200));
    expect(sessions.first.workout.id, 'w-${204 * 3}');
    expect(sessions.last.workout.id, 'w-${5 * 3}');
    for (var i = 1; i < sessions.length; i++) {
      expect(sessions[i].date.isBefore(sessions[i - 1].date), isTrue);
    }
    expect(sessions.first.sets.single.id, 'ws-${204 * 3}');
  });

  test('een training die nog bezig is, telt niet mee voor de 200', () async {
    for (var day = 0; day < 200; day++) {
      await session(day);
    }
    await session(500, running: true);

    final sessions = await db.workoutsDao.exerciseSessions('ex-bench');

    expect(sessions, hasLength(200));
    expect(sessions.every((s) => s.workout.endedAt != null), isTrue);
    expect(sessions.last.workout.id, 'w-0');
  });
}
