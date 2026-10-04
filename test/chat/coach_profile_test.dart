import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/domain/coach_prompt.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// Your age, sex and height, told to the coach only when you say so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wat er gezegd wordt', () {
    final now = DateTime(2026, 10, 4);

    test('leeftijd, geslacht en lengte, zoals je ze zegt', () {
      expect(
        describeProfile(
          now: now,
          birthDate: DateTime(2003, 2, 14),
          sex: Sex.male,
          heightCm: 182.4,
        ),
        '23 jaar, man, 182 cm',
      );
    });

    test('de dag voor je verjaardag ben je nog een jaar jonger', () {
      expect(
        describeProfile(now: now, birthDate: DateTime(2003, 10, 5)),
        '22 jaar',
      );
      expect(
        describeProfile(now: now, birthDate: DateTime(2003, 10, 4)),
        '23 jaar',
      );
    });

    test('"liever niet zeggen" wordt ook niet gezegd', () {
      expect(
        describeProfile(now: now, sex: Sex.undisclosed, heightCm: 170),
        '170 cm',
      );
      expect(describeProfile(now: now, sex: Sex.undisclosed), isNull);
      expect(describeProfile(now: now), isNull);
    });

    test('en in de prompt een regel, alleen als er iets is', () {
      expect(
        buildCoachPrompt(
          now: now,
          weightUnit: 'kg',
          aboutUser: '23 jaar, man, 182 cm',
        ),
        contains('Over de gebruiker: 23 jaar, man, 182 cm.'),
      );
      expect(
        buildCoachPrompt(now: now, weightUnit: 'kg'),
        isNot(contains('Over de gebruiker')),
      );
    });
  });

  group('wat er meegaat', () {
    late AppDatabase db;
    late Directory home;
    late List<String> sent;
    ProviderContainer? container;

    setUp(() async {
      db = createTestDatabase();
      await db.settingsDao.ensureInitialized();
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.settingsDao.upsertProfile(
        displayName: const Value('Kobe'),
        birthDate: Value(DateTime(2003, 2, 14).millisecondsSinceEpoch),
        sex: const Value('male'),
        heightCm: const Value(182),
      );
      home = await Directory.systemTemp.createTemp('fitlog_coach_profile');
      sent = [];
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appPathsProvider.overrideWith((ref) => AppPaths(home)),
          coachClientFactoryProvider.overrideWithValue(
            (apiKey, provider) => AiClient(
              apiKey: apiKey,
              provider: provider,
              client: MockClient((request) async {
                sent.add(request.body);
                return http.Response(
                  jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {'text': 'ok'},
                          ],
                        },
                      },
                    ],
                    'usageMetadata': {
                      'promptTokenCount': 1200,
                      'candidatesTokenCount': 4,
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
    });

    tearDown(() async {
      container?.dispose();
      await db.close();
      if (await home.exists()) await home.delete(recursive: true);
    });

    Future<String> ask() async {
      final coach = container!.read(coachControllerProvider.notifier);
      final thread = await coach.startThread('Hoeveel sets?');
      await coach.ask(threadId: thread, question: 'Hoeveel sets?');
      return sent.single;
    }

    test('standaard alleen je naam', () async {
      final body = await ask();

      expect(body, contains('Kobe'));
      expect(body, isNot(contains('Over de gebruiker')));
      expect(body, isNot(contains('182 cm')));
    });

    test('met de schakelaar aan ook de rest', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(coachSeesProfile: Value(true)),
      );

      final body = await ask();

      expect(body, contains('Over de gebruiker: '));
      expect(body, contains('jaar, man, 182 cm'));
    });
  });
}
