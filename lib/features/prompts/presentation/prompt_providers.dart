import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/moment_answerer.dart';
import '../data/moment_facts.dart';
import '../domain/coach_moments.dart';

part 'prompt_providers.g.dart';

/// Every moment, as the user left it.
@riverpod
Stream<List<MomentPrompt>> momentPrompts(Ref ref) =>
    ref.watch(databaseProvider).coachPromptsDao.watchPromptRows().map((rows) {
      final byMoment = {for (final row in rows) row.moment: row};
      return [
        for (final moment in CoachMoment.values)
          MomentPrompt.of(moment, byMoment[moment.wire]),
      ];
    });

/// One moment, as the user left it; null while it loads.
@riverpod
MomentPrompt? momentPrompt(Ref ref, CoachMoment moment) {
  final all = ref.watch(momentPromptsProvider).value;
  if (all == null) return null;
  return all.firstWhere((prompt) => prompt.moment == moment);
}

/// What the coach said at [moment] about [subject], if it was asked.
@riverpod
Stream<MomentAnswerView?> momentAnswer(
  Ref ref,
  CoachMoment moment,
  String subject,
) => watchMomentAnswer(ref.watch(databaseProvider), moment, subject);

/// The newest answer at [moment], whatever it was about: the milestone on
/// Profiel.
@riverpod
Stream<MomentAnswerRow?> latestMomentAnswer(Ref ref, CoachMoment moment) =>
    ref.watch(databaseProvider).coachPromptsDao.watchLatestMomentAnswer(moment);

/// The milestone [workoutId] reached, as a subject; null for an ordinary
/// workout.
@riverpod
Future<String?> milestoneReached(Ref ref, String workoutId) async {
  final reached = await milestoneReachedBy(
    ref.watch(databaseProvider),
    workoutId,
  );
  return reached == null
      ? null
      : MomentSubject.milestone(reached.kind, reached.step);
}

/// The workout finished last: the one the settings try a prompt on.
@riverpod
Stream<WorkoutRow?> lastFinishedWorkout(Ref ref) =>
    ref.watch(databaseProvider).workoutsDao.watchLastFinished();

/// The user's own questions, as buttons in the coach.
@riverpod
Stream<List<QuickQuestionRow>> quickQuestions(Ref ref) =>
    ref.watch(databaseProvider).coachPromptsDao.watchQuickQuestions();

class AskState {
  const AskState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Asking the coach at one moment about one thing.
///
/// Kept while the app runs: a screen that is closed and opened again while
/// the coach is still writing must not ask a second time.
@Riverpod(keepAlive: true)
class MomentAsk extends _$MomentAsk {
  @override
  AskState build(CoachMoment moment, String subject) => const AskState();

  bool _looked = false;

  MomentAnswerer get _answerer => MomentAnswerer(
    ref.read(databaseProvider),
    clientFactory: ref.read(coachClientFactoryProvider),
  );

  /// Asks [prompt], or the stored one, and replaces what was there.
  Future<void> ask({MomentPrompt? prompt}) async {
    if (state.busy) return;
    state = const AskState(busy: true);
    try {
      await _answerer.answer(moment, subject, prompt: prompt);
      if (ref.mounted) state = const AskState();
    } on Object catch (error) {
      if (ref.mounted) {
        state = AskState(
          error:
              'De coach vragen lukte niet. '
              '${AiClient.asCoachException(error).message}',
        );
      }
    }
  }

  /// When the screen it belongs on is shown: asks once, if it is due.
  Future<void> askIfDue() async {
    // Once per run: a screen can be built twice before the first look in
    // the database is back.
    if (state.busy || _looked) return;
    _looked = true;
    if (!await _answerer.isDue(moment, subject)) return;
    await ask();
  }
}
