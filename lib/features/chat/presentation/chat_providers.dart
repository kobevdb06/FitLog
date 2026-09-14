/// Everything the coach screen needs, and the switch that keeps it asleep.
///
/// Without a key in the settings there is no coach: [coachEnabled] is false,
/// the screen is unreachable, and nothing here ever builds a client.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../data/ai_client.dart';
import '../data/coach.dart';
import '../data/coach_tools.dart';
import '../domain/coach_prompt.dart';

part 'chat_providers.g.dart';

const _uuid = Uuid();

/// How a client is made, so a test can hand over one that answers from
/// memory instead of from the network.
typedef CoachClientFactory = AiClient Function(String apiKey);

@riverpod
CoachClientFactory coachClientFactory(Ref ref) =>
    (apiKey) => AiClient(apiKey: apiKey);

@riverpod
String? coachApiKey(Ref ref) {
  final key = ref.watch(settingsProvider).value?.anthropicApiKey;
  return key == null || key.isEmpty ? null : key;
}

/// Whether the user has switched the coach on by entering a key.
@riverpod
bool coachEnabled(Ref ref) => ref.watch(coachApiKeyProvider) != null;

/// Which service the key belongs to: what the user said, or else what the
/// key looks like.
@riverpod
CoachProvider coachProvider(Ref ref) {
  final chosen = CoachProvider.fromWire(
    ref.watch(settingsProvider).value?.chatProvider,
  );
  if (chosen != null) return chosen;

  final key = ref.watch(coachApiKeyProvider);
  return key == null ? CoachProvider.gemini : CoachProvider.forKey(key);
}

/// Whether the service was worked out rather than chosen, which is what the
/// settings screen says out loud.
@riverpod
bool coachProviderIsGuessed(Ref ref) =>
    CoachProvider.fromWire(ref.watch(settingsProvider).value?.chatProvider) ==
    null;

/// The chosen model, or this service's default - which is also what happens
/// when someone swaps a key for one of the other service.
@riverpod
CoachModel coachModel(Ref ref) => CoachModel.resolve(
  ref.watch(settingsProvider).value?.chatModel,
  ref.watch(coachProviderProvider),
);

@riverpod
Stream<List<ChatThreadRow>> chatThreads(Ref ref) =>
    ref.watch(databaseProvider).chatDao.watchThreads();

@riverpod
Stream<List<ChatMessageRow>> chatMessages(Ref ref, String threadId) =>
    ref.watch(databaseProvider).chatDao.watchMessages(threadId);

/// Where the conversation stands: waiting for an answer, or holding a failure.
class CoachState {
  const CoachState({
    this.sending = false,
    this.error,
    this.keyRejected = false,
  });

  final bool sending;

  /// The last failure, in Dutch, or null. Shown under the conversation with a
  /// button to try again.
  final String? error;

  /// The failure was the key itself, so the answer is in the settings.
  final bool keyRejected;
}

/// Asking a question, from the first keystroke to the answer on screen.
@Riverpod(keepAlive: true)
class CoachController extends _$CoachController {
  @override
  CoachState build() => const CoachState();

  /// Starts a conversation named after the question that begins it.
  Future<String> startThread(String firstQuestion) async {
    final id = _uuid.v4();
    await ref.read(databaseProvider).chatDao.createThread(id, firstQuestion);
    return id;
  }

  /// Sends [question] in [threadId] and writes both sides down.
  ///
  /// The question is stored before it is sent: an answer that never arrives
  /// should not take the question with it.
  Future<void> ask({required String threadId, required String question}) async {
    final text = question.trim();
    if (text.isEmpty || state.sending) return;

    final db = ref.read(databaseProvider);
    // Straight from the database rather than from the stream: on a cold start
    // the first question can arrive before the settings have been delivered,
    // and "geen sleutel" would then be wrong rather than true.
    final stored = await db.settingsDao.apiKey();
    final key = stored == null || stored.isEmpty ? null : stored;
    if (key == null) {
      state = const CoachState(
        error: 'Er staat geen API-sleutel in de instellingen.',
        keyRejected: true,
      );
      return;
    }

    state = const CoachState(sending: true);
    await db.chatDao.addMessage(
      id: _uuid.v4(),
      threadId: threadId,
      role: 'user',
      content: text,
    );

    final history = [
      for (final row in await db.chatDao.messages(threadId))
        if (row.content != text || row.role != 'user')
          CoachTurn(role: row.role, text: row.content),
    ];

    final client = ref.read(coachClientFactoryProvider)(key);
    try {
      final settings = ref.read(settingsProvider).value;
      final profile = ref.read(userProfileProvider).value;
      final coach = Coach(
        client: client,
        tools: CoachTools(db),
        model: ref.read(coachModelProvider),
        system: buildCoachPrompt(
          now: DateTime.now(),
          weightUnit: settings?.unitWeight ?? 'kg',
          displayName: profile?.displayName,
          exerciseCount: await db.exercisesDao.countExercises(),
        ),
      );

      final answer = await coach.ask(history: history, question: text);

      await db.chatDao.addMessage(
        id: _uuid.v4(),
        threadId: threadId,
        role: 'assistant',
        content: answer.text,
        lookups: answer.lookups.isEmpty ? null : answer.lookups.join('\n'),
        inputTokens: answer.usage.inputTokens,
        outputTokens: answer.usage.outputTokens,
      );
      state = const CoachState();
    } on CoachException catch (error) {
      state = CoachState(error: error.message, keyRejected: error.badKey);
    } finally {
      client.close();
    }
  }

  void clearError() => state = const CoachState();

  /// One cheap call, to find out whether a key works before the user types a
  /// question and waits for a failure.
  Future<String?> testKey(String key) async {
    final client = ref.read(coachClientFactoryProvider)(key.trim());
    try {
      await client.send(
        system: 'Antwoord met het woord ok.',
        messages: [CoachMessage.user('ok')],
        tools: const [],
        model: ref.read(coachModelProvider),
        maxTokens: 8,
      );
      return null;
    } on CoachException catch (error) {
      return error.message;
    } finally {
      client.close();
    }
  }
}
