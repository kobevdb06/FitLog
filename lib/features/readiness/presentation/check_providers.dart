/// The check before a session, for the screens that show it.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../dashboard/domain/today_plan.dart';
import '../../dashboard/presentation/today_providers.dart';
import '../../progress/presentation/recovery_providers.dart';
import '../../routines/presentation/routine_providers.dart';
import '../domain/training_check.dart';

part 'check_providers.g.dart';

/// You this morning. Null while the nights and the watch are read.
///
/// Worked out again when what it reads changes, and when you come back to
/// the app - the hours a muscle still needs went down meanwhile, and so may
/// the day have changed: every check rests on this one.
@riverpod
CheckBody? checkBodyToday(Ref ref) {
  final nights = ref.watch(sleepEntriesProvider).value;
  final vitals = ref.watch(vitalsDaysProvider).value;
  if (nights == null || vitals == null) return null;
  return checkBody(now: DateTime.now(), nights: nights, vitals: vitals);
}

/// The check of the session [routineId]. Null while what it reads is
/// loading.
@riverpod
TrainingCheck? trainingCheck(Ref ref, String routineId) {
  final detail = ref.watch(routineDetailProvider(routineId)).value;
  final estimates = ref.watch(recoveryEstimatesProvider).value;
  final body = ref.watch(checkBodyTodayProvider);
  if (detail == null || estimates == null || body == null) return null;
  return checkSession(
    routineId: routineId,
    routineName: detail.routine.name,
    muscleSets: sessionMuscleSets(detail),
    estimates: estimates,
    body: body,
    now: DateTime.now(),
  );
}

/// What the check says about today: the session Vandaag leads with, and with
/// a schema the other sessions of the week it is weighed against.
///
/// Null when there is nothing to check - no session, or one already done
/// today - while it loads, and when the check knows nothing worth a line:
/// no recent session of its muscles and nothing about your night.
@riverpod
TodayCheck? todayCheck(Ref ref) {
  final plan = ref.watch(todayPlanProvider);
  final lead = plan.lead;
  if (lead == null || lead.doneToday) return null;
  final check = ref.watch(trainingCheckProvider(lead.routine.id));
  if (check == null || !check.informed) return null;

  final others = <TrainingCheck>[];
  if (plan.kind == TodayPlanKind.plan) {
    for (final other in plan.rest) {
      final weighed = ref.watch(trainingCheckProvider(other.routine.id));
      if (weighed == null) return null;
      others.add(weighed);
    }
  }
  return weighToday(check, others);
}
