import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptics and short system sounds.
///
/// The approved package list has no audio player, so the distinct "tones" the
/// brief asks for are built from the platform's own feedback primitives: a
/// different haptic pattern plus the system click for a checked set, a heavier
/// triple tap for a personal record, and the scheduled local notification
/// (which carries the system alert sound) for the end of the rest timer.
///
/// Every method swallows its own errors. A device without a vibrator, or a
/// platform channel that is not wired up, must never stop a set from being
/// logged or a rest timer from starting.
class FeedbackService {
  const FeedbackService({
    this.hapticsEnabled = true,
    this.setCheckSoundEnabled = true,
  });

  final bool hapticsEnabled;
  final bool setCheckSoundEnabled;

  FeedbackService copyWith({
    bool? hapticsEnabled,
    bool? setCheckSoundEnabled,
  }) {
    return FeedbackService(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      setCheckSoundEnabled: setCheckSoundEnabled ?? this.setCheckSoundEnabled,
    );
  }

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      debugPrint('FitLog: feedback niet beschikbaar ($error)');
    }
  }

  /// A set was checked off.
  Future<void> setCompleted() => _guarded(() async {
    if (hapticsEnabled) await HapticFeedback.mediumImpact();
    if (setCheckSoundEnabled) await SystemSound.play(SystemSoundType.click);
  });

  /// A set was unchecked.
  Future<void> setUncompleted() => _guarded(() async {
    if (hapticsEnabled) await HapticFeedback.selectionClick();
  });

  /// A personal record: heavier, and repeated so it reads as different.
  Future<void> personalRecord() => _guarded(() async {
    if (!hapticsEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.heavyImpact();
  });

  /// The rest timer ran out while the app is in the foreground.
  Future<void> restFinished() => _guarded(() async {
    if (hapticsEnabled) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.lightImpact();
    }
    await SystemSound.play(SystemSoundType.alert);
  });

  /// A number changed on the keypad.
  Future<void> tick() => _guarded(() async {
    if (hapticsEnabled) await HapticFeedback.selectionClick();
  });

  /// Something was removed.
  Future<void> destructive() => _guarded(() async {
    if (hapticsEnabled) await HapticFeedback.heavyImpact();
  });
}
