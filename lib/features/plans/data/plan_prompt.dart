import '../../../core/calc/schedule.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../chat/domain/coach_prompt.dart';

/// What the coach is told in the conversation of [plan], at [now].
String describePlanOf(TrainingPlanRow plan, DateTime now) => describePlanThread(
  status: plan.state.wire,
  goal: plan.goal,
  split: switch (plan.splitKind) {
    PlanSplit.coach => 'kies zelf een split die past bij het doel en de dagen',
    PlanSplit.custom =>
      'zoals de gebruiker het beschrijft: "${plan.splitNote ?? ''}"',
    final split => split.label,
  },
  days: [
    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
      if (WeekdaySet(plan.days).has(d)) Formatters.weekdayName(d),
  ],
  coachSetsNumbers: plan.progressionKind == PlanProgression.coach,
  week: plan.weekAt(now),
  weeks: plan.weeks,
);
