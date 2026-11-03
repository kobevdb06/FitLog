import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/workout_answerer.dart';
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

/// What the coach said about [workoutId], if it was asked.
@riverpod
Stream<WorkoutAnswerRow?> workoutAnswer(Ref ref, String workoutId) =>
    ref.watch(databaseProvider).coachPromptsDao.watchAnswer(workoutId);

/// The workout finished last: the one the settings try a prompt on.
@riverpod
Stream<WorkoutRow?> lastFinishedWorkout(Ref ref) =>
    ref.watch(databaseProvider).workoutsDao.watchLastFinished();

class AskState {
  const AskState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

/// Asking the coach about one workout.
///
/// Kept while the app runs: a summary that is closed and opened again while
/// the coach is still writing must not ask a second time.
@Riverpod(keepAlive: true)
class WorkoutAsk extends _$WorkoutAsk {
  @override
  AskState build(String workoutId) => const AskState();

  bool _looked = false;

  /// Asks [prompt], or the stored one, and replaces what was there.
  Future<void> ask({MomentPrompt? prompt}) async {
    if (state.busy) return;
    state = const AskState(busy: true);
    try {
      await WorkoutAnswerer(
        ref.read(databaseProvider),
        clientFactory: ref.read(coachClientFactoryProvider),
      ).answer(workoutId, prompt: prompt);
      if (ref.mounted) state = const AskState();
    } on Object catch (error) {
      if (ref.mounted) {
        state = AskState(error: 'De coach vragen lukte niet: $error');
      }
    }
  }

  /// Right after the workout: asks once, when the prompt is on, there is a
  /// coach, and nothing was asked about it yet - also not a question that
  /// failed, which waits for Opnieuw instead of going again on every open.
  Future<void> askIfDue() async {
    // Once per run: the summary can be built twice before the first look
    // in the database is back.
    if (state.busy || _looked) return;
    _looked = true;
    final db = ref.read(databaseProvider);
    final key = (await db.settingsDao.getSettings()).anthropicApiKey;
    if (key == null || key.isEmpty) return;
    if (!(await MomentPrompt.load(db, CoachMoment.workout)).enabled) return;
    if (await db.coachPromptsDao.answerFor(workoutId) != null) return;
    await ask();
  }
}
