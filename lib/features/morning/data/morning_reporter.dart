import 'dart:convert';

import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/domain/coach_budget.dart';
import '../../progress/data/recovery_loader.dart';
import '../domain/morning_facts.dart';

/// The whole instruction for one job: turn this morning's facts into three
/// sentences.
///
/// Its own prompt, not the chat's: it has no tools and nothing to look up -
/// everything it may say is in the message - and it is short on purpose, as
/// it is paid for every morning.
const String kMorningReportSystem = '''
Je schrijft het ochtendrapport in FitLog, een logboek voor krachttraining. Je
krijgt de feiten van vanochtend als JSON. Schrijf in het Nederlands, in de
je-vorm, hoogstens drie korte zinnen en geen opsomming:
- hoe de nacht was (duur en slaapscore), en wat HRV of rusthartslag zeggen
  als ze erbij staan;
- welke spiergroepen nog herstellen en welke klaar zijn;
- wat dat betekent voor vandaag trainen, in één zin.
Gebruik alleen wat in de feiten staat: verzin geen cijfers en geen
spiergroepen. Je bent geen arts: geen diagnoses, geen supplementen.
''';

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
          ((key, provider) => AiClient(apiKey: key, provider: provider));

  final AppDatabase db;
  final ReportClientFactory _clientFactory;

  /// [importError] is why Health Connect could not be read just before,
  /// kept with the report so a morning without a night has a reason.
  Future<MorningReport> write({DateTime? now, String? importError}) async {
    final at = now ?? DateTime.now();

    final facts = buildMorningFacts(
      now: at,
      nights: await db.recoveryDao
          .watchSleepSince(at.subtract(const Duration(days: 2)))
          .first,
      vitals: [
        for (final row
            in await db.healthDao
                .watchVitalsSince(at.subtract(kVitalsBaselineWindow))
                .first)
          vitalsDayOf(row),
      ],
      estimates: await loadRecoveryEstimates(db, now: at),
    );

    String? text;
    String? error;
    CoachUsage? usage;
    final settings = await db.settingsDao.getSettings();
    final key = settings.anthropicApiKey;
    if (key != null && key.isNotEmpty) {
      final chosen = CoachProvider.fromWire(settings.chatProvider);
      final provider = chosen != null && kOfferedProviders.contains(chosen)
          ? chosen
          : kOfferedProviders.first;
      final spent = await db.chatDao.usageSince(coachDayStart(at, provider));
      final limit = settings.coachDailyLimit ?? kDefaultDailyLimit;

      if (limit > 0 && spent.requests >= limit) {
        error =
            'De coach zit aan je daglimiet, dus dit rapport staat er zonder '
            'zijn woorden.';
      } else {
        final client = _clientFactory(key, provider);
        try {
          final reply = await client.send(
            system: kMorningReportSystem,
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
