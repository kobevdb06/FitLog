/// What the dashboard offers you, and why.
///
/// A ladder from specific to general. The app used to open with "Workout van
/// vandaag" above whichever routine you had left alone longest, which was a
/// claim it could not back up: nothing told it what you do on a Tuesday. Now
/// the top rung is your own schedule, and each rung below it is what is left
/// to say when the one above is silent.
library;

import '../../../core/calc/schedule.dart';
import '../../../core/db/database.dart';

enum TodayPlanKind {
  /// Planned on today, and not all of it done yet.
  scheduled,

  /// Planned on today, and every one of them already finished.
  allDone,

  /// There is a schedule, and today is not part of it.
  rest,

  /// No schedule at all, so the routines you starred, most used first.
  favourites,

  /// Nothing planned and nothing starred: the routine you have left alone
  /// longest, which is what the dashboard always used to show.
  suggested,

  /// No routines yet.
  none,
}

/// A routine on the card, and whether today is already behind you.
class PlannedRoutine {
  const PlannedRoutine({required this.routine, required this.doneToday});

  final RoutineRow routine;

  /// Finished on this same training day. Offering it again would be the app
  /// forgetting what it watched you do an hour ago.
  final bool doneToday;
}

class TodayPlan {
  const TodayPlan({
    required this.kind,
    required this.routines,
    this.nextWeekday,
    this.daysUntilNext,
    this.nextRoutines = const [],
  });

  final TodayPlanKind kind;

  /// What to offer, in your own order. Empty for [TodayPlanKind.rest] and
  /// [TodayPlanKind.none].
  final List<PlannedRoutine> routines;

  /// The next day the schedule has something on it, 1 (Monday) to 7 (Sunday),
  /// and how far away it is. Null when nothing is planned anywhere.
  final int? nextWeekday;
  final int? daysUntilNext;

  /// What is planned on that day.
  final List<RoutineRow> nextRoutines;

  /// The one to put the big button under: the first you have not done yet.
  PlannedRoutine? get lead {
    for (final planned in routines) {
      if (!planned.doneToday) return planned;
    }
    return routines.isEmpty ? null : routines.first;
  }

  /// Everything else on the card, in order.
  List<PlannedRoutine> get rest {
    final first = lead;
    return [
      for (final planned in routines)
        if (!identical(planned, first)) planned,
    ];
  }
}

/// Reads the ladder top down and stops at the first rung with something on it.
TodayPlan buildTodayPlan({
  required List<RoutineRow> scheduled,
  required List<RoutineRow> favourites,
  required RoutineRow? suggested,
  required DateTime now,
}) {
  final today = trainingWeekday(now);
  final onToday = [
    for (final routine in scheduled)
      if (WeekdaySet(routine.scheduledDays).has(today)) routine,
  ];

  if (onToday.isNotEmpty) {
    final planned = [
      for (final routine in onToday)
        PlannedRoutine(routine: routine, doneToday: _doneToday(routine, now)),
    ];
    return _withNext(
      TodayPlan(
        kind: planned.every((p) => p.doneToday)
            ? TodayPlanKind.allDone
            : TodayPlanKind.scheduled,
        routines: planned,
      ),
      scheduled: scheduled,
      today: today,
    );
  }

  if (scheduled.isNotEmpty) {
    return _withNext(
      const TodayPlan(kind: TodayPlanKind.rest, routines: []),
      scheduled: scheduled,
      today: today,
    );
  }

  if (favourites.isNotEmpty) {
    return TodayPlan(
      kind: TodayPlanKind.favourites,
      routines: [
        for (final routine in favourites)
          PlannedRoutine(routine: routine, doneToday: _doneToday(routine, now)),
      ],
    );
  }

  if (suggested != null) {
    return TodayPlan(
      kind: TodayPlanKind.suggested,
      routines: [
        PlannedRoutine(
          routine: suggested,
          doneToday: _doneToday(suggested, now),
        ),
      ],
    );
  }

  return const TodayPlan(kind: TodayPlanKind.none, routines: []);
}

bool _doneToday(RoutineRow routine, DateTime now) {
  final last = routine.lastPerformedAt;
  if (last == null) return false;
  return sameTrainingDay(DateTime.fromMillisecondsSinceEpoch(last), now);
}

/// Fills in the next day with something on it, counting from tomorrow.
///
/// From tomorrow rather than today even on a rest day: today has already been
/// looked at, and searching from it again would answer "today" a week out.
TodayPlan _withNext(
  TodayPlan plan, {
  required List<RoutineRow> scheduled,
  required int today,
}) {
  for (var step = 1; step <= DateTime.daysPerWeek; step++) {
    final weekday = (today - 1 + step) % DateTime.daysPerWeek + 1;
    final onDay = [
      for (final routine in scheduled)
        if (WeekdaySet(routine.scheduledDays).has(weekday)) routine,
    ];
    if (onDay.isEmpty) continue;
    return TodayPlan(
      kind: plan.kind,
      routines: plan.routines,
      nextWeekday: weekday,
      daysUntilNext: step,
      nextRoutines: onDay,
    );
  }
  return plan;
}
