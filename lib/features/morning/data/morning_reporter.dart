import 'dart:convert';

import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/data/counted_client.dart';
import '../../progress/data/recovery_loader.dart';
import '../../prompts/data/moment_asker.dart';
import '../../prompts/domain/coach_moments.dart';
import '../../readiness/data/check_loader.dart';
import '../../readiness/domain/training_check.dart';
import '../domain/morning_facts.dart';

/// The morning at [at] as the report sees it: the night, what still
/// recovers, and the check before today's session. Also what the coach is
/// told about today before a workout, or when it had better wait.
Future<MorningFacts> loadMorningFacts(
  AppDatabase db,
  DateTime at, {
  required bool healthConnect,
}) async {
  final nights = [
    for (final row
        in await db.recoveryDao
            .watchSleepSince(at.subtract(const Duration(days: 2)))
            .first)
      if (healthConnect || row.source == null) row,
  ];
  final vitals = [
    if (healthConnect)
      for (final row
          in await db.healthDao
              .watchVitalsSince(at.subtract(kVitalsBaselineWindow))
              .first)
        vitalsDayOf(row),
  ];
  final estimates = await loadRecoveryEstimates(
    db,
    now: at,
    healthConnect: healthConnect,
  );
  return buildMorningFacts(
    now: at,
    nights: nights,
    vitals: vitals,
    estimates: estimates,
    // The check before today's session, from the same morning.
    check: await loadTodayCheck(
      db,
      now: at,
      estimates: estimates,
      body: checkBody(now: at, nights: nights, vitals: vitals),
    ),
  );
}

/// How a client is made, so a test can hand over one that answers from
/// memory. The same shape as the chat's own factory.
typedef ReportClientFactory = AiClient Function(
  String apiKey,
  CoachProvider provider,
);

/// One report, as the screen and the notification show it.
class MorningReport {
  const MorningReport({
    required this.facts,
    required this.createdAt,
    this.coachText,
    this.coachError,
    this.importError,
  });

  factory MorningReport.fromRow(MorningReportRow row) => MorningReport(
    facts: MorningFacts.fromJson(jsonDecode(row.facts) as Map<String, Object?>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    coachText: row.coachText,
    coachError: row.coachError,
    importError: row.importError,
  );

  final MorningFacts facts;
  final DateTime createdAt;
  final String? coachText;
  final String? coachError;
  final String? importError;

  /// The coach's words when there are any, the app's own otherwise.
  String get text => coachText ?? morningSummary(facts);
}

/// Works out this morning's report, has the coach put it in words when the
/// coach is on, and stores it.
class MorningReporter {
  MorningReporter(this.db, {ReportClientFactory? clientFactory})
    : _clientFactory =
          clientFactory ??
          ((key, provider) => countedClient(db, key, provider));

  final AppDatabase db;
  final ReportClientFactory _clientFactory;

  /// [importError] is why Health Connect could not be read just before,
  /// kept with the report so a morning without a night has a reason.
  Future<MorningReport> write({DateTime? now, String? importError}) async {
    final at = now ?? DateTime.now();

    Future<MorningFacts> build({required bool healthConnect}) =>
        loadMorningFacts(db, at, healthConnect: healthConnect);

    final facts = await build(healthConnect: true);

    String? text;
    String? error;
    CoachUsage? usage;
    final settings = await db.settingsDao.getSettings();
    // What the coach is asked, in the user's words; switched off, the report
    // is FitLog's own and nothing is asked.
    final prompt = await MomentPrompt.load(db, CoachMoment.morning);
    final key = prompt.enabled ? settings.anthropicApiKey : null;
    // A morning that holds something from Health Connect is not the coach's
    // to see unless that is shared. Leaving it out would not do either: the
    // coach's words replace the app's on the report, and words about a
    // morning without its night would contradict the numbers beside them.
    // So the coach writes only when what it may see is the whole morning -
    // as it is for someone who fills in their nights by hand.
    final withheld =
        key != null &&
        key.isNotEmpty &&
        !settings.coachSeesHealth &&
        jsonEncode((await build(healthConnect: false)).forCoach()) !=
            jsonEncode(facts.forCoach());
    if (withheld) {
      error =
          'Je deelt Health Connect niet met de coach, dus dit rapport staat '
          'er zonder zijn woorden.';
    } else if (key != null && key.isNotEmpty) {
      final answer = await askMoment(
        db,
        prompt: prompt,
        facts: facts.forCoach(),
        atLimit:
            'De coach zit aan je daglimiet, dus dit rapport staat er zonder '
            'zijn woorden.',
        now: at,
        clientFactory: _clientFactory,
      );
      text = answer?.text;
      error = answer?.error;
      usage = answer?.usage;
    }

    await db.reportsDao.saveReport(
      day: facts.day,
      createdAt: at,
      facts: jsonEncode(facts.toJson()),
      coachText: text,
      coachError: error,
      importError: importError,
      requests: usage == null ? null : 1,
      inputTokens: usage?.inputTokens,
      outputTokens: usage?.outputTokens,
    );
    return MorningReport(
      facts: facts,
      createdAt: at,
      coachText: text,
      coachError: error,
      importError: importError,
    );
  }
}
