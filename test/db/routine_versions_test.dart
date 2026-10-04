import 'package:fitlog/core/db/dao/routines_dao.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The coach's folder, and the versions that make what the coach does undone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name) in [('ex-a', 'Bench Press'), ('ex-b', 'Cable Fly')]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
  });

  tearDown(() => db.close());

  RoutineDraft draft(String name, List<(String, int, double?)> exercises) =>
      RoutineDraft(
        name: name,
        exercises: [
          for (final (id, reps, kg) in exercises)
            RoutineExerciseDraft(
              exerciseId: id,
              sets: [
                for (var i = 0; i < 3; i++)
                  RoutineSetDraft(targetReps: reps, targetWeightKg: kg),
              ],
            ),
        ],
      );

  test('de map van de coach komt er één keer', () async {
    expect(await db.routinesDao.coachFolder(), isNull);

    final first = await db.routinesDao.ensureCoachFolder();
    final again = await db.routinesDao.ensureCoachFolder();

    expect(again, first);
    final folder = (await db.routinesDao.coachFolder())!;
    expect(folder.name, 'Coach');
    expect(folder.isCoach, isTrue);
    expect(await db.routinesDao.getFolders(), hasLength(1));
  });

  test('een versie terugzetten bewaart eerst wat er nu is', () async {
    final id = await db.routinesDao.createRoutine(
      draft('Chest day', [('ex-a', 8, 80)]),
    );
    await db.routinesDao.keepVersion(id, 'Voor: meer volume');
    await db.routinesDao.updateRoutine(
      id,
      draft('Chest day', [('ex-a', 12, 60), ('ex-b', 15, 20)]),
    );

    final versions = await db.routinesDao.watchVersions(id).first;
    final left = await db.routinesDao.restoreVersion(versions.single.id);

    expect(left, 0);
    final detail = (await db.routinesDao.getRoutineDetail(id))!;
    expect(detail.exercises.single.exercise.id, 'ex-a');
    expect(detail.exercises.single.sets.first.targetReps, 8);
    expect(detail.exercises.single.sets.first.targetWeightKg, 80);
    // Wat de coach gemaakt had, is niet weg: dat staat nu bovenaan.
    final after = await db.routinesDao.watchVersions(id).first;
    expect(after, hasLength(2));
    expect(after.first.note, 'Voor je een vorige versie terugzette');
  });

  test('en houdt de plek en de kleur van nu', () async {
    final folder = await db.routinesDao.ensureCoachFolder();
    final id = await db.routinesDao.createRoutine(
      RoutineDraft(
        name: 'Chest day',
        folderId: folder,
        colorIndex: 3,
        exercises: draft('x', [('ex-a', 8, 80)]).exercises,
      ),
    );
    await db.routinesDao.keepVersion(id, 'Voor: iets');

    final versions = await db.routinesDao.watchVersions(id).first;
    await db.routinesDao.restoreVersion(versions.single.id);

    final routine = (await db.routinesDao.getRoutine(id))!;
    expect(routine.folderId, folder);
    expect(routine.colorIndex, 3);
  });

  test('een oefening die niet meer bestaat valt eruit, de rest komt '
      'terug', () async {
    final id = await db.routinesDao.createRoutine(
      draft('Chest day', [('ex-a', 8, 80), ('ex-b', 15, 20)]),
    );
    await db.routinesDao.keepVersion(id, 'Voor: zonder fly');
    await db.routinesDao.updateRoutine(
      id,
      draft('Chest day', [('ex-a', 8, 80)]),
    );
    await db.customStatement("DELETE FROM exercises WHERE id = 'ex-b'");

    final versions = await db.routinesDao.watchVersions(id).first;
    final left = await db.routinesDao.restoreVersion(versions.single.id);

    expect(left, 1);
    final detail = (await db.routinesDao.getRoutineDetail(id))!;
    expect(detail.exercises.map((e) => e.exercise.id), ['ex-a']);
  });

  test('er blijven er twintig, de oudste gaan eerst', () async {
    final id = await db.routinesDao.createRoutine(
      draft('Chest day', [('ex-a', 8, 80)]),
    );
    for (var i = 0; i < 25; i++) {
      await db.routinesDao.keepVersion(id, 'Voor: wijziging $i');
    }

    final kept = await db.routinesDao.watchVersions(id).first;
    expect(kept, hasLength(RoutinesDao.keptVersions));
    expect(kept.first.note, 'Voor: wijziging 24');
    expect(kept.last.note, 'Voor: wijziging 5');
  });

  test('en ze gaan mee weg met de routine', () async {
    final id = await db.routinesDao.createRoutine(
      draft('Chest day', [('ex-a', 8, 80)]),
    );
    await db.routinesDao.keepVersion(id, 'Voor: iets');

    await db.routinesDao.deleteRoutine(id);

    expect(await db.select(db.routineVersionsTable).get(), isEmpty);
  });
}
