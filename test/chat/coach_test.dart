import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach asking the app about you, and the app answering.
///
/// No request leaves this process: the "API" here is a list of canned replies
/// and the database is a real one, in memory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  /// Every request body the client tried to send, in order.
  late List<Map<String, Object?>> sent;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
  });

  tearDown(() async {
    await db.close();
  });

  /// A client that answers with [replies] in turn.
  AiClient clientSaying(List<Object> replies) {
    var next = 0;
    return AiClient(
      apiKey: 'sk-ant-test',
      client: MockClient((request) async {
        sent.add(jsonDecode(request.body) as Map<String, Object?>);
        final reply =
            replies[next < replies.length ? next : replies.length - 1];
        next++;
        return http.Response(
          jsonEncode(reply),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  Map<String, Object?> says(String text, {int input = 100, int output = 20}) =>
      {
        'content': [
          {'type': 'text', 'text': text},
        ],
        'usage': {'input_tokens': input, 'output_tokens': output},
      };

  Map<String, Object?> asksFor(
    String tool,
    Map<String, Object?> input, {
    String id = 'toolu_1',
  }) => {
    'content': [
      {'type': 'tool_use', 'id': id, 'name': tool, 'input': input},
    ],
    'usage': {'input_tokens': 200, 'output_tokens': 30},
  };

  Coach coachWith(AiClient client) => Coach(
    client: client,
    tools: CoachTools(db),
    model: CoachModel.sonnet.wire,
    system: buildCoachPrompt(now: DateTime(2026, 3, 2), weightUnit: 'kg'),
  );

  Future<void> seedWorkout({
    required String exercise,
    required double weight,
    required int reps,
    DateTime? on,
  }) async {
    final at = (on ?? DateTime(2026, 2, 27)).millisecondsSinceEpoch;
    final id = '$exercise-$at';
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-$exercise',
            name: exercise,
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-$id',
            name: 'Push',
            startedAt: at,
            endedAt: Value(at + 3600000),
            durationSeconds: const Value(3600),
            totalVolumeKg: Value(weight * reps),
            totalSets: const Value(1),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$id',
            workoutId: 'w-$id',
            exerciseId: 'ex-$exercise',
            sortOrder: 0,
          ),
        );
    await db
        .into(db.workoutSetsTable)
        .insert(
          WorkoutSetsTableCompanion.insert(
            id: 'ws-$id',
            workoutExerciseId: 'we-$id',
            sortOrder: 0,
            setType: const Value('normal'),
            weightKg: Value(weight),
            reps: Value(reps),
            isCompleted: const Value(true),
            completedAt: Value(at),
          ),
        );
  }

  group('a plain question', () {
    test('goes out once and comes back as an answer', () async {
      final coach = coachWith(
        clientSaying([says('Tussen 10 en 20 sets per week.')]),
      );

      final answer = await coach.ask(
        history: const [],
        question: 'Hoeveel sets voor borst?',
      );

      expect(answer.text, 'Tussen 10 en 20 sets per week.');
      expect(answer.lookups, isEmpty);
      expect(sent, hasLength(1));
      // Nothing about the user rides along uninvited.
      expect(sent.single['system'], isNot(contains('Bench')));
    });

    test('and the tools are offered, but nothing is forced', () async {
      final coach = coachWith(clientSaying([says('Ja.')]));

      await coach.ask(history: const [], question: 'Is 3x8 genoeg?');

      final tools = sent.single['tools']! as List<Object?>;
      expect(tools, hasLength(CoachTools.names.length));
      expect(
        tools.map((t) => (t! as Map<String, Object?>)['name']).toSet(),
        CoachTools.names,
      );
    });
  });

  group('a question about the user', () {
    test('is answered after the coach looks it up', () async {
      await seedWorkout(exercise: 'Bench Press', weight: 80, reps: 5);

      final coach = coachWith(
        clientSaying([
          asksFor('recent_workouts', {'limit': 3}),
          says('Je laatste sessie was Push, met 80 kg voor 5.'),
        ]),
      );

      final answer = await coach.ask(
        history: const [],
        question: 'Hoe ging mijn laatste sessie?',
      );

      expect(answer.text, contains('80 kg'));
      expect(answer.lookups, ['je laatste 1 sessie']);
      expect(sent, hasLength(2));

      // The second request carries the assistant's tool request and the
      // result of running it.
      final follow = sent[1]['messages']! as List<Object?>;
      expect(follow, hasLength(3));
      expect('${follow[2]}', contains('tool_result'));
      expect('${follow[2]}', contains('Bench Press'));
    });

    test('the tokens of every round are added up', () async {
      final coach = coachWith(
        clientSaying([
          asksFor('routines', const {}),
          says('Je hebt nog geen routines.', input: 500, output: 25),
        ]),
      );

      final answer = await coach.ask(
        history: const [],
        question: 'Welke routines heb ik?',
      );

      expect(answer.usage.inputTokens, 700);
      expect(answer.usage.outputTokens, 55);
    });

    test('two lookups in one turn are both reported', () async {
      final coach = coachWith(
        clientSaying([
          {
            'content': [
              {
                'type': 'tool_use',
                'id': 'a',
                'name': 'routines',
                'input': <String, Object?>{},
              },
              {
                'type': 'tool_use',
                'id': 'b',
                'name': 'personal_records',
                'input': <String, Object?>{},
              },
            ],
            'usage': {'input_tokens': 10, 'output_tokens': 10},
          },
          says('Klaar.'),
        ]),
      );

      final answer = await coach.ask(history: const [], question: 'Overzicht?');

      expect(answer.lookups, ['je routines', 'je persoonlijke records']);
    });

    test('a tool it invented does not break the turn', () async {
      final coach = coachWith(
        clientSaying([
          asksFor('lees_mijn_email', const {}),
          says('Daar kan ik niet bij.'),
        ]),
      );

      final answer = await coach.ask(history: const [], question: 'En?');

      expect(answer.text, 'Daar kan ik niet bij.');
      expect(answer.lookups.single, contains('bestaat'));
      expect('${sent[1]['messages']}', contains('onbekende tool'));
    });
  });

  group('met een Gemini-sleutel', () {
    /// The same conversation, in Google's shapes.
    AiClient geminiSaying(List<Object> replies) {
      var next = 0;
      return AiClient(
        apiKey: 'AIzaSyTest',
        client: MockClient((request) async {
          sent.add(jsonDecode(request.body) as Map<String, Object?>);
          final reply =
              replies[next < replies.length ? next : replies.length - 1];
          next++;
          return http.Response(
            jsonEncode(reply),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    }

    Map<String, Object?> geminiSays(String text) => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
      'usageMetadata': {'promptTokenCount': 400, 'candidatesTokenCount': 20},
    };

    Map<String, Object?> geminiAsksFor(
      String tool,
      Map<String, Object?> args,
    ) => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {
                'functionCall': {'name': tool, 'args': args},
              },
            ],
          },
        },
      ],
      'usageMetadata': {'promptTokenCount': 300, 'candidatesTokenCount': 10},
    };

    test('loopt dezelfde lus, met dezelfde opzoekingen', () async {
      await seedWorkout(exercise: 'Bench Press', weight: 80, reps: 5);

      final coach = Coach(
        client: geminiSaying([
          geminiAsksFor('recent_workouts', {'limit': 3}),
          geminiSays('Je laatste sessie was Push, met 80 kg voor 5.'),
        ]),
        tools: CoachTools(db),
        model: CoachModel.geminiFlash.wire,
        system: buildCoachPrompt(now: DateTime(2026, 3, 2), weightUnit: 'kg'),
      );

      final answer = await coach.ask(
        history: const [],
        question: 'Hoe ging mijn laatste sessie?',
      );

      expect(answer.text, contains('80 kg'));
      expect(answer.lookups, ['je laatste 1 sessie']);
      expect(answer.usage.inputTokens, 700);

      // De tweede vraag draagt de functionCall en het antwoord erop, in
      // Google's vorm.
      final contents = sent[1]['contents']! as List;
      expect(contents, hasLength(3));
      expect('${contents[1]}', contains('functionCall'));
      expect('${contents[2]}', contains('functionResponse'));
      expect('${contents[2]}', contains('Bench Press'));
    });

    test('en een signature overleeft de hele lus', () async {
      // Wat er misging bij Gemini 3: de app stuurde de functionCall terug
      // zonder de signature en kreeg de vraag afgewezen.
      await seedWorkout(exercise: 'Pec Fly', weight: 40, reps: 12);

      final coach = Coach(
        client: geminiSaying([
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'functionCall': {
                        'name': 'search_exercises',
                        'args': {'query': 'pec fly'},
                      },
                      'thoughtSignature': 'sig-1',
                    },
                  ],
                },
              },
            ],
            'usageMetadata': {
              'promptTokenCount': 10,
              'candidatesTokenCount': 5,
            },
          },
          geminiSays('Ja, Pec Fly staat erin.'),
        ]),
        tools: CoachTools(db),
        model: CoachModel.geminiFlash.wire,
        system: buildCoachPrompt(now: DateTime(2026, 3, 2), weightUnit: 'kg'),
      );

      final answer = await coach.ask(
        history: const [],
        question: 'Staat pec fly in de catalogus?',
      );

      expect(answer.text, contains('Pec Fly'));
      expect('${sent[1]['contents']}', contains('sig-1'));
    });

    test('en het gereedschap gaat mee als functionDeclarations', () async {
      final coach = Coach(
        client: geminiSaying([geminiSays('Ja.')]),
        tools: CoachTools(db),
        model: CoachModel.geminiFlash.wire,
        system: buildCoachPrompt(now: DateTime(2026, 3, 2), weightUnit: 'kg'),
      );

      await coach.ask(history: const [], question: 'Is 3x8 genoeg?');

      final declarations =
          ((sent.single['tools']! as List).single
                  as Map<String, Object?>)['functionDeclarations']!
              as List;
      expect(
        declarations.map((d) => (d! as Map<String, Object?>)['name']).toSet(),
        CoachTools.names,
      );
    });
  });

  group('the ceiling', () {
    test(
      'a coach that keeps looking things up has to answer eventually',
      () async {
        // Always asking, never answering.
        final coach = coachWith(clientSaying([asksFor('routines', const {})]));

        final answer = await coach.ask(
          history: const [],
          question: 'Hoe gaat het?',
        );

        expect(sent, hasLength(Coach.maxToolRounds + 1));
        expect(answer.text, contains('nauwer'));
      },
    );

    test('and a long conversation does not grow without end', () async {
      final history = [
        for (var i = 0; i < 40; i++)
          CoachTurn(role: i.isEven ? 'user' : 'assistant', text: 'bericht $i'),
      ];
      final coach = coachWith(clientSaying([says('ok')]));

      await coach.ask(history: history, question: 'En nu?');

      final messages = sent.single['messages']! as List<Object?>;
      expect(messages, hasLength(Coach.historyTurns + 1));
      // The oldest turns are the ones dropped.
      expect('${messages.first}', contains('bericht 20'));
    });
  });

  group('the prompt', () {
    test('says what the app is and what the coach is for', () {
      final prompt = buildCoachPrompt(
        now: DateTime(2026, 3, 2),
        weightUnit: 'kg',
        displayName: 'Kobe',
        exerciseCount: 900,
      );

      expect(prompt, contains('FitLog'));
      expect(prompt, contains('maandag 2026-03-02'));
      expect(prompt, contains('Kobe'));
      expect(prompt, contains('900 oefeningen'));
      // The two guard rails that matter most.
      expect(prompt, contains('geen arts'));
      expect(prompt, contains('gok nooit'));
      // En dat het zelf niets aanmaakt.
      expect(prompt, contains('propose_exercise'));
      expect(prompt, contains('gebruiker tikt zelf'));
    });

    test('and carries no data about the user beyond their name', () {
      final prompt = buildCoachPrompt(
        now: DateTime(2026, 3, 2),
        weightUnit: 'kg',
      );

      expect(prompt, isNot(contains('kg 80')));
      // Een budget, geen toevalligheid: dit gaat mee met elke vraag en de
      // gebruiker betaalt het per keer. Groeit het hierlangs, dan is dat een
      // beslissing en geen ongeluk.
      expect(prompt.length, lessThan(4300));
    });
  });
}
