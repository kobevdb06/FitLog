import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Moving a routine between folders, which until now could only be done by
/// opening the full editor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late RoutineActions actions;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    actions = container.read(routineActionsProvider);

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex',
            name: 'Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> makeRoutine(String name, {String? folderId}) => actions.create(
    RoutineDraft(
      name: name,
      folderId: folderId,
      exercises: const [
        RoutineExerciseDraft(exerciseId: 'ex', sets: [RoutineSetDraft()]),
      ],
    ),
  );

  test('a new routine starts at the top level', () async {
    final id = await makeRoutine('Push');
    expect(await actions.routineFolderId(id), isNull);
  });

  test('moving puts the routine in the folder', () async {
    final id = await makeRoutine('Push');
    final folderId = await actions.createFolder('Push Pull Legs');

    await actions.moveToFolder(id, folderId);

    expect(await actions.routineFolderId(id), folderId);
    expect((await db.routinesDao.getRoutine(id))!.folderId, folderId);
  });

  test('moving to null puts it back on the top level', () async {
    final folderId = await actions.createFolder('Bovenlichaam');
    final id = await makeRoutine('Push', folderId: folderId);
    expect(await actions.routineFolderId(id), folderId);

    await actions.moveToFolder(id, null);

    expect(await actions.routineFolderId(id), isNull);
  });

  test('a routine can move straight from one folder to another', () async {
    final first = await actions.createFolder('Blok 1');
    final second = await actions.createFolder('Blok 2');
    final id = await makeRoutine('Push', folderId: first);

    await actions.moveToFolder(id, second);

    expect(await actions.routineFolderId(id), second);
  });

  test('moving does not touch the routine itself', () async {
    final id = await makeRoutine('Push');
    final before = await db.routinesDao.getRoutineDetail(id);
    final folderId = await actions.createFolder('Blok');

    await actions.moveToFolder(id, folderId);

    final after = await db.routinesDao.getRoutineDetail(id);
    expect(after!.routine.name, before!.routine.name);
    expect(after.exercises, hasLength(before.exercises.length));
    expect(after.totalSets, before.totalSets);
  });

  test('the folder list comes back in display order', () async {
    await actions.createFolder('Eerst');
    await actions.createFolder('Daarna');

    final folders = await actions.folders();
    expect(folders.map((f) => f.name), ['Eerst', 'Daarna']);
  });

  test('the folder list is empty before any folder is made', () async {
    expect(await actions.folders(), isEmpty);
  });

  test('deleting the folder leaves the routine at the top level', () async {
    final folderId = await actions.createFolder('Tijdelijk');
    final id = await makeRoutine('Push', folderId: folderId);

    await actions.deleteFolder(folderId);

    expect(await db.routinesDao.getRoutine(id), isNotNull);
    expect(await actions.routineFolderId(id), isNull);
  });

  test('the folder of a routine that does not exist is simply null', () async {
    expect(await actions.routineFolderId('bestaat-niet'), isNull);
  });
}
