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

/// The day limit holds for every question (DECISIONS 249).
///
/// It is called the day's limit and stopped every automatic question, but
/// the chat never looked at it. And it counted stored answers: a request
/// that failed did not count, and deleting the conversations set the day
/// back to nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late List<String> bodies;
  late Future<http.Response> Function() answer;

  http.Response ok(String text) => http.Response(
    jsonEncode({
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
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await db.chatDao.createThread('t-1', 'Vraag');
    bodies = [];
    answer = () async => ok('Goed zo.');
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        // Counted as the app counts, as each request goes out.
        coachClientFactoryProvider.overrideWithValue(
          (apiKey, provider) => AiClient(
            apiKey: apiKey,
            provider: provider,
            onRequest: () => db.chatDao.noteRequest(DateTime.now()),
            client: MockClient((request) async {
              bodies.add(request.body);
              return answer();
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

  Future<int> spentToday() async => (await db.chatDao.usageSince(
    coachDayStart(DateTime.now(), CoachProvider.gemini),
  )).requests;

  CoachController coach() => container.read(coachControllerProvider.notifier);

  test('a question in the chat at the limit is not sent', () async {
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(coachDailyLimit: Value(2)),
    );
    await db.chatDao.noteRequest(DateTime.now());
    await db.chatDao.noteRequest(DateTime.now());

    await coach().ask(threadId: 't-1', question: 'Nog een vraag?');

    expect(bodies, isEmpty);
    expect(
      container.read(coachControllerProvider).error,
      contains('daglimiet'),
    );
    // The question stays, as with any answer that does not come.
    final asked = await db.chatDao.messages('t-1');
    expect(asked.single.content, 'Nog een vraag?');
  });

  test('without a limit it is sent however much was asked', () async {
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(coachDailyLimit: Value(0)),
    );
    for (var i = 0; i < 3; i++) {
      await db.chatDao.noteRequest(DateTime.now());
    }

    await coach().ask(threadId: 't-1', question: 'Nog een vraag?');

    expect(bodies, hasLength(1));
  });

  test('a request that failed counts', () async {
    answer = () async => throw const SocketException('weg');

    await coach().ask(threadId: 't-1', question: 'Hoeveel sets?');

    expect(await spentToday(), 1);
  });

  test('deleting the conversations does not give the day back', () async {
    await coach().ask(threadId: 't-1', question: 'Hoeveel sets?');
    expect(await spentToday(), 1);

    await db.chatDao.deleteAllThreads();

    expect(await spentToday(), 1);
  });

  test('only the last few days are kept', () async {
    final now = DateTime.now();
    await db.chatDao.noteRequest(now.subtract(const Duration(days: 10)));
    await db.chatDao.noteRequest(now);

    final kept = await db.select(db.coachRequestsTable).get();
    expect(kept, hasLength(1));
  });
}
