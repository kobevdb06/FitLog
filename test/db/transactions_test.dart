import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/share/data/routine_import.dart';
import 'package:fitlog/features/share/domain/routine_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Writes in several steps go in whole or not at all (DECISIONS 287).
///
/// A step that fails is forced here with a trigger: the database itself
/// refuses the write halfway, as a full disk or a crash would.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
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
  });

  tearDown(() => db.close());

  Future<void> refuse(String table, String event) => db.customStatement(
    'CREATE TRIGGER refuse_$table BEFORE $event ON $table '
    "BEGIN SELECT RAISE(ABORT, 'kapot'); END",
  );

  test('a session started again leaves no empty running one', () async {
    final source = await db.workoutsDao.startWorkout(
      name: 'Been',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(source, [
      'squat',
    ], defaultRestSeconds: 90);
    await db.workoutsDao.finishWorkout(source, discardPending: false);
    await refuse('workout_exercises', 'INSERT');

    await expectLater(
      db.workoutsDao.startFromWorkout(source, defaultRestSeconds: 90),
      throwsA(anything),
    );
    expect(await db.workoutsDao.getActiveWorkoutRow(), isNull);
  });

  test('a routine from a friend leaves no exercises without it', () async {
    final plan = await planRoutineImport(
      db,
      const SharedRoutine(
        name: 'Van Jan',
        exercises: [
          SharedExercise(
            name: 'Iets nieuws',
            primaryMuscle: 'borst',
            category: ExerciseCategory.barbell,
          ),
        ],
      ),
    );
    await refuse('routines', 'INSERT');

    await expectLater(applyRoutineImport(db, plan), throwsA(anything));
    expect(await db.exercisesDao.countExercises(), 1);
  });

  test('deleting every conversation is all or none', () async {
    const thread = 't-1';
    await db.chatDao.createThread(thread, 'Vraag');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: thread,
      role: 'user',
      content: 'Hoi',
    );
    await refuse('chat_threads', 'DELETE');

    await expectLater(db.chatDao.deleteAllThreads(), throwsA(anything));
    expect(await db.chatDao.messages(thread), hasLength(1));
  });
}
