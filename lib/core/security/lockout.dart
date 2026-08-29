/// Throttling for wrong PIN entries.
///
/// The first three attempts are free; from the fourth on the wait doubles,
/// capped at thirty seconds. There is deliberately no wipe-after-N-attempts:
/// losing a training history to a curious child is a worse outcome than a slow
/// brute force against a key that is already behind Argon2id.
library;

import 'dart:math' as math;

/// Attempts that are allowed without any delay.
const int kFreeAttempts = 3;

/// The longest the app ever makes someone wait.
const Duration kMaxLockout = Duration(seconds: 30);

/// The wait that applies after [consecutiveFailures] wrong entries.
Duration lockoutDelay(int consecutiveFailures) {
  if (consecutiveFailures < kFreeAttempts) return Duration.zero;
  final exponent = consecutiveFailures - kFreeAttempts;
  // 2, 4, 8, 16, 30, 30, ...
  final seconds = exponent >= 30
      ? kMaxLockout.inSeconds
      : math.min(kMaxLockout.inSeconds, 2 << exponent);
  return Duration(seconds: seconds);
}

/// How much of the lockout is still to run at [now].
Duration remainingLockout({
  required int consecutiveFailures,
  required DateTime? lastFailureAt,
  DateTime? now,
}) {
  if (lastFailureAt == null) return Duration.zero;
  final total = lockoutDelay(consecutiveFailures);
  if (total == Duration.zero) return Duration.zero;
  final elapsed = (now ?? DateTime.now()).difference(lastFailureAt);
  final left = total - elapsed;
  return left.isNegative ? Duration.zero : left;
}
