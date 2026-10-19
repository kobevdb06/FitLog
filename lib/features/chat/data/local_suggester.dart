import '../../../core/calc/deload.dart';
import '../../../core/calc/recovery.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../dashboard/domain/today_plan.dart';
import '../../progress/data/plateau_loader.dart';
import '../../progress/data/recovery_loader.dart';
import '../domain/coach_suggestions.dart';

/// Shorter than this, and a night is worth asking about.
const Duration kShortNight = Duration(hours: 6);

/// The questions, made on the phone from what the logbook says right now.
///
/// It reads what the dashboard reads, and sends none of it anywhere: a
/// question only leaves when you tap it, and then you have seen every word.
class LocalCoachSuggester implements CoachSuggester {
  LocalCoachSuggester(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _now;

  @override
  Future<List<CoachSuggestion>> suggest() async =>
      suggestQuestions(await facts());

  Future<SuggestionFacts> facts() async {
    final now = _now();
    final settings = await db.settingsDao.getSettings();
    final health = settings.healthConnectEnabled;

    final running = await db.workoutsDao.getActiveWorkoutRow();
    String? exercise;
    if (running != null) {
      final detail = await db.workoutsDao.getWorkoutDetail(running.id);
      for (final item in detail?.exercises ?? const <WorkoutExerciseDetail>[]) {
        if (item.sets.any((set) => !set.isCompleted && !set.isSkipped)) {
          exercise = item.exercise.name;
          break;
        }
      }
    }

    final deload = await db.deloadDao.onAt(now);

    final plan = buildTodayPlan(
      scheduled: await db.routinesDao.scheduledRoutines(),
      favourites: const [],
      suggested: null,
      now: now,
    );

    RecoveryEstimate? slowest;
    for (final estimate in await loadRecoveryEstimates(
      db,
      now: now,
      healthConnect: health,
    )) {
      if (estimate.isReadyAt(now)) continue;
      if (slowest == null ||
          estimate.remainingAt(now) > slowest.remainingAt(now)) {
        slowest = estimate;
      }
    }

    // The longest standing still comes first.
    final plateaus = await loadPlateaus(db, now: now, healthConnect: health);
    final weeks = weeksWithoutBreak(
      now: now,
      sessions: await db.workoutsDao.ordinarySessionStarts(),
      deloads: [
        for (final row in await db.deloadDao.all())
          (from: row.from, until: row.until),
      ],
    );
    final snoozed = settings.deloadSnoozedUntil;
    final due =
        settings.deloadSuggest &&
        (snoozed == null || now.millisecondsSinceEpoch >= snoozed) &&
        await db.deloadDao.currentAt(now) == null &&
        deloadDue(
              weeks: weeks,
              stalled: [for (final p in plateaus) p.exercise.name],
              weeksLimit: settings.deloadSuggestWeeks,
              stalledLimit: settings.deloadSuggestStalled,
            ) !=
            null;

    final latest = await db.recordsDao.newestRecord();
    final record =
        latest != null &&
            now.difference(
                  DateTime.fromMillisecondsSinceEpoch(latest.record.achievedAt),
                ) <
                const Duration(days: 7)
        ? latest.exercise.name
        : null;

    final dates = await db.workoutsDao.finishedWorkoutDates();

    // Last night: the one that ended this morning. From the watch only when
    // the coach may see what the watch saw - the question names it.
    Duration? lastNight;
    for (final night in await db.recoveryDao.sleepSince(
      now.subtract(const Duration(hours: 20)),
    )) {
      final woke = DateTime.fromMillisecondsSinceEpoch(night.wokeAt);
      if (woke.isAfter(now) || _days(woke, now) != 0) continue;
      if (night.source != null && !settings.coachSeesHealth) continue;
      final slept = woke.difference(
        DateTime.fromMillisecondsSinceEpoch(night.fellAsleepAt),
      );
      if (slept < kShortNight) lastNight = slept;
    }

    return SuggestionFacts(
      workout: running?.name,
      exercise: exercise,
      deloadDay: deload?.dayAt(now),
      deloadDays: deload?.days,
      plannedToday: plan.kind == TodayPlanKind.scheduled
          ? plan.lead?.routine.name
          : null,
      recovering: slowest?.muscle,
      recoveringHours: slowest == null
          ? null
          : (slowest.remainingAt(now).inMinutes / 60).ceil(),
      stalled: plateaus.firstOrNull?.exercise.name,
      stalledWeeks: plateaus.firstOrNull?.plateau.weeksAt(now),
      weeksWithoutBreak: weeks,
      deloadDue: due,
      record: record,
      daysSinceLast: dates.isEmpty ? null : _days(dates.last, now),
      workouts: dates.length,
      lastNight: lastNight,
      dayOfYear: _days(DateTime(now.year), now),
    );
  }

  /// Whole calendar days from [from] to [to], whatever the clocks did.
  static int _days(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}
