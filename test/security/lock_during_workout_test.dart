import 'package:fitlog/core/app/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether coming back to the app locks it (DECISIONS 279).
///
/// The running workout was a flag the workout screen set while it was
/// open. Hidden behind another tab and away for longer than the lock time -
/// to the music, in the gym - FitLog locked mid-session anyway, and the
/// buttons in the notification stopped working until the PIN.
void main() {
  bool locks({
    int awaySeconds = 120,
    int autoLockSeconds = 60,
    bool workoutRunning = false,
    bool lockDuringWorkout = false,
  }) => locksOnReturn(
    away: Duration(seconds: awaySeconds),
    autoLockSeconds: autoLockSeconds,
    workoutRunning: workoutRunning,
    lockDuringWorkout: lockDuringWorkout,
  );

  test('away longer than the lock time: locked', () {
    expect(locks(), isTrue);
    expect(locks(awaySeconds: 30), isFalse);
    expect(locks(autoLockSeconds: -1), isFalse, reason: 'Nooit');
    expect(locks(awaySeconds: 0, autoLockSeconds: 0), isTrue);
  });

  test('a running workout keeps it open, whatever screen it was on', () {
    expect(locks(workoutRunning: true), isFalse);
  });

  test('unless you asked for it to lock then too', () {
    expect(locks(workoutRunning: true, lockDuringWorkout: true), isTrue);
  });
}
