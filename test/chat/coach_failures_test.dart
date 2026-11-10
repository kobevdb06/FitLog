import 'dart:convert';
import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach after something unexpected (DECISIONS 248).
///
/// Only the coach's own errors were caught. A TLS failure, a broken stream,
/// a lookup that threw: the chat stayed busy, and every next question was
/// ignored until the app was restarted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late List<String> bodies;
  late Future<http.Response> Function(http.Request) answer;

  Map<String, Object?> says(String text) => {
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
    'usageMetadata': {'promptTokenCount': 100, 'candidatesTokenCount': 10},
  };

  http.Response ok(String text) => http.Response(
    jsonEncode(says(text)),
    200,
    headers: {'content-type': 'application/json'},
  );

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await db.chatDao.createThread('t-1', 'Vraag');
    bodies = [];
    answer = (_) async => ok('Goed zo.');
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        coachClientFactoryProvider.overrideWithValue(
          (apiKey, provider) => AiClient(
            apiKey: apiKey,
            provider: provider,
            client: MockClient((request) async {
              bodies.add(request.body);
              return answer(request);
            }),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  CoachController coach() => container.read(coachControllerProvider.notifier);

  test(
    'a failed secure connection is said, and the next question goes',
    () async {
      answer = (_) async => throw const HandshakeException('certificaat');

      await coach().ask(threadId: 't-1', question: 'Hoeveel sets?');

      final failed = container.read(coachControllerProvider);
      expect(failed.sending, isFalse);
      expect(failed.error, contains('beveiligde verbinding'));
      expect(failed.error, isNot(contains('certificaat')));

      answer = (_) async => ok('Drie.');
      await coach().ask(threadId: 't-1', question: 'Hoeveel sets?');

      final messages = await db.chatDao.messages('t-1');
      expect(messages.last.content, 'Drie.');
    },
  );

  test('an answer in a shape nobody expected is said too', () async {
    answer = (_) async => http.Response('{"candidates": 7}', 200);

    await coach().ask(threadId: 't-1', question: 'Hoeveel sets?');

    final failed = container.read(coachControllerProvider);
    expect(failed.sending, isFalse);
    expect(failed.error, isNotNull);
  });

  test('two quick taps send the question once', () async {
    await Future.wait([
      coach().ask(threadId: 't-1', question: 'Hoeveel sets?'),
      coach().ask(threadId: 't-1', question: 'Hoeveel sets?'),
    ]);

    final asked = [
      for (final m in await db.chatDao.messages('t-1'))
        if (m.role == 'user') m,
    ];
    expect(asked, hasLength(1));
    expect(bodies, hasLength(1));
  });

  test('the same words asked again keep the earlier ones in the '
      'conversation', () async {
    await coach().ask(threadId: 't-1', question: 'ok');
    await coach().ask(threadId: 't-1', question: 'ok');

    final last = jsonEncode(jsonDecode(bodies.last));
    expect(
      RegExp('"text":"ok"').allMatches(last).length,
      2,
      reason: 'the first "ok", and this one',
    );
  });

  test('a lookup that throws is told to the model as a failed one', () async {
    var round = 0;
    final client = AiClient(
      apiKey: 'AQ.Ab8RNiZhX2Mkg',
      client: MockClient((request) async {
        bodies.add(request.body);
        round++;
        if (round == 1) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'functionCall': {
                          'name': 'routines',
                          'args': <String, Object?>{},
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        return ok('Zonder die opzoeking: drie sets.');
      }),
    );

    final reply = await Coach(
      client: client,
      tools: _Broken(db),
      model: 'gemini-2.5-flash',
      system: 'Coach.',
    ).ask(history: const [], question: 'Welke routines?', images: const []);

    expect(reply.text, 'Zonder die opzoeking: drie sets.');
    expect(bodies.last, contains('"ok":false'));
  });
}

/// Every lookup throws, as one given input in a shape it did not expect.
class _Broken extends CoachTools {
  _Broken(super.db);

  @override
  Future<CoachLookup> run(String name, Map<String, Object?> input) async =>
      throw TypeError();
}
