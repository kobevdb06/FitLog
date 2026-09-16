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
import 'package:image/image.dart' as img;

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
  late Directory home;
  ProviderContainer? container;

  /// Every drawing that was asked for, as the body of the request.
  late List<Map<String, Object?>> drawn;

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    tools = CoachTools(db);
    home = await Directory.systemTemp.createTemp('fitlog_proposal');
    drawn = [];

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
    if (await home.exists()) await home.delete(recursive: true);
  });

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWith((ref) => AppPaths(home)),
      coachClientFactoryProvider.overrideWithValue(
        (apiKey, provider) => AiClient(
          apiKey: apiKey,
          provider: provider,
          client: MockClient((request) async => http.Response('{}', 500)),
        ),
      ),
      imageGeneratorFactoryProvider.overrideWithValue(
        (apiKey, {provider = DrawingService.huggingFace, accountId}) =>
            ImageGenerator(
              apiKey: apiKey,
              client: MockClient((request) async {
                drawn.add(jsonDecode(request.body) as Map<String, Object?>);
                return http.Response(
                  jsonEncode({
                    'data': [
                      {
                        'b64_json': base64Encode(
                          img.encodeJpg(img.Image(width: 32, height: 32)),
                        ),
                      },
                    ],
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
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

  group('met tekeningen erbij', () {
    /// Een voorstel zoals de coach het doet: met twee beschrijvingen erbij.
    Future<ChatMessageRow> drawable() => answerWith([
      CoachProposal.ofExercise(
        const ExerciseProposal(
          name: 'Overhead triceps extension',
          primaryMuscle: 'triceps',
          equipment: 'cable',
          category: 'cable',
          startImagePrompt:
              'A person stands with elbows bent, a bar behind '
              'the head',
          endImagePrompt: 'A person stands with the arms straight overhead',
        ),
      ),
    ]);

    setUp(() async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
    });

    test('tekent beide houdingen met hetzelfde toevalsgetal', () async {
      container = newContainer();
      final coach = container!.read(coachControllerProvider.notifier);

      final id = await coach.accept(
        message: await drawable(),
        index: 0,
        withImages: true,
      );

      expect(drawn, hasLength(2));
      // Twee houdingen...
      expect('${drawn.first['prompt']}', contains('elbows bent'));
      expect('${drawn.last['prompt']}', contains('straight overhead'));
      // ...maar dezelfde persoon: zonder één zaad zijn het twee vreemden in
      // twee zalen en zegt het verschil tussen de twee niets.
      expect(drawn.first['seed'], isNotNull);
      expect(drawn.last['seed'], drawn.first['seed']);

      final made = (await db.exercisesDao.getById(id!))!;
      expect(made.startImageFile, isNotNull);
      expect(made.endImageFile, isNotNull);
      expect(made.startImageFile, isNot(made.endImageFile));
      expect(made.imagesGenerated, isTrue);
    });

    test('en wat de gebruiker goedkeurt gaat voor', () async {
      // De coach kiest ook de naam van de oefening, en "V-Bar Attachment"
      // sleept het woord bar de tekening in. Wie de oefening kent haalt dat
      // eruit; dat woord moet dan ook echt weg zijn.
      container = newContainer();
      final coach = container!.read(coachControllerProvider.notifier);

      await coach.accept(
        message: await drawable(),
        index: 0,
        withImages: true,
        startPrompt:
            'Side view of a person with elbows pointing up, forearms '
            'behind the head',
        endPrompt: 'Side view of a person with both arms stretched straight up',
      );

      expect(drawn, hasLength(2));
      expect('${drawn.first['prompt']}', contains('forearms behind the head'));
      expect('${drawn.first['prompt']}', isNot(contains('a bar behind')));
      expect('${drawn.last['prompt']}', contains('stretched straight up'));
    });

    test('de coach kan de twee zinnen apart schrijven', () async {
      // Apart gevraagd, met alleen die opdracht ervoor: dan leest hij de
      // regels niet voorbij terwijl hij ook een oefening zit te bedenken.
      late String askedSystem;
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appPathsProvider.overrideWith((ref) => AppPaths(home)),
          coachClientFactoryProvider.overrideWithValue(
            (apiKey, provider) => AiClient(
              apiKey: apiKey,
              provider: provider,
              client: MockClient((request) async {
                final body = jsonDecode(request.body) as Map<String, Object?>;
                askedSystem = jsonEncode(body['systemInstruction']);
                return http.Response(
                  jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {
                              'text':
                                  '```json'
                                  '${jsonEncode({'start': 'Side view A', 'end': 'Side view B'})}'
                                  '```',
                            },
                          ],
                        },
                      },
                    ],
                    'usageMetadata': {
                      'promptTokenCount': 120,
                      'candidatesTokenCount': 30,
                    },
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          ),
        ],
      );
      final message = await drawable();

      final (start, end) = await container!
          .read(coachControllerProvider.notifier)
          .writeFramePrompts(
            messageId: message.id,
            name: 'Overhead triceps extension',
            equipment: 'cable',
          );

      expect(start, 'Side view A');
      expect(end, 'Side view B');
      // De opdracht die we duur geleerd hebben, staat erin.
      expect(askedSystem, contains('optrekbeweging'));
      // En wat het kostte staat bij het antwoord waar het bij hoort, anders
      // liegt de balk in de instellingen.
      final stored = (await db.chatDao.messages('t-1')).single;
      expect(stored.requests, 2);
      expect(stored.inputTokens, 120);
    });

    test('en zonder die knop wordt er niets getekend', () async {
      container = newContainer();
      final coach = container!.read(coachControllerProvider.notifier);

      final id = await coach.accept(message: await drawable(), index: 0);

      expect(drawn, isEmpty);
      expect((await db.exercisesDao.getById(id!))!.imagesGenerated, isFalse);
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

  group('de tekeningen bij een voorstel', () {
    test('de coach geeft zijn eigen beschrijvingen mee', () async {
      final lookup = await tools.run('propose_exercise', {
        'name': 'Sledepush',
        'primary_muscle': 'benen',
        'start_image_prompt': 'A person crouched behind a loaded sled',
        'end_image_prompt': 'The same person leaning forward, sled moved',
      });

      final proposal = lookup.proposal!.exercise!;
      expect(proposal.startImagePrompt, contains('crouched'));
      expect(proposal.endImagePrompt, contains('leaning forward'));
      expect(proposal.canBeDrawn, isTrue);
    });

    test('en zonder die twee valt er niets te tekenen', () async {
      final lookup = await tools.run('propose_exercise', {
        'name': 'Sledepush',
        'primary_muscle': 'benen',
      });

      expect(lookup.proposal!.exercise!.canBeDrawn, isFalse);
    });

    test('ze overleven opschrijven en teruglezen', () {
      final read = parseProposals(
        encodeProposals([
          CoachProposal.ofExercise(
            const ExerciseProposal(
              name: 'Sledepush',
              primaryMuscle: 'benen',
              startImagePrompt: 'start',
              endImagePrompt: 'eind',
            ),
          ),
        ]),
      );

      expect(read.single.exercise!.startImagePrompt, 'start');
      expect(read.single.exercise!.endImagePrompt, 'eind');
    });
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
