import 'package:drift/drift.dart';

import '../database.dart';

part 'coach_prompts_dao.drift.dart';

/// The geplande prompts - what the user asks the coach at a moment - and what
/// the coach answered after a workout.
@DriftAccessor(tables: [CoachPromptsTable, WorkoutAnswersTable])
class CoachPromptsDao extends DatabaseAccessor<AppDatabase>
    with _$CoachPromptsDaoMixin {
  CoachPromptsDao(super.db);

  /// Null while [moment] is as it comes.
  Future<CoachPromptRow?> promptRow(CoachMoment moment) => (select(
    coachPromptsTable,
  )..where((t) => t.moment.equals(moment.wire))).getSingleOrNull();

  Stream<List<CoachPromptRow>> watchPromptRows() =>
      select(coachPromptsTable).watch();

  /// Stores the whole of [moment] as the user left it. A null [prompt] or
  /// [length] is the moment's own.
  Future<void> savePrompt({
    required CoachMoment moment,
    required bool enabled,
    String? prompt,
    AnswerLength? length,
    DateTime? at,
  }) => into(coachPromptsTable).insertOnConflictUpdate(
    CoachPromptsTableCompanion.insert(
      moment: moment.wire,
      enabled: enabled,
      prompt: Value(prompt),
      length: Value(length?.wire),
      updatedAt: (at ?? DateTime.now()).millisecondsSinceEpoch,
    ),
  );

  Future<WorkoutAnswerRow?> answerFor(String workoutId) => (select(
    workoutAnswersTable,
  )..where((t) => t.workoutId.equals(workoutId))).getSingleOrNull();

  Stream<WorkoutAnswerRow?> watchAnswer(String workoutId) => (select(
    workoutAnswersTable,
  )..where((t) => t.workoutId.equals(workoutId))).watchSingleOrNull();

  /// Stores what the coach said about [workoutId]. Asking again replaces it.
  Future<void> saveAnswer({
    required String workoutId,
    required DateTime createdAt,
    required String prompt,
    required String facts,
    String? coachText,
    String? coachError,
    int? requests,
    int? inputTokens,
    int? outputTokens,
  }) => into(workoutAnswersTable).insertOnConflictUpdate(
    WorkoutAnswersTableCompanion.insert(
      workoutId: workoutId,
      createdAt: createdAt.millisecondsSinceEpoch,
      prompt: prompt,
      facts: facts,
      coachText: Value(coachText),
      coachError: Value(coachError),
      requests: Value(requests),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
    ),
  );
}
