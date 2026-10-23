import 'dart:async';
import 'dart:convert';

import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach's answer while it is being written: Google sends it as
/// server-sent events, and the app hands every piece on as it comes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late http.BaseRequest sent;

  /// One server-sent event per chunk, cut into [cuts] byte pieces to show
  /// that an event split over two network packets still reads as one.
  AiClient streaming(
    List<Map<String, Object?>> chunks, {
    int status = 200,
    int cuts = 1,
  }) {
    final body = utf8.encode(
      [for (final chunk in chunks) 'data: ${jsonEncode(chunk)}\r\n\r\n'].join(),
    );
    final size = (body.length / cuts).ceil();
    return AiClient(
      apiKey: 'AIzaSyGeheim123',
      provider: CoachProvider.gemini,
      timeout: const Duration(seconds: 2),
      client: MockClient.streaming((request, _) async {
        sent = request;
        return http.StreamedResponse(
          Stream.fromIterable([
            for (var i = 0; i < body.length; i += size)
              body.sublist(i, i + size > body.length ? body.length : i + size),
          ]),
          status,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
  }

  Map<String, Object?> text(String piece, {Map<String, Object?>? usage}) => {
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': piece},
          ],
        },
      },
    ],
    'usageMetadata': ?usage,
  };

  Future<CoachReply> ask(AiClient client, List<String> pieces) =>
      client.sendStreaming(
        system: 'x',
        messages: [CoachMessage.user('Hoeveel sets?')],
        tools: const [],
        model: 'gemini-2.5-flash',
        onText: pieces.add,
      );

  test('elk stukje komt door zodra het er is, en samen zijn ze het '
      'antwoord', () async {
    final pieces = <String>[];
    final reply = await ask(
      streaming([
        text('Tussen tien '),
        text('en twintig sets '),
        text(
          'per week.',
          usage: {'promptTokenCount': 900, 'candidatesTokenCount': 12},
        ),
      ]),
      pieces,
    );

    expect(pieces, ['Tussen tien ', 'en twintig sets ', 'per week.']);
    expect(reply.text, 'Tussen tien en twintig sets per week.');
    expect(reply.usage.inputTokens, 900);
    expect(reply.usage.outputTokens, 12);
    expect(reply.wantsTools, isFalse);
  });

  test('naar het adres dat streamt, met de sleutel in de header', () async {
    await ask(streaming([text('ok')]), []);

    expect(sent.url.path, endsWith('/gemini-2.5-flash:streamGenerateContent'));
    expect(sent.url.queryParameters['alt'], 'sse');
    expect(sent.headers['x-goog-api-key'], 'AIzaSyGeheim123');
    expect(sent.url.toString(), isNot(contains('AIzaSyGeheim123')));
  });

  test('een stukje dat over twee pakketten valt, blijft één stukje', () async {
    final pieces = <String>[];
    final reply = await ask(
      streaming([
        text('Drie sets van acht.'),
        text(' Rust twee minuten.'),
      ], cuts: 7),
      pieces,
    );

    expect(pieces, ['Drie sets van acht.', ' Rust twee minuten.']);
    expect(reply.text, 'Drie sets van acht. Rust twee minuten.');
  });

  test('een opzoeking komt mee, met haar handtekening', () async {
    final reply = await ask(
      streaming([
        {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'functionCall': {
                      'name': 'recent_workouts',
                      'args': {'limit': 3},
                    },
                    'thoughtSignature': 'sig-1',
                  },
                ],
              },
            },
          ],
        },
      ]),
      [],
    );

    expect(reply.wantsTools, isTrue);
    expect(reply.toolCalls.single.name, 'recent_workouts');
    expect(reply.toolCalls.single.input, {'limit': 3});
    expect(reply.toolCalls.single.signature, 'sig-1');
  });

  test('een fout voor het antwoord begint, is dezelfde fout als anders', () {
    final client = AiClient(
      apiKey: 'AIzaSyGeheim123',
      provider: CoachProvider.gemini,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {'message': 'API key not valid.'},
          }),
          400,
        ),
      ),
    );

    expect(
      ask(client, []),
      throwsA(isA<CoachException>().having((e) => e.badKey, 'badKey', isTrue)),
    );
  });

  test('een antwoord als gewone JSON leest ook, in één keer', () async {
    // Zonder alt=sse stuurt Google een lijst; een nep-dienst in een test
    // stuurt één antwoord. Allebei moeten ze werken.
    final pieces = <String>[];
    final client = AiClient(
      apiKey: 'AIzaSyGeheim123',
      provider: CoachProvider.gemini,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([text('In '), text('één keer.')]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final reply = await ask(client, pieces);

    expect(pieces, ['In ', 'één keer.']);
    expect(reply.text, 'In één keer.');
  });

  test('een verbinding die halverwege stilvalt, zegt dat', () async {
    final stalled = StreamController<List<int>>();
    addTearDown(stalled.close);
    stalled.add(utf8.encode('data: ${jsonEncode(text('Begin'))}\n\n'));
    final client = AiClient(
      apiKey: 'AIzaSyGeheim123',
      provider: CoachProvider.gemini,
      timeout: const Duration(milliseconds: 100),
      client: MockClient.streaming(
        (request, _) async => http.StreamedResponse(stalled.stream, 200),
      ),
    );
    final pieces = <String>[];

    await expectLater(
      ask(client, pieces),
      throwsA(
        isA<CoachException>().having(
          (e) => e.message,
          'message',
          contains('stokte'),
        ),
      ),
    );
    expect(pieces, ['Begin']);
  });

  group('de coach', () {
    test(
      'geeft de tekst door, en zegt wat hij opzoekt voor hij antwoordt',
      () async {
        final db = createTestDatabase();
        await db.settingsDao.ensureInitialized();
        addTearDown(db.close);
        var round = 0;
        final client = AiClient(
          apiKey: 'AIzaSyGeheim123',
          provider: CoachProvider.gemini,
          client: MockClient.streaming((request, _) async {
            final chunks = round++ == 0
                ? [
                    // Wat hij eerst zegt, voor hij opzoekt, is niet het
                    // antwoord.
                    text('Even kijken. '),
                    {
                      'candidates': [
                        {
                          'content': {
                            'parts': [
                              {
                                'functionCall': {
                                  'name': 'recent_workouts',
                                  'args': <String, Object?>{},
                                },
                              },
                            ],
                          },
                        },
                      ],
                    },
                  ]
                : [text('Je trainde '), text('drie keer.')];
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  [for (final c in chunks) 'data: ${jsonEncode(c)}\n\n'].join(),
                ),
              ),
              200,
            );
          }),
        );
        final events = <String>[];

        final answer =
            await Coach(
              client: client,
              tools: CoachTools(db),
              model: 'gemini-2.5-flash',
              system: 'x',
            ).ask(
              history: const [],
              question: 'Hoe vaak trainde ik?',
              onText: (piece) => events.add('tekst:$piece'),
              onLookup: (lookup) => events.add('zoekt:$lookup'),
            );

        expect(events.first, 'tekst:Even kijken. ');
        expect(events[1], startsWith('zoekt:'));
        expect(events.sublist(2), ['tekst:Je trainde ', 'tekst:drie keer.']);
        expect(answer.text, 'Je trainde drie keer.');
        expect(answer.requests, 2);
      },
    );
  });

  test(
    'een gestreamd antwoord dat tegen zijn grens liep, zegt dat ook',
    () async {
      final pieces = <String>[];
      final reply = await ask(
        streaming([
          text(''),
          {
            'candidates': [
              {'finishReason': 'MAX_TOKENS'},
            ],
            'usageMetadata': {'promptTokenCount': 16000},
          },
        ]),
        pieces,
      );
      expect(reply.cutOff, isTrue);
      expect(reply.malformed, isFalse);
    },
  );

  test('en een opzoeking die niet te lezen was, ook', () async {
    final reply = await ask(
      streaming([
        {
          'candidates': [
            {'finishReason': 'MALFORMED_FUNCTION_CALL'},
          ],
        },
      ]),
      [],
    );
    expect(reply.malformed, isTrue);
    expect(reply.text, isEmpty);
  });
}
