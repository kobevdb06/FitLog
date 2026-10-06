import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/review/data/week_reviewer.dart';
import 'package:fitlog/features/review/domain/week_facts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach's word on a week: asked once, with the week's facts and
/// nothing else, and kept.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<String> sent;

  final monday = DateTime(2026, 9, 28);
  final sundayEvening = DateTime(2026, 10, 4, 20);

  AiClient client(String apiKey, CoachProvider provider) => AiClient(
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
                  {
                    'text':
                        'Sterke week voor je borst. Volgende week: één set '
                        'extra rows in Pull day.',
                  },
                ],
              },
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 700,
            'candidatesTokenCount': 40,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
  });

  tearDown(() => db.close());

  test('zonder sleutel wordt er niets gevraagd en niets bewaard', () async {
    final review = await WeekReviewer(
      db,
      clientFactory: client,
    ).write(monday, now: sundayEvening);

    expect(review, isNull);
    expect(sent, isEmpty);
    expect(await db.reportsDao.weekReviewFor(monday), isNull);
  });

  group('met een sleutel', () {
    setUp(() => db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg'));

    test(
      'vraagt het één keer, met de feiten, en bewaart wat er kwam',
      () async {
        final review = (await WeekReviewer(
          db,
          clientFactory: client,
        ).write(monday, now: sundayEvening))!;

        expect(sent, hasLength(1));
        expect(sent.single, contains('Je schrijft het weekoverzicht'));
        expect(sent.single, contains('lagging_muscles'));
        expect(sent.single, contains('2026-09-28'));
        expect(review.coachText, startsWith('Sterke week'));
        expect(
          review.suggestion,
          'Volgende week: één set extra rows in Pull day.',
        );

        final row = (await db.reportsDao.weekReviewFor(monday))!;
        expect(row.coachText, review.coachText);
        expect(row.requests, 1);
        // Het telt mee in het verbruik van vandaag.
        final spent = await db.chatDao.usageSince(DateTime(2026, 10, 4));
        expect(spent.requests, 1);
      },
    );

    test('aan de daglimiet vraagt het niets, en zegt waarom', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(coachDailyLimit: Value(1)),
      );
      await db.chatDao.createThread('t', 'Iets');
      await db.chatDao.addMessage(
        id: 'm',
        threadId: 't',
        role: 'assistant',
        content: 'Antwoord',
        requests: 1,
      );

      final review = (await WeekReviewer(
        db,
        clientFactory: client,
      ).write(monday, now: DateTime.now()))!;

      expect(sent, isEmpty);
      expect(review.coachText, isNull);
      expect(review.coachError, contains('daglimiet'));
    });
  });

  test('zonder "Volgende week:" is de hele tekst het voorstel', () {
    final review = WeekReview(
      facts: WeekFacts(start: monday, workouts: 0, sets: 0, volumeKg: 0),
      createdAt: sundayEvening,
      coachText: 'Doe zo verder.',
    );

    expect(review.suggestion, 'Doe zo verder.');
  });
}
