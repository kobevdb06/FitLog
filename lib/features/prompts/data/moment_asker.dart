import 'dart:convert';

import '../../../core/db/database.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/data/counted_client.dart';
import '../../chat/domain/coach_budget.dart';
import '../../chat/domain/coach_prompt.dart';
import '../domain/coach_moments.dart';

/// How a client is made, so a test can hand over one that answers from
/// memory. The same shape as the reports' own.
typedef MomentClientFactory = AiClient Function(
  String apiKey,
  CoachProvider provider,
);

/// What one geplande prompt came back with: words, or why there are none.
class MomentAnswer {
  const MomentAnswer({this.text, this.error, this.usage});

  final String? text;
  final String? error;

  /// What it cost; null when nothing went out.
  final CoachUsage? usage;
}

/// Asks the coach [prompt] once about [facts], with no tools: everything it
/// may say is in the message, so it costs one request and nothing more.
///
/// Null without a key: then there is no coach to ask, and nothing to say
/// why. [atLimit] is what to say when the day's limit is spent, in the
/// words of the screen it ends up on.
///
/// The user's profile goes along when they share it, and the coach's
/// notebook when it is on - as with every question in the chat.
Future<MomentAnswer?> askMoment(
  AppDatabase db, {
  required MomentPrompt prompt,
  required Map<String, Object?> facts,
  required String atLimit,
  required DateTime now,
  MomentClientFactory? clientFactory,
  bool withWeightUnit = false,
}) async {
  final settings = await db.settingsDao.getSettings();
  final key = settings.anthropicApiKey;
  if (key == null || key.isEmpty) return null;

  final profile = settings.coachSeesProfile
      ? await db.settingsDao.getProfile()
      : null;
  final notes = settings.coachMemory
      ? await db.coachNotesDao.notes()
      : const <CoachNoteRow>[];
  final system = buildMomentSystem(
    prompt: prompt,
    weightUnit: withWeightUnit ? settings.unitWeight : null,
    aboutUser: profile == null
        ? null
        : describeProfile(
            now: now,
            birthDate: switch (profile.birthDate) {
              final at? => DateTime.fromMillisecondsSinceEpoch(at),
              null => null,
            },
            sex: Sex.fromWire(profile.sex),
            heightCm: profile.heightCm,
          ),
    notes: [for (final note in notes) note.note],
  );
  return askOnce(
    db,
    system: system,
    message: jsonEncode(facts),
    maxTokens: prompt.length.maxTokens,
    atLimit: atLimit,
    now: now,
    clientFactory: clientFactory,
  );
}

/// Asks the coach once: [system], and [message] as the one question, with
/// no tools. Null without a key; [atLimit] when the day's limit is spent.
Future<MomentAnswer?> askOnce(
  AppDatabase db, {
  required String system,
  required String message,
  required int maxTokens,
  required String atLimit,
  required DateTime now,
  MomentClientFactory? clientFactory,
}) async {
  final settings = await db.settingsDao.getSettings();
  final key = settings.anthropicApiKey;
  if (key == null || key.isEmpty) return null;

  final chosen = CoachProvider.fromWire(settings.chatProvider);
  final provider = chosen != null && kOfferedProviders.contains(chosen)
      ? chosen
      : kOfferedProviders.first;
  final spent = await db.chatDao.usageSince(coachDayStart(now, provider));
  final limit = settings.coachDailyLimit ?? kDefaultDailyLimit;
  if (limit > 0 && spent.requests >= limit) {
    return MomentAnswer(error: atLimit);
  }

  final client =
      (clientFactory ?? (key, provider) => countedClient(db, key, provider))(
        key,
        provider,
      );
  try {
    final reply = await client.send(
      system: system,
      messages: [CoachMessage.user(message)],
      tools: const [],
      model: CoachModel.resolveWire(settings.chatModel, provider),
      maxTokens: maxTokens,
    );
    final text = reply.text.trim();
    return MomentAnswer(
      text: text.isEmpty ? null : text,
      error: text.isEmpty ? 'De coach gaf een leeg antwoord.' : null,
      usage: reply.usage,
    );
  } on CoachException catch (e) {
    return MomentAnswer(error: e.message);
  } on Object catch (e) {
    // Said as the coach says it, never as the raw error (DECISIONS 248).
    return MomentAnswer(error: AiClient.asCoachException(e).message);
  } finally {
    client.close();
  }
}
