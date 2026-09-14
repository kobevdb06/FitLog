import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitlog/features/chat/data/anthropic_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The one door in the app, tested without opening it.
///
/// Every request here is answered by a client that never leaves this process.
void main() {
  /// The last request the client tried to send.
  late http.Request sent;

  AnthropicClient clientThatAnswers(
    int status,
    Object? body, {
    Duration delay = Duration.zero,
  }) {
    return AnthropicClient(
      apiKey: 'sk-ant-geheim-abc123',
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

  Future<CoachReply> ask(AnthropicClient client) => client.send(
    system: 'Je bent een coach.',
    messages: [
      {'role': 'user', 'content': 'Hoeveel sets voor borst?'},
    ],
    tools: const [],
    model: CoachModel.sonnet,
  );

  group('what goes out', () {
    test('one address, the key in the header, nothing in the URL', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'Tussen 10 en 20 per week.'},
        ],
        'usage': {'input_tokens': 800, 'output_tokens': 40},
      });

      await ask(client);

      expect(sent.url.toString(), kAnthropicEndpoint);
      expect(sent.url.query, isEmpty);
      expect(sent.headers['x-api-key'], 'sk-ant-geheim-abc123');
      expect(sent.headers['anthropic-version'], kAnthropicVersion);
      // The key belongs in the header and nowhere else.
      expect(sent.body, isNot(contains('sk-ant')));
    });

    test('the model and the question, and no tools when there are none', () {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      });

      return ask(client).then((_) {
        final body = jsonDecode(sent.body) as Map<String, Object?>;
        expect(body['model'], 'claude-sonnet-5');
        expect(body.containsKey('tools'), isFalse);
        expect(body['system'], 'Je bent een coach.');
        expect('${body['messages']}', contains('Hoeveel sets'));
      });
    });
  });

  group('what comes back', () {
    test('the text, and what it cost', () async {
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

    test('a request to look something up in the database', () async {
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
      expect(reply.toolCalls.single.name, 'recent_workouts');
      expect(reply.toolCalls.single.input['limit'], 5);
      expect(reply.text, 'Even kijken.');
      // The raw blocks are kept, because the next request has to send them
      // back as the assistant's turn.
      expect(reply.content, hasLength(2));
    });

    test('an answer without usage still counts as an answer', () async {
      final client = clientThatAnswers(200, {
        'content': [
          {'type': 'text', 'text': 'Ja.'},
        ],
      });

      final reply = await ask(client);

      expect(reply.text, 'Ja.');
      expect(reply.usage.inputTokens, 0);
    });
  });

  group('when it goes wrong', () {
    test('a rejected key says so, and points at the settings', () async {
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

    test('being rate limited is not the same as a broken key', () async {
      final client = clientThatAnswers(429, {
        'error': {'message': 'rate_limit'},
      });

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>().having((e) => e.badKey, 'badKey', isFalse),
        ),
      );
    });

    test('an error message never carries the key back', () async {
      // An API that echoes the request would otherwise put the key on screen.
      final client = clientThatAnswers(400, {
        'error': {'message': 'bad request with sk-ant-geheim-abc123 in it'},
      });

      try {
        await ask(client);
        fail('should have thrown');
      } on CoachException catch (error) {
        expect(error.message, isNot(contains('geheim')));
        expect(error.message, contains('sk-ant-...'));
      }
    });

    test('an overloaded server asks you to wait', () async {
      final client = clientThatAnswers(529, '');

      await expectLater(
        ask(client),
        throwsA(
          isA<CoachException>().having(
            (e) => e.message,
            'message',
            contains('overbelast'),
          ),
        ),
      );
    });

    test('nonsense back is a readable failure, not a crash', () async {
      final client = clientThatAnswers(200, 'dit is geen json');

      await expectLater(ask(client), throwsA(isA<CoachException>()));
    });

    test('no connection says the rest of the app still works', () async {
      final client = AnthropicClient(
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

    test('and waiting too long gives up rather than hanging', () async {
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

  group('the model choice', () {
    test('an unknown name falls back to the recommended one', () {
      expect(CoachModel.fromWire(null), CoachModel.sonnet);
      expect(CoachModel.fromWire('claude-2'), CoachModel.sonnet);
      expect(CoachModel.fromWire('claude-opus-5'), CoachModel.opus);
    });
  });
}
