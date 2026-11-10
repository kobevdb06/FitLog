import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../domain/coach_moments.dart';
import 'moment_asker.dart';
import 'moment_facts.dart';

const _uuid = Uuid();

/// What the coach said at a moment, from whichever table holds it: after a
/// workout it stays with the workout, the rest by moment and subject.
class MomentAnswerView {
  const MomentAnswerView({
    required this.prompt,
    required this.createdAt,
    this.coachText,
    this.coachError,
    this.threadId,
  });

  factory MomentAnswerView.ofWorkout(WorkoutAnswerRow row) => MomentAnswerView(
    prompt: row.prompt,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    coachText: row.coachText,
    coachError: row.coachError,
  );

  factory MomentAnswerView.of(MomentAnswerRow row) => MomentAnswerView(
    prompt: row.prompt,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    coachText: row.coachText,
    coachError: row.coachError,
    threadId: row.threadId,
  );

  /// The words it was asked in, as they were then.
  final String prompt;
  final DateTime createdAt;
  final String? coachText;
  final String? coachError;

  /// The conversation it was put in, for a moment that answers in the chat.
  final String? threadId;
}

Future<MomentAnswerView?> readMomentAnswer(
  AppDatabase db,
  CoachMoment moment,
  String subject,
) async => moment == CoachMoment.workout
    ? switch (await db.coachPromptsDao.answerFor(subject)) {
        final row? => MomentAnswerView.ofWorkout(row),
        null => null,
      }
    : switch (await db.coachPromptsDao.momentAnswer(moment, subject)) {
        final row? => MomentAnswerView.of(row),
        null => null,
      };

Stream<MomentAnswerView?> watchMomentAnswer(
  AppDatabase db,
  CoachMoment moment,
  String subject,
) => moment == CoachMoment.workout
    ? db.coachPromptsDao
          .watchAnswer(subject)
          .map((row) => row == null ? null : MomentAnswerView.ofWorkout(row))
    : db.coachPromptsDao
          .watchMomentAnswer(moment, subject)
          .map((row) => row == null ? null : MomentAnswerView.of(row));

/// Asks the coach the user's prompt at a moment, about what it is about, and
/// keeps the answer: so seeing it again costs nothing.
class MomentAnswerer {
  MomentAnswerer(this.db, {this.clientFactory});

  final AppDatabase db;
  final MomentClientFactory? clientFactory;

  /// Whether [moment] should ask about [subject] by itself now: switched on,
  /// a coach to ask, and nothing asked about it yet - also not a question
  /// that failed, which waits for Opnieuw instead of going again on every
  /// look. A weighing at most once a week.
  Future<bool> isDue(
    CoachMoment moment,
    String subject, {
    DateTime? now,
  }) async {
    final key = (await db.settingsDao.getSettings()).anthropicApiKey;
    if (key == null || key.isEmpty) return false;
    if (!(await MomentPrompt.load(db, moment)).enabled) return false;
    // Only an answer that came keeps it from being asked: one that holds
    // nothing but an error - the day's limit, no connection - is asked again,
    // where it used to stay until you tapped Opnieuw (DECISIONS 251).
    if ((await readMomentAnswer(db, moment, subject))?.coachText != null) {
      return false;
    }
    if (moment == CoachMoment.weighing) {
      final last = await db.coachPromptsDao.latestMomentAnswer(moment);
      final at = now ?? DateTime.now();
      if (last != null &&
          at.difference(DateTime.fromMillisecondsSinceEpoch(last.createdAt)) <
              kWeighingEvery) {
        return false;
      }
    }
    return true;
  }

  /// The stored answer, or null when there was nothing to ask: no key, or
  /// nothing (any more) to say anything about. [prompt] is the one to ask
  /// instead of the stored one.
  Future<MomentAnswerView?> answer(
    CoachMoment moment,
    String subject, {
    MomentPrompt? prompt,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final settings = await db.settingsDao.getSettings();
    final facts = await momentFacts(
      db,
      moment,
      subject,
      health: settings.coachSeesHealth,
      now: at,
    );
    if (facts == null) return null;

    final asked = prompt ?? await MomentPrompt.load(db, moment);
    final answer = await askMoment(
      db,
      prompt: asked,
      facts: facts,
      atLimit: 'De coach zit aan je daglimiet, dus hier schreef hij niets.',
      now: at,
      clientFactory: clientFactory,
      withWeightUnit: switch (moment) {
        CoachMoment.workout ||
        CoachMoment.before ||
        CoachMoment.planDone ||
        CoachMoment.weighing ||
        CoachMoment.month => true,
        _ => false,
      },
    );
    if (answer == null) return null;
    final cost = answer.usage;

    if (moment == CoachMoment.workout) {
      await db.coachPromptsDao.saveAnswer(
        workoutId: subject,
        createdAt: at,
        prompt: asked.text,
        facts: jsonEncode(facts),
        coachText: answer.text,
        coachError: answer.error,
        requests: cost == null ? null : 1,
        inputTokens: cost?.inputTokens,
        outputTokens: cost?.outputTokens,
      );
      return readMomentAnswer(db, moment, subject);
    }

    // In the chat: the prompt and the answer as a conversation of their
    // own, to go on from. The cost is on the answer there, as for any
    // answer in the chat, and not counted twice here.
    String? threadId;
    if (moment.inChat && answer.text != null) {
      threadId = _uuid.v4();
      await db.chatDao.createThread(threadId, moment.title);
      await db.chatDao.addMessage(
        id: _uuid.v4(),
        threadId: threadId,
        role: 'user',
        content: asked.text,
      );
      await db.chatDao.addMessage(
        id: _uuid.v4(),
        threadId: threadId,
        role: 'assistant',
        content: answer.text!,
        requests: 1,
        inputTokens: cost?.inputTokens,
        outputTokens: cost?.outputTokens,
      );
    }
    await db.coachPromptsDao.saveMomentAnswer(
      moment: moment,
      subject: subject,
      createdAt: at,
      prompt: asked.text,
      facts: jsonEncode(facts),
      coachText: answer.text,
      coachError: answer.error,
      threadId: threadId,
      requests: threadId != null || cost == null ? null : 1,
      inputTokens: threadId != null ? null : cost?.inputTokens,
      outputTokens: threadId != null ? null : cost?.outputTokens,
    );
    return readMomentAnswer(db, moment, subject);
  }
}
