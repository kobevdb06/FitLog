import 'dart:convert';

import '../../../core/db/database.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/domain/coach_budget.dart';
import '../../morning/data/morning_reporter.dart' show ReportClientFactory;
import '../domain/week_facts.dart';
import 'week_facts_builder.dart';

/// The whole instruction for one job: the week's facts in a few sentences,
/// ending in one thing to do next week.
///
/// No tools, like the morning report: everything it may say is in the
/// message. The suggestion is put ready for the coach in the chat, which
/// can then change a routine; this one only writes.
const String kWeekReviewSystem = '''
Je schrijft het weekoverzicht in FitLog, een logboek voor krachttraining. Je
krijgt de feiten van de afgelopen week als JSON. Schrijf in het Nederlands, in
de je-vorm, hoogstens vier korte zinnen en geen opsomming:
- wat goed ging: records, oefeningen die weer vooruitgaan, trainingen gehaald;
- wat achterbleef, alleen als het in de feiten staat: een spiergroep in
  lagging_muscles, gemiste trainingen, korter slapen dan gewoonlijk;
- eindig met één concreet voorstel voor volgende week, in een zin die begint
  met "Volgende week:".
Gebruik alleen wat in de feiten staat: verzin geen cijfers, oefeningen of
spiergroepen. Je bent geen arts: geen diagnoses, geen supplementen.
''';

/// What the coach wrote about a week, or why it did not.
class WeekReview {
  const WeekReview({
    required this.facts,
    required this.createdAt,
    this.coachText,
    this.coachError,
  });

  final WeekFacts facts;
  final DateTime createdAt;
  final String? coachText;
  final String? coachError;

  /// The sentence with what to do next week, or the whole text when the
  /// coach did not start one with "Volgende week:".
  String? get suggestion {
    final text = coachText;
    if (text == null) return null;
    final at = text.indexOf('Volgende week');
    return at < 0 ? text : text.substring(at).trim();
  }

  static WeekReview fromRow(WeekReviewRow row) => WeekReview(
    facts: WeekFacts.fromJson(
      (jsonDecode(row.facts) as Map).cast<String, Object?>(),
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    coachText: row.coachText,
    coachError: row.coachError,
  );
}

/// Works out a week, has the coach put it in words, and stores what it said.
///
/// Without a key there is nothing to write: the review on screen is the
/// numbers, and those are worked out when it opens.
class WeekReviewer {
  WeekReviewer(this.db, {ReportClientFactory? clientFactory})
    : _clientFactory =
          clientFactory ??
          ((key, provider) => AiClient(apiKey: key, provider: provider));

  final AppDatabase db;
  final ReportClientFactory _clientFactory;

  /// Null when there is no coach to ask.
  Future<WeekReview?> write(DateTime start, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final settings = await db.settingsDao.getSettings();
    final key = settings.anthropicApiKey;
    if (key == null || key.isEmpty) return null;

    final facts = await buildWeekFacts(db, start, now: at);
    final chosen = CoachProvider.fromWire(settings.chatProvider);
    final provider = chosen != null && kOfferedProviders.contains(chosen)
        ? chosen
        : kOfferedProviders.first;
    final spent = await db.chatDao.usageSince(coachDayStart(at, provider));
    final limit = settings.coachDailyLimit ?? kDefaultDailyLimit;

    String? text;
    String? error;
    CoachUsage? usage;
    if (limit > 0 && spent.requests >= limit) {
      error =
          'De coach zit aan je daglimiet, dus over deze week schreef hij '
          'niets.';
    } else {
      final client = _clientFactory(key, provider);
      try {
        final reply = await client.send(
          system: kWeekReviewSystem,
          messages: [CoachMessage.user(jsonEncode(facts.forCoach()))],
          tools: const [],
          model: CoachModel.resolveWire(settings.chatModel, provider),
          maxTokens: 512,
        );
        usage = reply.usage;
        text = reply.text.trim().isEmpty ? null : reply.text.trim();
        if (text == null) error = 'De coach gaf een leeg antwoord.';
      } on CoachException catch (e) {
        error = e.message;
      } on Object catch (e) {
        error = 'De coach was niet bereikbaar: $e';
      } finally {
        client.close();
      }
    }

    await db.reportsDao.saveWeekReview(
      start: start,
      createdAt: at,
      facts: jsonEncode(facts.toJson()),
      coachText: text,
      coachError: error,
      requests: usage == null ? null : 1,
      inputTokens: usage?.inputTokens,
      outputTokens: usage?.outputTokens,
    );
    return WeekReview(
      facts: facts,
      createdAt: at,
      coachText: text,
      coachError: error,
    );
  }
}
