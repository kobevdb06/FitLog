import 'dart:convert';
import 'dart:io';

import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The one door in the app, tested without opening it.
///
/// Every request here is answered by a client that never leaves this process.
/// Two services are behind that door, and the point of most of these tests is
/// that the app above it cannot tell which one it is talking to.
void main() {
  /// The last request the client tried to send.
  late http.Request sent;

  AiClient clientThatAnswers(
    int status,
    Object? body, {
    String key = 'sk-ant-geheim-abc123',
    Duration delay = Duration.zero,
  }) {
    return AiClient(
      apiKey: key,
      timeout: const Duration(milliseconds: 200),
      client: MockClient((request) async {
        sent = request;
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        return http.Response(
          body is String ? body : jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  Future<CoachReply> ask(
    AiClient client, {
    List<Map<String, Object?>> tools = const [],
  }) => client.send(
    system: 'Je bent een coach.',
    messages: [CoachMessage.user('Hoeveel sets voor borst?')],
    tools: tools,
    model: CoachModel.defaultFor(client.provider),
  );

  const searchTool = {
    'name': 'search_exercises',
    'description': 'Zoek oefeningen.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
      },
    },
  };

  const noArgsTool = {
    'name': 'routines',
    'description': 'De routines.',
    'input_schema': {'type': 'object', 'properties': <String, Object?>{}},
  };

  group('welke dienst een sleutel hoort', () {
    test('wordt van de sleutel zelf afgeleid', () {
      expect(CoachProvider.forKey('sk-ant-abc'), CoachProvider.anthropic);
      expect(CoachProvider.forKey('AIzaSyAbc'), CoachProvider.gemini);
      expect(CoachProvider.forKey('  AIzaSyAbc  '), CoachProvider.gemini);
    });

    test('ook het nieuwere formaat van Google', () {
      // AQ.Ab8... is wat AI Studio tegenwoordig uitdeelt, en dat werd eerst
      // voor een Anthropic-sleutel aangezien.
      expect(CoachProvider.forKey('AQ.Ab8RNiZhX2Mkg'), CoachProvider.gemini);
    });

    test('en alleen het prefix van Anthropic is onmiskenbaar', () {
      // Google verzint nieuwe vormen, Anthropic niet: al de rest is dus een
      // betere gok als Google, en de gebruiker kan het rechtzetten.
      expect(CoachProvider.forKey('hallo'), CoachProvider.gemini);
      expect(CoachProvider.forKey(''), CoachProvider.gemini);
    });

    test('een opgeslagen keuze is terug te lezen', () {
      expect(CoachProvider.fromWire('gemini'), CoachProvider.gemini);
      expect(CoachProvider.fromWire('anthropic'), CoachProvider.anthropic);
      expect(CoachProvider.fromWire(null), isNull);
      expect(CoachProvider.fromWire('openai'), isNull);
    });

    test('een model van de andere dienst valt terug op de standaard', () {
      expect(
        CoachModel.resolve('claude-opus-5', CoachProvider.gemini),
        CoachModel.geminiFlash,
      );
      expect(
        CoachModel.resolve('gemini-2.5-pro', CoachProvider.gemini),
        CoachModel.geminiPro,
      );
      expect(
        CoachModel.resolve(null, CoachProvider.anthropic),
        CoachModel.sonnet,
      );
    });
  });

  group('Anthropic', () {
    test('één adres, de sleutel in de header, niets in de URL', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'Tussen 10 en 20 per week.'},
        ],
        'usage': {'input_tokens': 800, 'output_tokens': 40},
      });

      await ask(client);

      expect(sent.url.toString(), CoachProvider.anthropic.endpoint);
      expect(sent.url.query, isEmpty);
      expect(sent.headers['x-api-key'], 'sk-ant-geheim-abc123');
      expect(sent.headers['anthropic-version'], kAnthropicVersion);
      expect(sent.body, isNot(contains('sk-ant')));
    });

    test('de tekst, en wat ze kostte', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'Tussen 10 en 20 sets per week.'},
        ],
        'usage': {'input_tokens': 812, 'output_tokens': 44},
      });

      final reply = await ask(client);

      expect(reply.text, 'Tussen 10 en 20 sets per week.');
      expect(reply.wantsTools, isFalse);
      expect(reply.usage.inputTokens, 812);
      expect(reply.usage.outputTokens, 44);
    });

    test('een vraag om iets op te zoeken, met haar id', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'Even kijken.'},
          {
            'type': 'tool_use',
            'id': 'toolu_1',
            'name': 'recent_workouts',
            'input': {'limit': 5},
          },
        ],
        'usage': {'input_tokens': 900, 'output_tokens': 60},
      });

      final reply = await ask(client);

      expect(reply.wantsTools, isTrue);
      expect(reply.toolCalls.single.id, 'toolu_1');
      expect(reply.toolCalls.single.name, 'recent_workouts');
      expect(reply.toolCalls.single.input['limit'], 5);
      expect(reply.text, 'Even kijken.');
    });

    test('en het antwoord daarop gaat terug met datzelfde id', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      });

      const call = CoachToolCall(
        id: 'toolu_1',
        name: 'routines',
        input: <String, Object?>{},
      );
      await client.send(
        system: 'x',
        messages: [
          CoachMessage.user('En?'),
          const CoachMessage.assistant(text: 'Even kijken.', toolCalls: [call]),
          const CoachMessage.results([
            CoachToolResult(call: call, json: '{"routines":[]}'),
          ]),
        ],
        tools: const [searchTool],
        model: CoachModel.sonnet,
      );

      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect('${body['messages']}', contains('tool_use'));
      expect('${body['messages']}', contains('tool_result'));
      expect('${body['messages']}', contains('toolu_1'));
      // Het gereedschap gaat mee zoals Anthropic het wil.
      expect('${body['tools']}', contains('input_schema'));
    });
  });

  group('Gemini', () {
    AiClient gemini(Object body, {int status = 200}) =>
        clientThatAnswers(status, body, key: 'AIzaSyGeheim123');

    Map<String, Object?> saying(String text) => {
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
      'usageMetadata': {'promptTokenCount': 700, 'candidatesTokenCount': 50},
    };

    test('het model staat in het adres, de sleutel in de header', () async {
      final client = gemini(saying('Tussen 10 en 20 per week.'));

      await ask(client);

      expect(
        sent.url.toString(),
        '${CoachProvider.gemini.endpoint}/gemini-2.5-flash:generateContent',
      );
      // Een sleutel in de URL komt in logboeken terecht; deze niet.
      expect(sent.url.query, isEmpty);
      expect(sent.headers['x-goog-api-key'], 'AIzaSyGeheim123');
      expect(sent.body, isNot(contains('AIza')));
    });

    test('de tekst en de tokens komen uit hun eigen velden', () async {
      final reply = await ask(gemini(saying('Tussen 10 en 20 per week.')));

      expect(reply.text, 'Tussen 10 en 20 per week.');
      expect(reply.usage.inputTokens, 700);
      expect(reply.usage.outputTokens, 50);
    });

    test('de vraag gaat als contents met een systemInstruction', () async {
      await ask(gemini(saying('ok')));

      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect('${body['systemInstruction']}', contains('Je bent een coach'));
      final contents = body['contents']! as List;
      expect((contents.single as Map)['role'], 'user');
      expect('${contents.single}', contains('Hoeveel sets'));
      expect((body['generationConfig']! as Map)['maxOutputTokens'], 1024);
    });

    test('een functionCall leest als een opzoeking', () async {
      final client = gemini({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'Even kijken.'},
                {
                  'functionCall': {
                    'name': 'recent_workouts',
                    'args': {'limit': 5},
                  },
                },
              ],
            },
          },
        ],
        'usageMetadata': {'promptTokenCount': 10, 'candidatesTokenCount': 5},
      });

      final reply = await ask(client);

      expect(reply.toolCalls.single.name, 'recent_workouts');
      expect(reply.toolCalls.single.input['limit'], 5);
      // Google koppelt op naam, niet op id.
      expect(reply.toolCalls.single.id, isEmpty);
    });

    test('en het antwoord erop gaat terug als functionResponse', () async {
      final client = gemini(saying('Je hebt nog geen routines.'));

      const call = CoachToolCall(
        id: '',
        name: 'routines',
        input: <String, Object?>{},
      );
      await client.send(
        system: 'x',
        messages: [
          CoachMessage.user('Welke routines heb ik?'),
          const CoachMessage.assistant(toolCalls: [call]),
          const CoachMessage.results([
            CoachToolResult(call: call, json: '{"routines":[]}'),
          ]),
        ],
        tools: const [searchTool, noArgsTool],
        model: CoachModel.geminiFlash,
      );

      final body = jsonDecode(sent.body) as Map<String, Object?>;
      final contents = body['contents']! as List;
      expect((contents[1] as Map)['role'], 'model');
      expect('${contents[1]}', contains('functionCall'));
      expect('${contents[2]}', contains('functionResponse'));
      expect('${contents[2]}', contains('routines'));
    });

    test('gereedschap gaat mee als functionDeclarations', () async {
      await ask(gemini(saying('ok')), tools: const [searchTool, noArgsTool]);

      final body = jsonDecode(sent.body) as Map<String, Object?>;
      final declarations =
          ((body['tools']! as List).single as Map)['functionDeclarations']!
              as List;
      expect(declarations, hasLength(2));

      final search = declarations.first as Map<String, Object?>;
      expect(search['name'], 'search_exercises');
      expect('${search['parameters']}', contains('query'));

      // Een tool zonder argumenten krijgt geen leeg parameters-object: dat
      // wijst die API af.
      final routines = declarations[1] as Map<String, Object?>;
      expect(routines.containsKey('parameters'), isFalse);
    });

    test('een geweigerde prompt is een leesbare fout', () async {
      final client = gemini({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });

      await expectLater(ask(client), throwsA(isA<CoachException>()));
    });
  });

  group('als het misgaat', () {
    test('een geweigerde sleutel wijst naar de instellingen', () async {
      final client = clientThatAnswers(401, {
        'error': {'message': 'invalid x-api-key'},
      });

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>()
              .having((e) => e.badKey, 'badKey', isTrue)
              .having((e) => e.message, 'message', contains('Instellingen')),
        ),
      );
    });

    test('ook als Google dat met een 400 zegt', () async {
      // Google antwoordt op een slechte sleutel met 400, niet met 401.
      final client = clientThatAnswers(400, {
        'error': {'message': 'API key not valid. Please pass a valid API key.'},
      }, key: 'AIzaFout');

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>().having((e) => e.badKey, 'badKey', isTrue),
        ),
      );
    });

    test('een limiet is geen kapotte sleutel', () async {
      final client = clientThatAnswers(429, {
        'error': {'message': 'rate limit'},
      });

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>()
              .having((e) => e.badKey, 'badKey', isFalse)
              .having((e) => e.message, 'message', contains('gratis limiet')),
        ),
      );
    });

    test('een foutmelding draagt nooit de sleutel terug', () async {
      for (final (key, secret) in [
        ('sk-ant-geheim-abc123', 'sk-ant-geheim-abc123'),
        ('AIzaSyGeheim123', 'AIzaSyGeheim123'),
      ]) {
        final client = clientThatAnswers(400, {
          'error': {'message': 'bad request met $secret erin'},
        }, key: key);

        try {
          await ask(client);
          fail('had moeten falen');
        } on CoachException catch (error) {
          expect(error.message, isNot(contains('Geheim')));
          expect(error.message, isNot(contains(secret)));
        }
      }
    });

    test('een overbelaste dienst vraagt om geduld', () async {
      await expectLater(
        ask(clientThatAnswers(529, '')),
        throwsA(
          isA<CoachException>().having(
            (e) => e.message,
            'message',
            contains('overbelast'),
          ),
        ),
      );
    });

    test('onzin terug is een nette fout, geen crash', () async {
      await expectLater(
        ask(clientThatAnswers(200, 'dit is geen json')),
        throwsA(isA<CoachException>()),
      );
    });

    test('geen verbinding zegt dat de rest van de app blijft werken', () async {
      final client = AiClient(
        apiKey: 'sk-ant-test',
        client: MockClient(
          (_) async => throw const SocketException('no route to host'),
        ),
      );

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>().having(
            (e) => e.message,
            'message',
            contains('werkt gewoon verder'),
          ),
        ),
      );
    });

    test('en te lang wachten geeft het op', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'traag'},
        ],
      }, delay: const Duration(seconds: 1));

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>().having(
            (e) => e.message,
            'message',
            contains('niet op tijd'),
          ),
        ),
      );
    });
  });
}
