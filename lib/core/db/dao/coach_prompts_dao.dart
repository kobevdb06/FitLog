import 'package:drift/drift.dart';

import '../database.dart';

part 'coach_prompts_dao.drift.dart';

/// The geplande prompts - what the user asks the coach at a moment - what the
/// coach answered, and the user's own quick questions.
@DriftAccessor(
  tables: [
    CoachPromptsTable,
    WorkoutAnswersTable,
    MomentAnswersTable,
    QuickQuestionsTable,
  ],
)
class CoachPromptsDao extends DatabaseAccessor<AppDatabase>
    with _$CoachPromptsDaoMixin {
  CoachPromptsDao(super.db);

  /// Null while [moment] is as it comes.
  Future<CoachPromptRow?> promptRow(CoachMoment moment) => (select(
    coachPromptsTable,
  )..where((t) => t.moment.equals(moment.wire))).getSingleOrNull();

  Stream<List<CoachPromptRow>> watchPromptRows() =>
      select(coachPromptsTable).watch();

  /// Stores the whole of [moment] as the user left it. A null [prompt],
  /// [length] or [option] is the moment's own.
  Future<void> savePrompt({
    required CoachMoment moment,
    required bool enabled,
    String? prompt,
    AnswerLength? length,
    String? option,
    DateTime? at,
  }) => into(coachPromptsTable).insertOnConflictUpdate(
    CoachPromptsTableCompanion.insert(
      moment: moment.wire,
      enabled: enabled,
      prompt: Value(prompt),
      length: Value(length?.wire),
      option: Value(option),
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

  // --- The other moments ----------------------------------------------------

  Future<MomentAnswerRow?> momentAnswer(CoachMoment moment, String subject) =>
      (select(momentAnswersTable)..where(
            (t) => t.moment.equals(moment.wire) & t.subject.equals(subject),
          ))
          .getSingleOrNull();

  Stream<MomentAnswerRow?> watchMomentAnswer(
    CoachMoment moment,
    String subject,
  ) =>
      (select(momentAnswersTable)..where(
            (t) => t.moment.equals(moment.wire) & t.subject.equals(subject),
          ))
          .watchSingleOrNull();

  /// The newest answer at [moment], whatever it was about.
  Future<MomentAnswerRow?> latestMomentAnswer(CoachMoment moment) =>
      (select(momentAnswersTable)
            ..where((t) => t.moment.equals(moment.wire))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<MomentAnswerRow?> watchLatestMomentAnswer(CoachMoment moment) =>
      (select(momentAnswersTable)
            ..where((t) => t.moment.equals(moment.wire))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .watchSingleOrNull();

  /// Stores what the coach said at [moment] about [subject]. Asking again
  /// replaces it.
  Future<void> saveMomentAnswer({
    required CoachMoment moment,
    required String subject,
    required DateTime createdAt,
    required String prompt,
    required String facts,
    String? coachText,
    String? coachError,
    String? threadId,
    int? requests,
    int? inputTokens,
    int? outputTokens,
  }) => into(momentAnswersTable).insertOnConflictUpdate(
    MomentAnswersTableCompanion.insert(
      moment: moment.wire,
      subject: subject,
      createdAt: createdAt.millisecondsSinceEpoch,
      prompt: prompt,
      facts: facts,
      coachText: Value(coachText),
      coachError: Value(coachError),
      threadId: Value(threadId),
      requests: Value(requests),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
    ),
  );

  /// Takes away what was said about [subject] at [moment] - a workout that
  /// is deleted takes the word before it along.
  Future<void> deleteMomentAnswer(CoachMoment moment, String subject) =>
      (delete(momentAnswersTable)..where(
            (t) => t.moment.equals(moment.wire) & t.subject.equals(subject),
          ))
          .go();

  // --- Quick questions -------------------------------------------------------

  Stream<List<QuickQuestionRow>> watchQuickQuestions() =>
      (select(quickQuestionsTable)..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  /// Adds [question] at the end.
  Future<int> addQuickQuestion(String question, {DateTime? at}) async {
    final last = quickQuestionsTable.sortOrder.max();
    final row = await (selectOnly(
      quickQuestionsTable,
    )..addColumns([last])).getSingle();
    return into(quickQuestionsTable).insert(
      QuickQuestionsTableCompanion.insert(
        question: question,
        sortOrder: (row.read(last) ?? -1) + 1,
        createdAt: (at ?? DateTime.now()).millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> changeQuickQuestion(int id, String question) =>
      (update(quickQuestionsTable)..where((t) => t.id.equals(id))).write(
        QuickQuestionsTableCompanion(question: Value(question)),
      );

  Future<void> deleteQuickQuestion(int id) =>
      (delete(quickQuestionsTable)..where((t) => t.id.equals(id))).go();

  /// The name the question is asked by after a /, or null for none. Whether
  /// the name will do is for the one who asks it to say.
  Future<void> setQuickCommand(int id, String? command) =>
      (update(quickQuestionsTable)..where((t) => t.id.equals(id))).write(
        QuickQuestionsTableCompanion(command: Value(command)),
      );
}
