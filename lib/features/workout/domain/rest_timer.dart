/// The rest timer, modelled as an end timestamp rather than a countdown.
///
/// A `Timer` stops being trustworthy the moment the app goes to the
/// background, so the only thing that is stored is *when the rest ends*. The
/// UI derives the remaining seconds from the clock on every frame, which means
/// coming back from the background needs no correction at all.
library;

class RestTimerState {
  const RestTimerState({
    this.endsAt,
    this.totalSeconds = 0,
    this.exerciseName,
    this.finishedHandled = true,
  });

  const RestTimerState.idle()
    : endsAt = null,
      totalSeconds = 0,
      exerciseName = null,
      finishedHandled = true;

  /// When the rest is over. Null means no timer is running.
  final DateTime? endsAt;

  /// The length the timer was started with, used for the progress ring.
  final int totalSeconds;

  /// Shown on the full screen timer: what is coming up next.
  final String? exerciseName;

  /// Set once the "rest is over" feedback has been played, so it fires once.
  final bool finishedHandled;

  bool get isActive => endsAt != null;

  int remainingSeconds([DateTime? now]) {
    final end = endsAt;
    if (end == null) return 0;
    final left = end.difference(now ?? DateTime.now()).inMilliseconds;
    if (left <= 0) return 0;
    return (left / 1000).ceil();
  }

  bool hasElapsed([DateTime? now]) =>
      endsAt != null && remainingSeconds(now) <= 0;

  /// 0 at the start, 1 when the rest is over.
  double progress([DateTime? now]) {
    if (endsAt == null || totalSeconds <= 0) return 0;
    final done = totalSeconds - remainingSeconds(now);
    return (done / totalSeconds).clamp(0, 1);
  }

  RestTimerState copyWith({
    DateTime? endsAt,
    int? totalSeconds,
    String? exerciseName,
    bool? finishedHandled,
  }) {
    return RestTimerState(
      endsAt: endsAt ?? this.endsAt,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      exerciseName: exerciseName ?? this.exerciseName,
      finishedHandled: finishedHandled ?? this.finishedHandled,
    );
  }

  /// Starts a rest of [seconds] from [from].
  static RestTimerState start({
    required int seconds,
    required DateTime from,
    String? exerciseName,
  }) {
    return RestTimerState(
      endsAt: from.add(Duration(seconds: seconds)),
      totalSeconds: seconds,
      exerciseName: exerciseName,
      finishedHandled: false,
    );
  }

  /// Moves the end forward or backward, never below the current moment.
  RestTimerState adjust(int deltaSeconds, {DateTime? now}) {
    final end = endsAt;
    if (end == null) return this;
    final moment = now ?? DateTime.now();
    var next = end.add(Duration(seconds: deltaSeconds));
    if (next.isBefore(moment)) next = moment;
    return RestTimerState(
      endsAt: next,
      totalSeconds: totalSeconds + deltaSeconds > 0
          ? totalSeconds + deltaSeconds
          : totalSeconds,
      exerciseName: exerciseName,
      finishedHandled: finishedHandled,
    );
  }
}
