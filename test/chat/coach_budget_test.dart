import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/domain/coach_budget.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// What a day of asking has cost.
///
/// The bar counts calls the app made, not credits a service has left - nobody
/// can read those - so these tests are about that count being right, and about
/// the day starting where the service's day starts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  ProviderContainer? container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  /// A Gemini that says [replies] in turn.
  ProviderContainer containerSaying(List<Object> replies) {
    var next = 0;
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        coachClientFactoryProvider.overrideWithValue(
          (apiKey, provider) => AiClient(
            apiKey: apiKey,
            provider: provider,
            client: MockClient((request) async {
              final reply =
                  replies[next < replies.length ? next : replies.length - 1];
              next++;
              return http.Response(
                jsonEncode(reply),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );
  }

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
    'usageMetadata': {'promptTokenCount': 1000, 'candidatesTokenCount': 40},
  };

  Map<String, Object?> asksForRoutines() => {
    'candidates': [
      {
        'content': {
          'parts': [
            {
              'functionCall': {'name': 'routines', 'args': <String, Object?>{}},
            },
          ],
        },
      },
    ],
    'usageMetadata': {'promptTokenCount': 300, 'candidatesTokenCount': 10},
  };

  group('waar de dag begint', () {
    test('bij Google in Californië, niet hier', () {
      // Acht uur 's ochtends hier is bij Google nog gisteren: de gratis laag
      // springt pas om middernacht daar terug.
      final morning = DateTime(2026, 6, 15, 8);
      final start = coachDayStart(morning, CoachProvider.gemini);

      expect(start.isBefore(morning), isTrue);
      expect(start.isBefore(DateTime(2026, 6, 15)), isTrue);
      expect(start.isAfter(DateTime(2026, 6, 14)), isTrue);
    });

    test('en na negen uur telt het wel als vandaag', () {
      final afternoon = DateTime(2026, 6, 15, 14);
      final start = coachDayStart(afternoon, CoachProvider.gemini);

      expect(start.isAfter(DateTime(2026, 6, 15)), isTrue);
      expect(start.isBefore(afternoon), isTrue);
    });

    test('bij Anthropic is het je eigen middernacht', () {
      final start = coachDayStart(
        DateTime(2026, 6, 15, 8),
        CoachProvider.anthropic,
      );

      expect(start, DateTime(2026, 6, 15));
    });
  });

  group('de balk zelf', () {
    test('is leeg zolang er niets gevraagd is', () {
      const usage = CoachDayUsage.none;

      expect(usage.fractionOf(250), 0);
      expect(usage.isOver(250), isFalse);
    });

    test('loopt vol maar niet over', () {
      const usage = CoachDayUsage(
        requests: 400,
        answers: 200,
        inputTokens: 0,
        outputTokens: 0,
        since: null,
      );

      expect(usage.fractionOf(250), 1);
      expect(usage.isOver(250), isTrue);
    });

    test('en een limiet van niets deelt niet door nul', () {
      const usage = CoachDayUsage(
        requests: 5,
        answers: 5,
        inputTokens: 0,
        outputTokens: 0,
        since: null,
      );

      expect(usage.fractionOf(0), 0);
      expect(usage.isOver(0), isFalse);
    });
  });

  group('wat er geteld wordt', () {
    test('één vraag zonder opzoeking is één call', () async {
      container = containerSaying([says('Tussen 10 en 20 sets.')]);
      final coach = container!.read(coachControllerProvider.notifier);

      final thread = await coach.startThread('Hoeveel sets?');
      await coach.ask(threadId: thread, question: 'Hoeveel sets voor borst?');

      final usage = await db.chatDao.usageSince(DateTime(2020));
      expect(usage.requests, 1);
      expect(usage.answers, 1);
      expect(usage.inputTokens, 1000);
      expect(usage.outputTokens, 40);
    });

    test('maar met een opzoeking erin zijn het er twee', () async {
      // Dit is waarom de balk calls telt en geen vragen: de gratis laag telt
      // ook calls, en een vraag over je eigen logboek is er minstens twee.
      container = containerSaying([
        asksForRoutines(),
        says('Je hebt nog geen routines.'),
      ]);
      final coach = container!.read(coachControllerProvider.notifier);

      final thread = await coach.startThread('Welke routines heb ik?');
      await coach.ask(threadId: thread, question: 'Welke routines heb ik?');

      final usage = await db.chatDao.usageSince(DateTime(2020));
      expect(usage.requests, 2);
      expect(usage.answers, 1);
      // De tokens van beide rondes staan erbij.
      expect(usage.inputTokens, 1300);
    });

    test('een antwoord van voor de teller telt als één', () async {
      await db.chatDao.createThread('t-oud', 'Oude vraag');
      await db.chatDao.addMessage(
        id: 'm-oud',
        threadId: 't-oud',
        role: 'assistant',
        content: 'Oud antwoord',
      );

      final usage = await db.chatDao.usageSince(DateTime(2020));
      expect(usage.requests, 1);
    });

    test('en wat je zelf typte telt niet mee', () async {
      container = containerSaying([says('ok')]);
      final coach = container!.read(coachControllerProvider.notifier);

      final thread = await coach.startThread('Vraag');
      await coach.ask(threadId: thread, question: 'Vraag');

      // Twee berichten in het gesprek, één antwoord op de teller.
      expect(await db.chatDao.messages(thread), hasLength(2));
      expect((await db.chatDao.usageSince(DateTime(2020))).answers, 1);
    });

    test('en gisteren telt niet mee vandaag', () async {
      container = containerSaying([says('ok')]);
      final coach = container!.read(coachControllerProvider.notifier);

      final thread = await coach.startThread('Vraag');
      await coach.ask(threadId: thread, question: 'Vraag');

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final usage = await db.chatDao.usageSince(tomorrow);
      expect(usage.requests, 0);
      expect(usage.answers, 0);
    });
  });

  group('de limiet', () {
    test('begint op het getal van de app tot je er zelf een zet', () async {
      container = containerSaying([says('ok')]);

      // Zonder eigen getal: het startgetal van de app.
      expect(container!.read(coachDailyLimitProvider), kDefaultDailyLimit);

      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(coachDailyLimit: Value(40)),
      );

      // En daarna staat jouw getal in de database, waar het scherm het
      // vandaan haalt.
      expect((await db.settingsDao.getSettings()).coachDailyLimit, 40);
    });
  });
}
