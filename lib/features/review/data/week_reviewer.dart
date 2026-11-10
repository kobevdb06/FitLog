import 'dart:convert';

import '../../../core/db/database.dart';
import '../../chat/data/counted_client.dart';
import '../../morning/data/morning_reporter.dart' show ReportClientFactory;
import '../../prompts/data/moment_asker.dart';
import '../../prompts/domain/coach_moments.dart';
import '../domain/week_facts.dart';
import 'week_facts_builder.dart';

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
          ((key, provider) => countedClient(db, key, provider));

  final AppDatabase db;
  final ReportClientFactory _clientFactory;

  /// Null when there is no coach to ask, or the user switched the question
  /// off (Geplande prompts → Weekoverzicht): the week is its numbers then.
  Future<WeekReview?> write(DateTime start, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final settings = await db.settingsDao.getSettings();
    final key = settings.anthropicApiKey;
    if (key == null || key.isEmpty) return null;
    final prompt = await MomentPrompt.load(db, CoachMoment.week);
    if (!prompt.enabled) return null;

    final facts = await buildWeekFacts(db, start, now: at);
    // The review keeps the whole week; the coach is told what it may see.
    // Without Health Connect shared, that is the week without the watch:
    // the training, and only the nights filled in by hand.
    final told = settings.coachSeesHealth
        ? facts
        : await buildWeekFacts(db, start, now: at, healthConnect: false);
    final answer = await askMoment(
      db,
      prompt: prompt,
      facts: told.forCoach(),
      atLimit:
          'De coach zit aan je daglimiet, dus over deze week schreef hij '
          'niets.',
      now: at,
      clientFactory: _clientFactory,
    );
    if (answer == null) return null;
    final text = answer.text;
    final error = answer.error;
    final usage = answer.usage;

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
