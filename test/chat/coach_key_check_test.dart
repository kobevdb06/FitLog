import 'dart:convert';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// Testing a key costs nothing of the day's asking: it asks for the list of
/// models, not a question.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<http.Request> sent;
  ProviderContainer? container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ProviderContainer answering(int status, Map<String, Object?> body) =>
      ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          coachClientFactoryProvider.overrideWithValue(
            (apiKey, provider) => AiClient(
              apiKey: apiKey,
              provider: provider,
              client: MockClient((request) async {
                sent.add(request);
                return http.Response(
                  jsonEncode(body),
                  status,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          ),
        ],
      );

  test('een werkende sleutel: de modellenlijst, geen vraag', () async {
    container = answering(200, {
      'models': [
        {
          'name': 'models/gemini-2.5-flash',
          'displayName': 'Gemini 2.5 Flash',
          'supportedGenerationMethods': ['generateContent'],
        },
      ],
    });

    final failure = await container!
        .read(coachControllerProvider.notifier)
        .checkKey(' AQ.Ab8RNgeheimgeheim1234 ');

    expect(failure, isNull);
    expect(sent.single.method, 'GET');
    expect(sent.single.url.path, endsWith('/models'));
    expect(sent.single.url.toString(), isNot(contains('generateContent')));
    // In de header, niet in het adres - en zonder de spaties eromheen.
    expect(sent.single.headers['x-goog-api-key'], 'AQ.Ab8RNgeheimgeheim1234');
    expect(sent.single.url.toString(), isNot(contains('AQ.Ab8RN')));
  });

  test('een geweigerde sleutel zegt dat het de sleutel is', () async {
    container = answering(400, {
      'error': {'message': 'API key not valid. Please pass a valid API key.'},
    });

    final failure = await container!
        .read(coachControllerProvider.notifier)
        .checkKey('AQ.fout');

    expect(failure, isNotNull);
    expect(failure!.badKey, isTrue);
  });
}
