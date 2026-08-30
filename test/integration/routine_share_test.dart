import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/share/data/routine_import.dart';
import 'package:fitlog/features/share/domain/exercise_matcher.dart';
import 'package:fitlog/features/share/domain/routine_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Two phones, one code: a routine leaves one database as bytes and arrives in
/// another. Both databases are real; only the QR in between is imaginary.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase his;
  late AppDatabase mine;
  late ProviderContainer container;

  /// The catalogue both phones share, seeded with the same ids.
  Future<void> seedCatalogue(AppDatabase db) async {
    for (final e in const [
      ('cat-squat', 'Barbell Squat', 'quadriceps', 'barbell'),
      ('cat-bench', 'Barbell Bench Press', 'borst', 'barbell'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: e.$1,
              name: e.$2,
              primaryMuscle: e.$3,
              category: e.$4,
              createdAt: 0,
            ),
          );
    }
  }

  setUp(() async {
    his = createTestDatabase();
    mine = createTestDatabase();
    for (final db in [his, mine]) {
      await db.settingsDao.ensureInitialized();
      await seedCatalogue(db);
    }
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(mine)],
    );
  });

  tearDown(() async {
    container.dispose();
    await his.close();
    await mine.close();
  });

  /// An exercise he made himself.
  Future<String> hisOwnExercise({
    String name = 'Kabel curl schuin',
    String muscle = 'biceps',
    String category = 'cable',
  }) async {
    final id = 'own-${name.hashCode}';
    await his.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: id,
        name: name,
        primaryMuscle: muscle,
        category: category,
        isCustom: const Value(true),
        instructions: const Value('Ellebogen stil houden.'),
        createdAt: 0,
      ),
    );
    return id;
  }

  Future<String> hisRoutine({List<String> exerciseIds = const []}) {
    return his.routinesDao.createRoutine(
      RoutineDraft(
        name: 'Push A',
        notes: 'zwaar blok',
        exercises: [
          for (final id in exerciseIds)
            RoutineExerciseDraft(
              exerciseId: id,
              restSeconds: 120,
              sets: const [
                RoutineSetDraft(setType: SetType.warmup),
                RoutineSetDraft(targetReps: 8),
                RoutineSetDraft(targetReps: 6),
              ],
            ),
        ],
      ),
    );
  }

  /// The whole trip: his routine, through the bytes, onto my phone.
  Future<RoutineImportPlan> scan(String routineId) async {
    final payload = await sharedRoutineFor(his, routineId);
    final decoded = decodeRoutine(encodeRoutine(payload));
    return planRoutineImport(mine, decoded);
  }

  test('a catalogue routine arrives without adding anything', () async {
    final id = await hisRoutine(exerciseIds: ['cat-squat', 'cat-bench']);

    final plan = await scan(id);
    expect(plan.newExerciseCount, 0);
    expect(
      plan.exercises.map((e) => e.match.kind),
      everyElement(ExerciseMatchKind.sameId),
    );

    final routineId = await applyRoutineImport(mine, plan);

    final detail = await mine.routinesDao.getRoutineDetail(routineId);
    expect(detail!.routine.name, 'Push A');
    expect(detail.exercises.map((e) => e.exercise.id), [
      'cat-squat',
      'cat-bench',
    ]);
    expect(await mine.exercisesDao.countExercises(), 2);
  });

  test('the sets and the rest come over, the weights do not', () async {
    final id = await hisRoutine(exerciseIds: ['cat-squat']);

    final routineId = await applyRoutineImport(mine, await scan(id));

    final item = (await mine.routinesDao.getRoutineDetail(
      routineId,
    ))!.exercises.single;
    expect(item.routineExercise.restSeconds, 120);
    expect(item.sets.map((s) => s.setType), [
      SetType.warmup.wire,
      SetType.normal.wire,
      SetType.normal.wire,
    ]);
    expect(item.sets.map((s) => s.targetReps), [null, 8, 6]);
    expect(
      item.sets.every((s) => s.targetWeightKg == null),
      isTrue,
      reason: 'his numbers are not mine',
    );
  });

  test('an exercise he made is added to my catalogue', () async {
    final ownId = await hisOwnExercise();
    final id = await hisRoutine(exerciseIds: ['cat-squat', ownId]);

    final plan = await scan(id);
    expect(plan.newExerciseCount, 1);

    await applyRoutineImport(mine, plan);

    final added = (await mine.exercisesDao.getExercises()).firstWhere(
      (e) => e.name == 'Kabel curl schuin',
    );
    expect(added.isCustom, isTrue);
    expect(added.primaryMuscle, 'biceps');
    expect(added.instructions, 'Ellebogen stil houden.');
    expect(
      added.id,
      isNot(ownId),
      reason: 'it gets an id of its own here',
    );
  });

  test('one I already have under the same name is reused', () async {
    await mine.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: 'my-curl',
        name: 'kabel curl schuin',
        primaryMuscle: 'biceps',
        category: 'cable',
        isCustom: const Value(true),
        createdAt: 0,
      ),
    );
    final ownId = await hisOwnExercise();
    final id = await hisRoutine(exerciseIds: [ownId]);

    final plan = await scan(id);
    expect(plan.exercises.single.match.kind, ExerciseMatchKind.sameName);
    expect(plan.newExerciseCount, 0);

    final routineId = await applyRoutineImport(mine, plan);

    final detail = await mine.routinesDao.getRoutineDetail(routineId);
    expect(detail!.exercises.single.exercise.id, 'my-curl');
    expect(await mine.exercisesDao.countExercises(), 3);
  });

  test('I can refuse the match and keep them apart', () async {
    await mine.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: 'my-curl',
        name: 'Kabel curl',
        primaryMuscle: 'biceps',
        category: 'cable',
        isCustom: const Value(true),
        createdAt: 0,
      ),
    );
    final ownId = await hisOwnExercise();
    final id = await hisRoutine(exerciseIds: [ownId]);

    final plan = await scan(id);
    expect(plan.exercises.single.match.kind, ExerciseMatchKind.similar);

    plan.exercises.single.link = false;
    final routineId = await applyRoutineImport(mine, plan);

    final detail = await mine.routinesDao.getRoutineDetail(routineId);
    expect(detail!.exercises.single.exercise.id, isNot('my-curl'));
    expect(await mine.exercisesDao.countExercises(), 4);
  });

  test('an exercise my version does not know becomes my own', () async {
    // His catalogue has an entry mine has never seen: a newer app version, or
    // a regenerated seed.
    await his.exercisesDao.insertExercise(
      ExercisesTableCompanion.insert(
        id: 'cat-nieuw',
        name: 'Zercher Squat',
        primaryMuscle: 'quadriceps',
        category: 'barbell',
        createdAt: 0,
      ),
    );
    final id = await hisRoutine(exerciseIds: ['cat-nieuw']);

    final plan = await scan(id);
    expect(plan.exercises.single.match.kind, ExerciseMatchKind.none);

    await applyRoutineImport(mine, plan);

    final added = (await mine.exercisesDao.getExercises()).firstWhere(
      (e) => e.name == 'Zercher Squat',
    );
    expect(
      added.isCustom,
      isTrue,
      reason: 'here it is not part of the catalogue',
    );
  });

  test('scanning the same code twice adds no duplicates', () async {
    final ownId = await hisOwnExercise();
    final id = await hisRoutine(exerciseIds: ['cat-squat', ownId]);

    await applyRoutineImport(mine, await scan(id));
    final after = await mine.exercisesDao.countExercises();

    await applyRoutineImport(mine, await scan(id));

    expect(await mine.exercisesDao.countExercises(), after);
    expect(
      (await mine.routinesDao.watchRoutines().first),
      hasLength(2),
      reason: 'the routine itself arrives twice, which is what was asked',
    );
  });

  test('an empty routine cannot be shared into a code at all', () async {
    final id = await hisRoutine();
    final payload = await sharedRoutineFor(his, id);

    expect(
      () => decodeRoutine(encodeRoutine(payload)),
      throwsA(isA<InvalidRoutineCodeException>()),
    );
  });

  test('a routine that is gone is a clean failure', () async {
    expect(() => sharedRoutineFor(his, 'weg'), throwsStateError);
  });
}
