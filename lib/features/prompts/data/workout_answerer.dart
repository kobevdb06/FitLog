import 'dart:convert';

import '../../../core/db/database.dart';
import '../domain/coach_moments.dart';
import 'moment_asker.dart';
import 'workout_facts.dart';

/// Asks the coach the user's prompt about a finished workout, and stores the
/// answer with the workout, so opening it again costs nothing.
class WorkoutAnswerer {
  WorkoutAnswerer(this.db, {this.clientFactory});

  final AppDatabase db;
  final MomentClientFactory? clientFactory;

  /// The stored answer, or null when there was nothing to ask: no key, or no
  /// finished workout by that id. [prompt] is the one to ask instead of the
  /// stored one - the settings try a prompt before it is kept.
  Future<WorkoutAnswerRow?> answer(
    String workoutId, {
    MomentPrompt? prompt,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final settings = await db.settingsDao.getSettings();
    final facts = await buildWorkoutFacts(
      db,
      workoutId,
      health: settings.coachSeesHealth,
    );
    if (facts == null) return null;

    final asked = prompt ?? await MomentPrompt.load(db, CoachMoment.workout);
    final answer = await askMoment(
      db,
      prompt: asked,
      facts: facts,
      atLimit:
          'De coach zit aan je daglimiet, dus over deze workout schreef hij '
          'niets.',
      now: at,
      clientFactory: clientFactory,
      withWeightUnit: true,
    );
    if (answer == null) return null;

    await db.coachPromptsDao.saveAnswer(
      workoutId: workoutId,
      createdAt: at,
      prompt: asked.text,
      facts: jsonEncode(facts),
      coachText: answer.text,
      coachError: answer.error,
      requests: answer.usage == null ? null : 1,
      inputTokens: answer.usage?.inputTokens,
      outputTokens: answer.usage?.outputTokens,
    );
    return db.coachPromptsDao.answerFor(workoutId);
  }
}
