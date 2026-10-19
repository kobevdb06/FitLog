import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/security/key_material.dart';
import '../../chat/presentation/chat_providers.dart';
import '../domain/workout_notice.dart';
import 'workout_live_update.dart';
import 'workout_providers.dart';

part 'workout_coach.g.dart';

@Riverpod(keepAlive: true)
WorkoutCoach workoutCoach(Ref ref) => WorkoutCoach(ref);

/// The coach as the panel over another app asks it: through the running
/// app, which has the key and the logbook, into a conversation of its own
/// per workout - the same coach, with the same daily limit, and the answer
/// stored as any other.
///
/// Behind the PIN when there is one, although FitLog does not lock during a
/// workout: the coach's conversations are yours to open, and the panel opens
/// over whatever app is in front.
class WorkoutCoach {
  WorkoutCoach(this._ref, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final Ref _ref;
  final DateTime Function() _now;

  /// How long one unlock holds: a few questions in a row ask for it once.
  static const unlockedFor = Duration(minutes: 5);

  DateTime? _unlockedAt;

  bool get _unlocked {
    final at = _unlockedAt;
    return at != null && _now().difference(at) < unlockedFor;
  }

  /// A panel method, or null for one that is not the coach's.
  Future<Map<String, Object?>?> handle(
    String method,
    Map<Object?, Object?>? arguments, {
    required void Function(Map<String, Object?> event) send,
  }) async => switch (method) {
    'coachState' => state(),
    'coachUnlock' => unlock(
      pin: arguments?['pin'] as String?,
      biometric: arguments?['biometric'] == true,
    ),
    'coachAsk' => ask(arguments?['question'] as String? ?? '', send: send),
    _ => null,
  };

  /// What the coach panel opens with.
  Future<Map<String, Object?>> state() async {
    final key = await _ref.read(databaseProvider).settingsDao.apiKey();
    final status = await _ref.read(keyManagerProvider).status();
    final pin = status.mode == LockMode.pin;
    return {
      'available': key != null && key.isNotEmpty,
      'locked': pin && !_unlocked,
      'biometric': pin && status.biometricEnabled,
      'lockoutSeconds': status.remainingLockoutAt(_now()).inSeconds,
      'about': _about(),
      'thread': await _thread(),
    };
  }

  /// The PIN, checked as the lock screen checks it - with its wait after
  /// wrong tries - or a fingerprint the panel already took.
  Future<Map<String, Object?>> unlock({
    String? pin,
    bool biometric = false,
  }) async {
    if (biometric) {
      _unlockedAt = _now();
      return {'ok': true};
    }
    if (pin == null) return {'ok': false};
    final manager = _ref.read(keyManagerProvider);
    final wait = (await manager.status()).remainingLockoutAt(_now());
    if (wait > Duration.zero) {
      return {'ok': false, 'lockoutSeconds': wait.inSeconds};
    }
    try {
      await manager.unlockWithPin(pin);
      _unlockedAt = _now();
      return {'ok': true};
    } on InvalidSecretException {
      final after = await manager.status();
      return {
        'ok': false,
        'lockoutSeconds': after.remainingLockoutAt(_now()).inSeconds,
      };
    }
  }

  /// Asks [question], sending the answer on as it is written.
  Future<Map<String, Object?>> ask(
    String question, {
    required void Function(Map<String, Object?> event) send,
  }) async {
    final status = await _ref.read(keyManagerProvider).status();
    if (status.mode == LockMode.pin && !_unlocked) {
      return {'ok': false, 'locked': true};
    }
    final text = question.trim();
    if (text.isEmpty) return {'ok': false};

    final coach = _ref.read(coachControllerProvider.notifier);
    // The workout's own conversation, which the Chat tab shows too - and
    // which is still there after the app was closed in between.
    final workoutId = _ref.read(activeWorkoutProvider).value?.workout.id;
    final threadId = workoutId == null
        ? await coach.startThread(text)
        : await coach.workoutThread(workoutId);

    final writing = _ref.listen(coachControllerProvider, (_, next) {
      if (next.sending) {
        send({'type': 'writing', 'text': next.answer, 'looking': next.looking});
      }
    });
    try {
      await coach.ask(
        threadId: threadId,
        question: text,
        situation: _situation(),
      );
    } finally {
      writing.close();
    }

    final error = _ref.read(coachControllerProvider).error;
    if (error != null) {
      send({'type': 'error', 'message': error});
      return {'ok': false};
    }
    final messages = await _ref
        .read(databaseProvider)
        .chatDao
        .messages(threadId);
    final answer = messages.lastWhere((m) => m.role == 'assistant');
    send({
      'type': 'done',
      'text': answer.content,
      'lookups': answer.lookups?.split('\n') ?? const <String>[],
    });
    return {'ok': true};
  }

  /// The set it is about, for the panel's header.
  String? _about() {
    final set = _ref.read(workoutLiveUpdateProvider)?.current;
    if (set == null) return null;
    final values = noticeValues(set, _ref.read(formattersProvider));
    return [set.exerciseName, set.label, if (values != '-') values].join(' · ');
  }

  /// Where the question comes from, for the coach: mid-workout, between two
  /// sets, so a short answer.
  String? _situation() {
    final about = _about();
    if (about == null) return null;
    return 'de gebruiker vraagt dit midden in een training, tussen twee sets '
        '($about). Hou het kort.';
  }

  /// This workout's conversation so far, also what was asked in the Chat
  /// tab.
  Future<List<Map<String, Object?>>> _thread() async {
    final workoutId = _ref.read(activeWorkoutProvider).value?.workout.id;
    if (workoutId == null) return const [];
    final db = _ref.read(databaseProvider);
    final thread = await db.chatDao.threadForWorkout(workoutId);
    if (thread == null) return const [];
    return [
      for (final m in await db.chatDao.messages(thread.id))
        {'role': m.role, 'text': m.content},
    ];
  }
}
