import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// What the coach offers to add, and who actually adds it.
///
/// The whole point of this design: the model describes, the user decides.
/// These tests are mostly about the second half - that nothing appears in the
/// logbook until a button is tapped, and that tapping twice does not make two.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CoachTools tools;
  ProviderContainer? container;

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    tools = CoachTools(db);

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bench Press',
            primaryMuscle: 'borst',
            equipment: const Value('barbell'),
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
      coachClientFactoryProvider.overrideWithValue(
        (apiKey, provider) => AiClient(
          apiKey: apiKey,
          provider: provider,
          client: MockClient((request) async => http.Response('{}', 500)),
        ),
      ),
    ],
  );

  /// Puts a proposal in the database the way an answer would.
  Future<ChatMessageRow> answerWith(List<CoachProposal> proposals) async {
    await db.chatDao.createThread('t-1', 'Vraag');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Zo zou ik het doen.',
      proposals: encodeProposals(proposals),
    );
    return (await db.chatDao.messages('t-1')).single;
  }

  group('een oefening voorstellen', () {
    test('levert een kaart op en verandert niets', () async {
      final before = await db.exercisesDao.countExercises();

      final lookup = await tools.run('propose_exercise', {
        'name': 'Sledepush',
        'primary_muscle': 'Benen',
        'equipment': 'slee',
        'category': 'duration',
      });

      expect(decode(lookup)['ok'], isTrue);
      expect(lookup.proposal, isNotNull);
      expect(lookup.proposal!.exercise!.name, 'Sledepush');
      // Spiergroepen komen in kleine letters binnen, zoals de rest van de app.
      expect(lookup.proposal!.exercise!.primaryMuscle, 'benen');
      expect(lookup.summary, contains('voorstel'));

      // En er is niets aangemaakt.
      expect(await db.exercisesDao.countExercises(), before);
    });

    test('een oefening die al bestaat wordt geen tweede', () async {
      final lookup = await tools.run('propose_exercise', {
        'name': 'bench press',
        'primary_muscle': 'borst',
      });

      expect(decode(lookup)['ok'], isFalse);
      expect(decode(lookup)['existing'], 'Bench Press');
      expect(lookup.proposal, isNull);
    });

    test('en zonder naam of spier komt er niets uit', () async {
      final lookup = await tools.run('propose_exercise', {'name': 'Iets'});

      expect(decode(lookup)['ok'], isFalse);
      expect(lookup.proposal, isNull);
    });
  });

  group('een routine voorstellen', () {
    test('matcht elke oefening aan een die bestaat', () async {
      final lookup = await tools.run('propose_routine', {
        'name': 'Push',
        'exercises': [
          {'exercise': 'bench', 'sets': 4, 'target_reps': 8},
        ],
      });

      expect(decode(lookup)['ok'], isTrue);
      final routine = lookup.proposal!.routine!;
      expect(routine.name, 'Push');
      expect(routine.exercises.single.exerciseId, 'ex-bench');
      expect(routine.exercises.single.name, 'Bench Press');
      expect(routine.exercises.single.sets, 4);
      expect(routine.totalSets, 4);
    });

    test(
      'en een verzonnen oefening komt terug als fout, niet als kaart',
      () async {
        // Zo kan het model het rechtzetten in plaats van een routine te maken
        // met een oefening die niet bestaat.
        final lookup = await tools.run('propose_routine', {
          'name': 'Push',
          'exercises': [
            {'exercise': 'Zweefduik', 'sets': 3},
          ],
        });

        expect(decode(lookup)['ok'], isFalse);
        expect('${decode(lookup)['not_found']}', contains('Zweefduik'));
        expect(lookup.proposal, isNull);
      },
    );
  });

  group('de knop', () {
    test('maakt de oefening aan, met haar eigen spiergroep erbij', () async {
      container = newContainer();
      final coach = container!.read(coachControllerProvider.notifier);

      final message = await answerWith([
        CoachProposal.ofExercise(
          const ExerciseProposal(
            name: 'Sledepush',
            primaryMuscle: 'benen',
            equipment: 'slee',
            category: 'duration',
          ),
        ),
      ]);

      final id = await coach.accept(message: message, index: 0);

      expect(id, isNotNull);
      final made = (await db.exercisesDao.getById(id!))!;
      expect(made.name, 'Sledepush');
      expect(made.primaryMuscle, 'benen');
      expect(made.category, 'duration');
      expect(made.isCustom, isTrue);

      // Een spiergroep en materiaal die de app nog niet kende, staan nu ook
      // in de keuzelijsten - anders wijst de oefening naar een naam die
      // nergens anders bestaat.
      expect(await db.exercisesDao.distinctPrimaryMuscles(), contains('benen'));
      expect(await db.exercisesDao.distinctEquipment(), contains('slee'));
    });

    test('en de kaart onthoudt dat je getikt hebt', () async {
      container = newContainer();
      final coach = container!.read(coachControllerProvider.notifier);

      final message = await answerWith([
        CoachProposal.ofExercise(
          const ExerciseProposal(name: 'Sledepush', primaryMuscle: 'benen'),
        ),
      ]);

      final first = await coach.accept(message: message, index: 0);
      final stored = (await db.chatDao.messages('t-1')).single;
      expect(parseProposals(stored.proposals).single.isApplied, isTrue);

      // Tweemaal tikken maakt geen twee oefeningen.
      final again = await coach.accept(message: stored, index: 0);
      expect(again, first);
      final all = await db.exercisesDao.getExercises();
      expect(all.where((e) => e.name == 'Sledepush'), hasLength(1));
    });

    test('maakt de routine met haar sets', () async {
      container = newContainer();
      final coach = container!.read(coachControllerProvider.notifier);

      final message = await answerWith([
        CoachProposal.ofRoutine(
          const RoutineProposal(
            name: 'Push',
            exercises: [
              ProposedRoutineExercise(
                exerciseId: 'ex-bench',
                name: 'Bench Press',
                sets: 3,
                targetReps: 8,
              ),
            ],
          ),
        ),
      ]);

      final id = await coach.accept(message: message, index: 0);

      final routine = await db.routinesDao.getRoutineDetail(id!);
      expect(routine!.routine.name, 'Push');
      expect(routine.exercises.single.exercise.name, 'Bench Press');
      expect(routine.exercises.single.sets, hasLength(3));
      expect(routine.exercises.single.sets.first.targetReps, 8);
    });

    test('en zonder tik bestaat er niets', () async {
      container = newContainer();
      final before = await db.exercisesDao.countExercises();

      await answerWith([
        CoachProposal.ofExercise(
          const ExerciseProposal(name: 'Sledepush', primaryMuscle: 'benen'),
        ),
      ]);

      expect(await db.exercisesDao.countExercises(), before);
      expect(await db.routinesDao.getFolders(), isEmpty);
    });
  });

  group('wat er bewaard staat', () {
    test('overleeft opschrijven en teruglezen', () {
      final proposals = [
        CoachProposal.ofExercise(
          const ExerciseProposal(
            name: 'Sledepush',
            primaryMuscle: 'benen',
            secondaryMuscles: ['bilspieren'],
            equipment: 'slee',
            category: 'duration',
            instructions: 'Duwen.',
          ),
        ),
        CoachProposal.ofRoutine(
          const RoutineProposal(
            name: 'Push',
            exercises: [
              ProposedRoutineExercise(
                exerciseId: 'ex-bench',
                name: 'Bench Press',
                sets: 3,
              ),
            ],
          ),
          appliedId: 'r-1',
        ),
      ];

      final read = parseProposals(encodeProposals(proposals));

      expect(read, hasLength(2));
      expect(read.first.exercise!.secondaryMuscles, ['bilspieren']);
      expect(read.first.isApplied, isFalse);
      expect(read[1].routine!.exercises.single.sets, 3);
      expect(read[1].appliedId, 'r-1');
    });

    test('en onzin kost je de kaart, niet het gesprek', () {
      expect(parseProposals('dit is geen json'), isEmpty);
      expect(parseProposals('{"kind":"exercise"}'), isEmpty);
      expect(parseProposals('[{"kind":"raket"}]'), isEmpty);
      expect(parseProposals(null), isEmpty);
    });
  });
}
