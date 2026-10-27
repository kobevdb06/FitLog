/// The check before a session: are the muscles it works recovered, and are
/// you - worked out by the app from what it already knows, never by the
/// coach.
///
/// Three kinds of sign, each counted once however much of it there is: a
/// muscle the session works that still needs a good while, a short or poor
/// night, and a watch that says this morning is off your usual. None and the
/// session is ready; one and you go, knowing it; two or more and the session
/// had better wait. Like the recovery estimate it reads, it is a reading of
/// a logbook, not advice.
library;

import '../../../core/calc/recovery.dart';
import '../../../core/calc/sleep_score.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';

/// A muscle counts for a session from this many working sets on it as the
/// main muscle. One set of something is not what a session is about.
const int kCheckMinSets = 3;

/// A muscle is a sign when it needs longer than this still: a few hours
/// short is within what an estimate can tell apart.
const Duration kCheckMuscleSlack = Duration(hours: 12);

/// A night shorter than this, or scored below [kCheckLowScore], is a sign.
const Duration kCheckShortNight = Duration(hours: 6);
const int kCheckLowScore = 60;

enum CheckSign { muscles, night, heart }

enum CheckVerdict {
  /// No sign.
  ready,

  /// One sign: go, and know it.
  note,

  /// Two or more: better another session, or lighter.
  wait,
}

/// A muscle the session works, and how far along its recovery is.
class CheckMuscle {
  const CheckMuscle({
    required this.muscle,
    required this.sets,
    this.left = Duration.zero,
    this.progress = 1,
  });

  final String muscle;

  /// Working sets on it, as the main muscle.
  final int sets;

  /// How long it still needs; zero when it is ready.
  final Duration left;

  /// How far along, 0 to 1.
  final double progress;

  bool get holdsBack => left > kCheckMuscleSlack;
}

/// You, this morning: the same for every session of the day.
class CheckBody {
  const CheckBody({
    this.slept,
    this.score,
    this.usualSleep,
    this.hrvMs,
    this.usualHrvMs,
    this.restingHr,
    this.usualRestingHr,
  });

  /// The night that ended today, and its score.
  final Duration? slept;
  final int? score;

  /// Your usual night over the four weeks before, when there are enough.
  final Duration? usualSleep;

  /// This morning's readings and your usual, when there is a usual.
  final double? hrvMs;
  final double? usualHrvMs;
  final double? restingHr;
  final double? usualRestingHr;

  double? get hrvDrop =>
      hrvMs == null || usualHrvMs == null ? null : 1 - hrvMs! / usualHrvMs!;

  double? get restingHrRise => restingHr == null || usualRestingHr == null
      ? null
      : restingHr! - usualRestingHr!;

  bool get shortNight =>
      (slept != null && slept! < kCheckShortNight) ||
      (score != null && score! < kCheckLowScore);

  /// The same lines the recovery estimate starts to count from.
  bool get heartOff =>
      (hrvDrop ?? 0) > kHrvDropNoEffect ||
      (restingHrRise ?? 0) > kRestingHrRiseNoEffect;

  /// Whether there is anything about you to go on.
  bool get known => slept != null || hrvDrop != null || restingHrRise != null;
}

/// The check of one session.
class TrainingCheck {
  const TrainingCheck({
    required this.routineId,
    required this.routineName,
    required this.muscles,
    required this.body,
    this.recentlyTrained = false,
  });

  final String routineId;
  final String routineName;

  /// The muscles it works, the most sets first.
  final List<CheckMuscle> muscles;

  final CheckBody body;

  /// Whether one of its muscles has a recovery to look at. Without that and
  /// without anything about you, the check knows nothing worth a line.
  final bool recentlyTrained;

  bool get informed => recentlyTrained || body.known;

  Set<CheckSign> get signs => {
    if (muscles.any((m) => m.holdsBack)) CheckSign.muscles,
    if (body.shortNight) CheckSign.night,
    if (body.heartOff) CheckSign.heart,
  };

  CheckVerdict get verdict => switch (signs.length) {
    0 => CheckVerdict.ready,
    1 => CheckVerdict.note,
    _ => CheckVerdict.wait,
  };

  /// All the hours its muscles still need: what tells two sessions that
  /// both wait apart.
  Duration get shortfall =>
      muscles.fold(Duration.zero, (sum, m) => sum + m.left);

  /// What stands against it, in words: `quadriceps nog 14 u`,
  /// `5 u 10 geslapen, score 58`, `HRV 18% onder je gewone`.
  List<String> get reasons {
    final night = <String>[
      if (body.slept case final slept?) '${checkHours(slept)} geslapen',
      if (body.score case final score?) 'score $score',
    ].join(', ');
    return [
      for (final m in muscles)
        if (m.holdsBack) '${m.muscle} nog ${(m.left.inMinutes / 60).ceil()} u',
      if (body.shortNight) night,
      if ((body.hrvDrop ?? 0) > kHrvDropNoEffect)
        'HRV ${(body.hrvDrop! * 100).round()}% onder je gewone',
      if ((body.restingHrRise ?? 0) > kRestingHrRiseNoEffect)
        'rusthartslag ${body.restingHrRise!.round()} hoger dan gewoonlijk',
    ];
  }

  /// The one line on a card: `Klaar: je spieren zijn hersteld, 7 u 40
  /// geslapen`, or what stands against it.
  String get line {
    if (verdict != CheckVerdict.ready) return _capitalized(reasons.join(' · '));
    final said = [
      if (muscles.isNotEmpty)
        muscles.every((m) => m.left == Duration.zero)
            ? 'je spieren zijn hersteld'
            : 'je spieren zijn bijna hersteld',
      if (body.slept case final slept?) '${checkHours(slept)} geslapen',
    ];
    return said.isEmpty ? 'Klaar' : 'Klaar: ${said.join(', ')}';
  }
}

/// `7 u 40`, or `7 u` on the hour.
String checkHours(Duration d) {
  final minutes = d.inMinutes.remainder(60);
  return minutes == 0 ? '${d.inHours} u' : '${d.inHours} u $minutes';
}

String _capitalized(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Working sets per main muscle in [routine].
Map<String, int> sessionMuscleSets(RoutineDetail routine) {
  final sets = <String, int>{};
  for (final exercise in routine.exercises) {
    final working = exercise.sets
        .where((s) => SetType.fromWire(s.setType) != SetType.warmup)
        .length;
    if (working == 0) continue;
    final muscle = exercise.exercise.primaryMuscle;
    sets[muscle] = (sets[muscle] ?? 0) + working;
  }
  return sets;
}

/// Checks one session at [now].
TrainingCheck checkSession({
  required String routineId,
  required String routineName,
  required Map<String, int> muscleSets,
  required List<RecoveryEstimate> estimates,
  required CheckBody body,
  required DateTime now,
}) {
  final byMuscle = {for (final e in estimates) e.muscle: e};
  var recent = false;
  final muscles = <CheckMuscle>[];
  for (final MapEntry(key: muscle, value: sets) in muscleSets.entries) {
    if (sets < kCheckMinSets) continue;
    final estimate = byMuscle[muscle];
    if (estimate != null &&
        now.difference(estimate.trainedAt) <
            Duration(minutes: (kMaxRecoveryHours * 60).round())) {
      recent = true;
    }
    muscles.add(
      CheckMuscle(
        muscle: muscle,
        sets: sets,
        left: estimate?.remainingAt(now) ?? Duration.zero,
        progress: estimate?.progressAt(now) ?? 1,
      ),
    );
  }
  muscles.sort((a, b) => b.sets.compareTo(a.sets));
  return TrainingCheck(
    routineId: routineId,
    routineName: routineName,
    muscles: muscles,
    body: body,
    recentlyTrained: recent,
  );
}

/// You on the morning of [now]: the night that ended today, and how this
/// morning's watch compares with your usual.
CheckBody checkBody({
  required DateTime now,
  required Iterable<SleepEntryRow> nights,
  required Iterable<VitalsDay> vitals,
}) {
  final day = DateTime(now.year, now.month, now.day);
  final from = DateTime(
    day.year,
    day.month,
    day.day - kVitalsBaselineWindow.inDays,
  );

  SleepEntryRow? last;
  final before = <Duration>[];
  for (final row in nights) {
    final woke = DateTime.fromMillisecondsSinceEpoch(row.wokeAt);
    final wokeDay = DateTime(woke.year, woke.month, woke.day);
    final length = Duration(milliseconds: row.wokeAt - row.fellAsleepAt);
    if (wokeDay == day) {
      if (last == null || row.wokeAt > last.wokeAt) last = row;
    } else if (!wokeDay.isBefore(from) && wokeDay.isBefore(day)) {
      before.add(length);
    }
  }

  final morning = morningAgainstUsual(day, vitals);
  VitalsDay? today;
  for (final entry in vitals) {
    if (DateTime(entry.day.year, entry.day.month, entry.day.day) == day) {
      today = entry;
    }
  }

  final slept = last == null
      ? null
      : Duration(milliseconds: last.wokeAt - last.fellAsleepAt);
  before.sort();
  final drop = morning.hrvDrop;
  final rise = morning.restingHrRise;
  return CheckBody(
    slept: slept,
    score: last == null
        ? null
        : sleepScore(
            asleep: slept!,
            deepMinutes: last.deepMinutes,
            remMinutes: last.remMinutes,
            hrvDrop: drop,
            restingHrRise: rise,
          ).value,
    usualSleep: before.length < kVitalsForBaseline
        ? null
        : before.length.isOdd
        ? before[before.length ~/ 2]
        : (before[before.length ~/ 2 - 1] + before[before.length ~/ 2]) ~/ 2,
    // morningAgainstUsual gives the difference; the usual is what it was
    // taken from.
    hrvMs: drop == null ? null : today?.hrvMs,
    usualHrvMs: drop == null || drop >= 1 ? null : today!.hrvMs! / (1 - drop),
    restingHr: rise == null ? null : today?.restingHr,
    usualRestingHr: rise == null ? null : today!.restingHr! - rise,
  );
}

/// What today's check says: the session that was next, and - when it had
/// better wait - the one that is readiest instead.
class TodayCheck {
  const TodayCheck({required this.lead, this.instead, this.noneReady = false});

  final TrainingCheck lead;

  /// The open session of this week to do today instead. Null when the lead
  /// can go, or when no other session is readier.
  final TrainingCheck? instead;

  /// The lead had better wait and so does every other open session: a
  /// rest day, or lighter.
  final bool noneReady;

  /// The session Start goes to.
  TrainingCheck get start => instead ?? lead;
}

/// Weighs [lead] against the other open sessions of the week, in their
/// order. Without a schema there are none: the day is planned, and only
/// lighter or anyway are left.
TodayCheck weighToday(TrainingCheck lead, List<TrainingCheck> others) {
  if (lead.verdict != CheckVerdict.wait) return TodayCheck(lead: lead);
  TrainingCheck? best;
  for (final other in others) {
    if (other.verdict == CheckVerdict.wait) continue;
    if (best == null ||
        other.signs.length < best.signs.length ||
        (other.signs.length == best.signs.length &&
            other.shortfall < best.shortfall)) {
      best = other;
    }
  }
  return TodayCheck(
    lead: lead,
    instead: best,
    noneReady: best == null && others.isNotEmpty,
  );
}
