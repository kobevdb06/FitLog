import 'dart:convert';

import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The routines the coach makes and changes itself - and only those.
///
/// This is the one place the coach writes in the logbook, so most of what is
/// checked here is what it may not do: touch a routine outside its folder,
/// use an exercise that does not exist, or change something without the
/// version before it being kept.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CoachTools tools;

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    tools = CoachTools(db);
    for (final (id, name) in [
      ('ex-bench', 'Bench Press'),
      ('ex-fly', 'Cable Fly'),
      ('ex-dip', 'Dips'),
    ]) {
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

  Map<String, Object?> chestDay({String? routine, int benchReps = 8}) => {
    'routine': ?routine,
    'name': 'Chest day',
    'change': 'Een borstdag rond je bench, met fly om af te werken.',
    'exercises': [
      {
        'exercise': 'Bench Press',
        'rest_seconds': 150,
        'sets': [
          {'type': 'warmup', 'reps': 10, 'weight_kg': 40},
          for (var i = 0; i < 3; i++) {'reps': benchReps, 'weight_kg': 80},
        ],
      },
      {
        'exercise': 'cable fly',
        'notes': 'Langzaam terug',
        'sets': [
          for (var i = 0; i < 3; i++) {'reps': 15},
        ],
      },
    ],
  };

  group('een nieuwe routine', () {
    test('komt in de map Coach, set per set', () async {
      final lookup = await tools.run('save_coach_routine', chestDay());

      expect(decode(lookup)['ok'], isTrue);
      final folder = (await db.routinesDao.coachFolder())!;
      final routine = (await db.routinesDao.coachRoutines()).single;
      expect(routine.name, 'Chest day');
      expect(routine.folderId, folder.id);

      final detail = (await db.routinesDao.getRoutineDetail(routine.id))!;
      final bench = detail.exercises.first;
      expect(bench.exercise.id, 'ex-bench');
      expect(bench.routineExercise.restSeconds, 150);
      expect(bench.sets, hasLength(4));
      expect(bench.sets.first.setType, 'warmup');
      expect(bench.sets.last.targetReps, 8);
      expect(bench.sets.last.targetWeightKg, 80);
      final fly = detail.exercises.last;
      expect(fly.exercise.id, 'ex-fly');
      expect(fly.routineExercise.notes, 'Langzaam terug');
      expect(fly.sets.first.targetWeightKg, isNull);
    });

    test('en als kaart: gemaakt, met wat en waarom', () async {
      final lookup = await tools.run('save_coach_routine', chestDay());

      final card = lookup.proposal!;
      expect(card.kind, ProposalKind.coachRoutine);
      expect(card.made, isTrue);
      expect(card.change, contains('borstdag'));
      expect(card.appliedId, (await db.routinesDao.coachRoutines()).single.id);
      expect(card.routine!.exercises.first.sets, 4);
      // De herhalingen van het werk, niet van de opwarming.
      expect(card.routine!.exercises.first.targetReps, 8);
      expect(lookup.summary, 'de routine "Chest day", die het maakte');
    });

    test('een oefening die niet exact zo heet, schrijft niets', () async {
      // "bench" is geen naam: welke van de drie bench presses was bedoeld?
      final lookup = await tools.run('save_coach_routine', {
        'name': 'Chest day',
        'change': 'Iets',
        'exercises': [
          {
            'exercise': 'bench',
            'sets': [
              {'reps': 8},
            ],
          },
          {
            'exercise': 'Zweefduik',
            'sets': [
              {'reps': 8},
            ],
          },
        ],
      });

      expect(decode(lookup)['ok'], isFalse);
      expect(decode(lookup)['not_found'], ['bench', 'Zweefduik']);
      expect(lookup.proposal, isNull);
      expect(await db.routinesDao.coachFolder(), isNull);
      expect(await db.select(db.routinesTable).get(), isEmpty);
    });

    test('onmogelijke waarden ook niet', () async {
      final lookup = await tools.run('save_coach_routine', {
        'name': 'Chest day',
        'change': 'Iets',
        'exercises': [
          {
            'exercise': 'Bench Press',
            'sets': [
              {'reps': 8, 'weight_kg': 2000},
            ],
          },
        ],
      });

      expect(decode(lookup)['ok'], isFalse);
      expect(await db.select(db.routinesTable).get(), isEmpty);
    });

    test('en een naam die er al staat, vraagt om aanpassen', () async {
      await tools.run('save_coach_routine', chestDay());

      final lookup = await tools.run('save_coach_routine', chestDay());

      expect(decode(lookup)['ok'], isFalse);
      expect('${decode(lookup)['error']}', contains('routine: "Chest day"'));
      expect(await db.routinesDao.coachRoutines(), hasLength(1));
    });
  });

  group('een routine aanpassen', () {
    test('vervangt de inhoud en bewaart hoe ze was', () async {
      await tools.run('save_coach_routine', chestDay());
      final id = (await db.routinesDao.coachRoutines()).single.id;

      final lookup = await tools.run('save_coach_routine', {
        ...chestDay(routine: 'chest day', benchReps: 5),
        'change': 'Zwaarder en minder herhalingen: je bench staat stil.',
      });

      expect(decode(lookup)['ok'], isTrue);
      final detail = (await db.routinesDao.getRoutineDetail(id))!;
      expect(detail.exercises.first.sets.last.targetReps, 5);
      final versions = await db.routinesDao.watchVersions(id).first;
      expect(
        versions.single.note,
        'Voor: Zwaarder en minder herhalingen: je bench staat stil.',
      );
      expect(lookup.proposal!.made, isFalse);
      expect(lookup.summary, 'de routine "Chest day", die het aanpaste');
    });

    test('maar nooit een routine buiten de map Coach', () async {
      final mine = await db.routinesDao.createRoutine(
        const RoutineDraft(
          name: 'Chest day',
          exercises: [
            RoutineExerciseDraft(
              exerciseId: 'ex-dip',
              sets: [RoutineSetDraft(targetReps: 12)],
            ),
          ],
        ),
      );

      final lookup = await tools.run(
        'save_coach_routine',
        chestDay(routine: 'Chest day'),
      );

      expect(decode(lookup)['ok'], isFalse);
      expect('${decode(lookup)['error']}', contains('niet in de map Coach'));
      final detail = (await db.routinesDao.getRoutineDetail(mine))!;
      expect(detail.exercises.single.exercise.id, 'ex-dip');
      expect(await db.routinesDao.watchVersions(mine).first, isEmpty);
    });
  });

  test(
    'de routines in de map Coach, om te lezen voor je iets aanpast',
    () async {
      await tools.run('save_coach_routine', chestDay());

      final lookup = await tools.run('coach_routines', const {});

      final json = decode(lookup);
      expect(json['folder_exists'], isTrue);
      final routine = (json['routines']! as List).single as Map;
      expect(routine['name'], 'Chest day');
      final bench = (routine['exercises']! as List).first as Map;
      expect(bench['exercise'], 'Bench Press');
      expect(bench['rest_seconds'], 150);
      expect((bench['sets']! as List).first, {
        'type': 'warmup',
        'reps': 10,
        'weight_kg': 40,
      });
      expect(lookup.summary, 'je routines in de map Coach');
    },
  );

  test('zonder map nog niets', () async {
    final lookup = await tools.run('coach_routines', const {});

    expect(decode(lookup), {'folder_exists': false, 'routines': <Object>[]});
  });

  test('de oude voorsteltool bestaat niet meer', () async {
    expect(CoachTools.names, isNot(contains('propose_routine')));
    expect(
      CoachTools.definitions().map((d) => d['name']),
      containsAll(<String>['coach_routines', 'save_coach_routine', 'gym']),
    );
  });
}
