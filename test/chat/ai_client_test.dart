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
    model: CoachModel.defaultFor(client.provider).wire,
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

    test('de lichte Gemini 3-modellen zijn de aanbevolen', () {
      expect(isRecommendedModel('gemini-3.5-flash-lite'), isTrue);
      expect(isRecommendedModel('gemini-3.1-flash-lite'), isTrue);
      // Ook een variant die er later bijkomt.
      expect(isRecommendedModel('gemini-3.7-flash-lite-preview'), isTrue);

      expect(isRecommendedModel('gemini-3-pro'), isFalse);
      // Een beeldmodel is nooit aanbevolen, ook niet met flash-lite erin.
      expect(isRecommendedModel('gemini-3-flash-lite-image-preview'), isFalse);
      expect(isRecommendedModel('gemini-2.5-flash-lite'), isFalse);
      expect(isRecommendedModel('claude-sonnet-5'), isFalse);
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

  group('welke modellen een sleutel mag gebruiken', () {
    test('worden bij Google opgevraagd, niet uit de app gehaald', () async {
      // Modelnamen veranderen sneller dan deze app uitkomt; wie een sleutel
      // heeft die een nieuw model aankan, moet het kunnen kiezen.
      final client = clientThatAnswers(200, {
        'models': [
          {
            'name': 'models/gemini-3.5-flash-lite',
            'displayName': 'Gemini 3.5 Flash Lite',
            'description': 'Snel en goedkoop.',
            'supportedGenerationMethods': ['generateContent', 'countTokens'],
          },
          {
            'name': 'models/gemini-2.5-flash',
            'displayName': 'Gemini 2.5 Flash',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
      }, key: 'AIzaSyGeheim123');

      final models = await client.listModels();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), contains('/v1beta/models'));
      expect(sent.headers['x-goog-api-key'], 'AIzaSyGeheim123');

      // Nieuwste eerst, voor zover een naam dat kan zeggen.
      expect(models.first.wire, 'gemini-3.5-flash-lite');
      expect(models.first.label, 'Gemini 3.5 Flash Lite');
      expect(models.map((m) => m.wire), contains('gemini-2.5-flash'));
    });

    test('en wat deze app niet kan gebruiken valt weg', () async {
      final client = clientThatAnswers(200, {
        'models': [
          {
            'name': 'models/text-embedding-004',
            'supportedGenerationMethods': ['embedContent'],
          },
          {
            'name': 'models/imagen-4.0',
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/gemini-3-pro',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
      }, key: 'AIzaSyGeheim123');

      final models = await client.listModels();

      expect(models.map((m) => m.wire), ['gemini-3-pro']);
    });

    test('ook de beeldmodellen, hoe licht ze ook heten', () async {
      // Nano Banana antwoordt op generateContent met een plaatje. Het is
      // geen coach, en het hoort dus zeker niet onder "Aanbevolen".
      final client = clientThatAnswers(200, {
        'models': [
          {
            'name': 'models/gemini-3-flash-lite-image-preview',
            'displayName': 'Nano Banana 2 Lite',
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/gemini-3-pro-image-preview',
            'displayName': 'Nano Banana Pro',
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/gemini-3.5-flash-lite',
            'displayName': 'Gemini 3.5 Flash Lite',
            'supportedGenerationMethods': ['generateContent'],
          },
        ],
      }, key: 'AIzaSyGeheim123');

      final models = await client.listModels();

      expect(models.map((m) => m.wire), ['gemini-3.5-flash-lite']);
    });

    test('en een beeldmodel dat alleen aan zijn naam te zien is ook', () {
      // Zou de id niets verraden, dan doet de naam het.
      expect(
        isChatModel('gemini-3-flash-lite-x', 'Nano Banana 2 Lite'),
        isFalse,
      );
      expect(
        isRecommendedModel('gemini-3-flash-lite-x', 'Nano Banana 2 Lite'),
        isFalse,
      );
      expect(
        isRecommendedModel('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
        isTrue,
      );
    });

    test(
      'bij Anthropic komt het uit data, met de versie in de header',
      () async {
        final client = clientThatAnswers(200, {
          'data': [
            {'type': 'model', 'id': 'claude-opus-5', 'display_name': 'Opus 5'},
          ],
        });

        final models = await client.listModels();

        expect(sent.headers['anthropic-version'], kAnthropicVersion);
        expect(models.single.wire, 'claude-opus-5');
        expect(models.single.label, 'Opus 5');
      },
    );

    test('een geweigerde sleutel zegt dat ook hier', () async {
      final client = clientThatAnswers(401, {
        'error': {'message': 'invalid'},
      });

      await expectLater(
        client.listModels(),
        throwsA(
          isA<CoachException>().having((e) => e.badKey, 'badKey', isTrue),
        ),
      );
    });

    test('en een model dat de app niet kent blijft gewoon staan', () {
      // Precies waar dit allemaal om draait: een naam van na deze versie.
      expect(
        CoachModel.resolveWire('gemini-3.5-flash-lite', CoachProvider.gemini),
        'gemini-3.5-flash-lite',
      );
      expect(
        CoachModel.resolveWire(null, CoachProvider.gemini),
        CoachModel.geminiFlash.wire,
      );
      expect(
        CoachModel.resolveWire('  ', CoachProvider.anthropic),
        CoachModel.sonnet.wire,
      );
      expect(
        CoachModel.labelFor('gemini-3.5-flash-lite', CoachProvider.gemini),
        'gemini-3.5-flash-lite',
      );
      expect(
        CoachModel.labelFor('claude-sonnet-5', CoachProvider.anthropic),
        'Sonnet 5',
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
        model: CoachModel.sonnet.wire,
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
        model: CoachModel.geminiFlash.wire,
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

    test('een thought signature komt mee en gaat onveranderd terug', () async {
      // De Gemini 3-modellen weigeren een gesprek waarin een functionCall
      // zonder zijn signature terugkomt: "Function call is missing a
      // thought_signature".
      final client = gemini({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'Even kijken.', 'thoughtSignature': 'sig-tekst'},
                {
                  'functionCall': {
                    'name': 'search_exercises',
                    'args': {'query': 'pec fly'},
                  },
                  'thoughtSignature': 'sig-call',
                },
              ],
            },
          },
        ],
        'usageMetadata': {'promptTokenCount': 10, 'candidatesTokenCount': 5},
      });

      final reply = await ask(client);

      expect(reply.toolCalls.single.signature, 'sig-call');
      expect(reply.textSignature, 'sig-tekst');

      // En terug de deur uit, op dezelfde delen.
      const call = CoachToolCall(
        id: '',
        name: 'search_exercises',
        input: <String, Object?>{},
        signature: 'sig-call',
      );
      await client.send(
        system: 'x',
        messages: [
          CoachMessage.user('Staat pec fly in de catalogus?'),
          const CoachMessage.assistant(
            text: 'Even kijken.',
            toolCalls: [call],
            textSignature: 'sig-tekst',
          ),
          const CoachMessage.results([
            CoachToolResult(call: call, json: '{"exercises":[]}'),
          ]),
        ],
        tools: const [searchTool],
        model: CoachModel.geminiFlash.wire,
      );

      final parts =
          ((jsonDecode(sent.body) as Map)['contents'] as List)[1]
              as Map<String, Object?>;
      final written = parts['parts']! as List;
      expect((written.first as Map)['thoughtSignature'], 'sig-tekst');
      expect((written[1] as Map)['thoughtSignature'], 'sig-call');
    });

    test('en zonder signature staat er ook geen lege sleutel in', () async {
      final client = gemini(saying('ok'));

      const call = CoachToolCall(
        id: '',
        name: 'routines',
        input: <String, Object?>{},
      );
      await client.send(
        system: 'x',
        messages: [
          CoachMessage.user('En?'),
          const CoachMessage.assistant(toolCalls: [call]),
        ],
        tools: const [noArgsTool],
        model: CoachModel.geminiFlash.wire,
      );

      expect(sent.body, isNot(contains('thoughtSignature')));
    });

    test('een geweigerde prompt is een leesbare fout', () async {
      final client = gemini({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });

      await expectLater(ask(client), throwsA(isA<CoachException>()));
    });
  });

  group('een foto bij de vraag', () {
    const photo = CoachImage(base64: 'AAAAfoto');

    test('gaat bij Anthropic mee als image-blok, voor de tekst', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'Dat is een lat pulldown.'},
        ],
      });

      await client.send(
        system: 'x',
        messages: [CoachMessage.user('Wat is dit?', image: photo)],
        tools: const [],
        model: CoachModel.sonnet.wire,
      );

      final content =
          ((jsonDecode(sent.body) as Map)['messages'] as List).single
              as Map<String, Object?>;
      final blocks = content['content']! as List;
      expect((blocks.first as Map)['type'], 'image');
      expect(
        ((blocks.first as Map)['source']! as Map)['media_type'],
        'image/jpeg',
      );
      expect((blocks[1] as Map)['text'], 'Wat is dit?');
    });

    test('en bij Google als inlineData', () async {
      final client = clientThatAnswers(200, {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Dat is een lat pulldown.'},
              ],
            },
          },
        ],
      }, key: 'AIzaSyGeheim123');

      await client.send(
        system: 'x',
        messages: [CoachMessage.user('Wat is dit?', image: photo)],
        tools: const [],
        model: CoachModel.geminiFlash.wire,
      );

      final parts =
          ((jsonDecode(sent.body) as Map)['contents'] as List).single
              as Map<String, Object?>;
      final first = (parts['parts']! as List).first as Map<String, Object?>;
      expect((first['inlineData']! as Map)['mimeType'], 'image/jpeg');
      expect((first['inlineData']! as Map)['data'], 'AAAAfoto');
    });

    test('en zonder foto blijft een vraag gewone tekst', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      });

      await ask(client);

      final message =
          ((jsonDecode(sent.body) as Map)['messages'] as List).single
              as Map<String, Object?>;
      expect(message['content'], isA<String>());
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
