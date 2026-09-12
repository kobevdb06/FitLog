/// Estimates how long a muscle group is likely to need before it is ready
/// again, from what the user logged and nothing else.
///
/// The estimate is deliberately modest about what it knows. Sleep, food,
/// stress, age, illness and how sore you actually are all outweigh training
/// volume, and none of them are in the database. What is in the database is
/// how hard this session was **compared to your own recent sessions for that
/// muscle**, which is the only comparison that survives the differences
/// between people - and, since the user rates the session afterwards, how it
/// felt.
///
/// Nothing here is advice. It is a reading of a logbook.
library;

import '../db/enums.dart';

/// How much of a set's load a secondary muscle takes.
///
/// Shared with the muscle map on the summary screen so the two never disagree
/// about what a session worked.
const double kSecondaryMuscleShare = 0.4;

/// Sessions older than this do not inform the baseline.
const Duration kRecoveryHistoryWindow = Duration(days: 56);

/// An exercise the user has not done inside this window counts as
/// unaccustomed. Unfamiliar movements are the classic reason for being unable
/// to walk two days later.
const Duration kUnaccustomedWindow = Duration(days: 28);

/// How many earlier sessions a muscle needs before its baseline means
/// anything. Below this the estimate is marked provisional.
const int kSessionsForBaseline = 3;

/// The load ratio is clamped before it is applied: one enormous session should
/// stretch the estimate, not triple it.
const double kMinLoadRatio = 0.6;
const double kMaxLoadRatio = 1.5;

/// The RPE an ordinary hard working set sits at, and how much one point above
/// or below it moves the estimate.
///
/// Deliberately small. An RPE is one person's impression of one set, given
/// while out of breath; it deserves a nudge, not a verdict. Two full points
/// above a normal day - every set at 10 - stretches the estimate by a tenth,
/// which is about three hours on a leg day.
const double kNeutralRpe = 8;
const double kRpeHoursPerPoint = 0.05;

/// Added on top, in hours, for the three things that leave a muscle sorer than
/// its tonnage suggests.
const double kFailureBonusHours = 12;
const double kPrAttemptBonusHours = 12;
const double kUnaccustomedBonusHours = 12;

/// The estimate never leaves this range, whatever the arithmetic says.
const double kMinRecoveryHours = 24;
const double kMaxRecoveryHours = 96;

/// Stands in when the user has never logged a body weight, so that
/// bodyweight work still counts for something.
const double kAssumedBodyWeightKg = 75;

/// Roughly how long each muscle group takes after an ordinary session.
///
/// Big muscles that move the whole body take longer than the small ones people
/// train several times a week. These are starting points that the load ratio
/// and the user's own rating then move; they are not claims about physiology.
const Map<String, double> kBaseRecoveryHours = {
  'quadriceps': 72,
  'hamstrings': 72,
  'bilspieren': 72,
  'onderrug': 72,
  'borst': 60,
  'lats': 60,
  'bovenrug': 60,
  'schouders': 48,
  'trapezius': 48,
  'adductoren': 48,
  'abductoren': 48,
  'nek': 36,
  'biceps': 36,
  'triceps': 36,
  'kuiten': 36,
  'buik': 36,
  'onderarmen': 36,
};

/// Used for a muscle name the table does not know, which can only come from an
/// exercise the user made themselves.
const double kDefaultBaseRecoveryHours = 48;

double baseRecoveryHours(String muscle) =>
    kBaseRecoveryHours[muscle] ?? kDefaultBaseRecoveryHours;

/// Reads the JSON array of muscle names stored on an exercise row.
///
/// Deliberately not `jsonDecode`: the column is written by the app and never
/// holds anything but a flat list of strings, and this runs over every set of
/// every session in the window.
List<String> decodeMuscleList(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length < 2) return const [];
  return trimmed
      .substring(1, trimmed.length - 1)
      .split(',')
      .map((s) => s.trim().replaceAll('"', ''))
      .where((s) => s.isNotEmpty)
      .toList();
}

/// One completed working set, with everything the estimate needs about the
/// session and the exercise it belongs to.
class RecoverySet {
  const RecoverySet({
    required this.workoutId,
    required this.startedAt,
    required this.exerciseId,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.category,
    required this.setType,
    required this.isPrAttempt,
    required this.effort,
    this.weightKg,
    this.reps,
    this.rpe,
  });

  final String workoutId;
  final DateTime startedAt;
  final String exerciseId;
  final String primaryMuscle;
  final List<String> secondaryMuscles;
  final ExerciseCategory category;
  final SetType setType;
  final bool isPrAttempt;
  final PerceivedEffort? effort;
  final double? weightKg;
  final int? reps;

  /// How hard this set felt, 1 to 10, when the user is keeping track of that.
  final double? rpe;
}

/// What one muscle got out of one session.
class MuscleSession {
  const MuscleSession({
    required this.muscle,
    required this.workoutId,
    required this.at,
    required this.loadKg,
    required this.exerciseIds,
    required this.hadFailureSets,
    required this.wasPrAttempt,
    required this.effort,
    this.averageRpe,
  });

  final String muscle;
  final String workoutId;
  final DateTime at;

  /// Volume in kilograms, with secondary muscles taking their share.
  final double loadKg;

  /// Which exercises hit this muscle, for the unaccustomed check.
  final Set<String> exerciseIds;

  final bool hadFailureSets;
  final bool wasPrAttempt;
  final PerceivedEffort? effort;

  /// The RPE of this muscle's sets in this session, weighted by how much load
  /// each of them put on it, or null when none were scored.
  ///
  /// Weighted rather than averaged flat: a heavy set at 9 says more about what
  /// the muscle went through than a light one at 6 does.
  final double? averageRpe;
}

/// One muscle's estimate, as of [RecoveryEstimate.trainedAt].
class RecoveryEstimate {
  const RecoveryEstimate({
    required this.muscle,
    required this.workoutId,
    required this.trainedAt,
    required this.recovery,
    required this.loadRatio,
    required this.provisional,
  });

  final String muscle;

  /// The session this estimate came out of - the last one to train the muscle.
  final String workoutId;

  final DateTime trainedAt;
  final Duration recovery;

  /// This session's load against the muscle's own recent baseline. 1.0 is an
  /// ordinary day for that muscle.
  final double loadRatio;

  /// True while the muscle has too little history for the baseline to mean
  /// anything, so the estimate is the starting point and little more.
  final bool provisional;

  DateTime get readyAt => trainedAt.add(recovery);

  bool isReadyAt(DateTime now) => !now.isBefore(readyAt);

  Duration remainingAt(DateTime now) {
    final left = readyAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// How far along the recovery is, 0 to 1.
  double progressAt(DateTime now) {
    if (recovery.inSeconds <= 0) return 1;
    final done = now.difference(trainedAt).inSeconds / recovery.inSeconds;
    return done.clamp(0.0, 1.0);
  }
}

/// The load one set puts on the muscles it works.
///
/// Bodyweight movements carry no weight in the log but plainly train the
/// muscle, so the user's own body weight stands in; on an assisted machine the
/// logged weight is what is taken off instead of added.
double setLoadKg(RecoverySet set, {double? bodyWeightKg}) {
  final reps = set.reps;
  if (!set.category.hasReps || reps == null || reps <= 0) return 0;

  final logged = set.weightKg ?? 0;
  final body = bodyWeightKg ?? kAssumedBodyWeightKg;

  final perRep = switch (set.category) {
    ExerciseCategory.bodyweight => body + logged,
    ExerciseCategory.assistedBodyweight => (body - logged).clamp(0.0, body),
    _ => logged,
  };
  return perRep * reps;
}

/// Groups completed sets into one entry per muscle per session.
///
/// Sets that carry no load at all - cardio, a duration hold, a rep count
/// without a weight on a machine - are left out rather than counted as zero: a
/// muscle that got nothing measurable should have no estimate, not a short
/// one.
List<MuscleSession> muscleSessions(
  Iterable<RecoverySet> sets, {
  double? bodyWeightKg,
}) {
  final byKey = <String, _Accumulator>{};

  for (final set in sets) {
    if (set.setType == SetType.warmup) continue;
    final load = setLoadKg(set, bodyWeightKg: bodyWeightKg);
    if (load <= 0) continue;

    void add(String muscle, double share) {
      if (muscle.isEmpty) return;
      byKey
          .putIfAbsent(
            '${set.workoutId} $muscle',
            () => _Accumulator(
              muscle: muscle,
              workoutId: set.workoutId,
              at: set.startedAt,
              effort: set.effort,
            ),
          )
          .add(
            load: load * share,
            exerciseId: set.exerciseId,
            failure: set.setType == SetType.failure,
            prAttempt: set.isPrAttempt,
            rpe: set.rpe,
          );
    }

    add(set.primaryMuscle, 1);
    for (final secondary in set.secondaryMuscles) {
      add(secondary, kSecondaryMuscleShare);
    }
  }

  final sessions = byKey.values.map((a) => a.build()).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return sessions;
}

/// The recovery time for one session of one muscle.
///
/// [baselineLoadKg] is what that muscle usually gets; null or zero means there
/// is nothing to compare against yet, and the ratio falls back to 1.
Duration recoveryDuration({
  required String muscle,
  required double loadKg,
  required double? baselineLoadKg,
  required bool hadFailureSets,
  required bool wasPrAttempt,
  required bool unaccustomed,
  required PerceivedEffort? effort,
  double? averageRpe,
}) {
  final ratio = (baselineLoadKg == null || baselineLoadKg <= 0)
      ? 1.0
      : loadKg / baselineLoadKg;

  var hours =
      baseRecoveryHours(muscle) * ratio.clamp(kMinLoadRatio, kMaxLoadRatio);

  // Both the RPE and the rating you give the session afterwards answer the
  // same question - how hard was that - so they are not applied on top of one
  // another. The RPE wins where there is one: it is per set and per muscle,
  // while the rating covers a whole evening in which the legs may have been
  // brutal and the arms an afterthought.
  hours *= averageRpe != null
      ? 1 + (averageRpe - kNeutralRpe) * kRpeHoursPerPoint
      : effort?.recoveryFactor ?? 1.0;

  if (hadFailureSets) hours += kFailureBonusHours;
  if (wasPrAttempt) hours += kPrAttemptBonusHours;
  if (unaccustomed) hours += kUnaccustomedBonusHours;

  final clamped = hours.clamp(kMinRecoveryHours, kMaxRecoveryHours);
  return Duration(minutes: (clamped * 60).round());
}

/// One estimate per muscle, based on the most recent session for each.
///
/// [sessions] is everything inside [kRecoveryHistoryWindow]; the earlier
/// sessions are what the latest one is measured against.
List<RecoveryEstimate> estimateRecovery(List<MuscleSession> sessions) {
  final byMuscle = <String, List<MuscleSession>>{};
  for (final session in sessions) {
    byMuscle.putIfAbsent(session.muscle, () => []).add(session);
  }

  final estimates = <RecoveryEstimate>[];
  for (final entry in byMuscle.entries) {
    final ordered = entry.value.toList()..sort((a, b) => a.at.compareTo(b.at));
    final latest = ordered.last;
    final earlier = ordered.sublist(0, ordered.length - 1);

    final baseline = earlier.isEmpty
        ? null
        : _median(earlier.map((s) => s.loadKg).toList());

    final recovery = recoveryDuration(
      muscle: latest.muscle,
      loadKg: latest.loadKg,
      baselineLoadKg: baseline,
      hadFailureSets: latest.hadFailureSets,
      wasPrAttempt: latest.wasPrAttempt,
      unaccustomed: _isUnaccustomed(latest, earlier),
      effort: latest.effort,
      averageRpe: latest.averageRpe,
    );

    estimates.add(
      RecoveryEstimate(
        muscle: latest.muscle,
        workoutId: latest.workoutId,
        trainedAt: latest.at,
        recovery: recovery,
        loadRatio: baseline == null || baseline <= 0
            ? 1
            : latest.loadKg / baseline,
        provisional: earlier.length < kSessionsForBaseline,
      ),
    );
  }

  estimates.sort((a, b) => b.readyAt.compareTo(a.readyAt));
  return estimates;
}

/// True when the session contained an exercise the user had not done for this
/// muscle inside [kUnaccustomedWindow].
bool _isUnaccustomed(MuscleSession latest, List<MuscleSession> earlier) {
  final since = latest.at.subtract(kUnaccustomedWindow);
  final familiar = <String>{
    for (final session in earlier)
      if (session.at.isAfter(since)) ...session.exerciseIds,
  };
  return latest.exerciseIds.any((id) => !familiar.contains(id));
}

double _median(List<double> values) {
  final sorted = values.toList()..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

class _Accumulator {
  _Accumulator({
    required this.muscle,
    required this.workoutId,
    required this.at,
    required this.effort,
  });

  final String muscle;
  final String workoutId;
  final DateTime at;
  final PerceivedEffort? effort;

  final Set<String> exerciseIds = {};
  double loadKg = 0;
  bool hadFailureSets = false;
  bool wasPrAttempt = false;

  /// Running totals for the load-weighted RPE, counting only the sets that
  /// were actually scored. Scoring half your sets should average those half,
  /// not treat the rest as zero.
  double rpeWeighted = 0;
  double rpeLoad = 0;

  void add({
    required double load,
    required String exerciseId,
    required bool failure,
    required bool prAttempt,
    double? rpe,
  }) {
    loadKg += load;
    exerciseIds.add(exerciseId);
    hadFailureSets |= failure;
    wasPrAttempt |= prAttempt;
    if (rpe != null && load > 0) {
      rpeWeighted += rpe * load;
      rpeLoad += load;
    }
  }

  MuscleSession build() => MuscleSession(
    muscle: muscle,
    workoutId: workoutId,
    at: at,
    loadKg: loadKg,
    exerciseIds: exerciseIds,
    hadFailureSets: hadFailureSets,
    wasPrAttempt: wasPrAttempt,
    effort: effort,
    averageRpe: rpeLoad > 0 ? rpeWeighted / rpeLoad : null,
  );
}
