import '../../../core/calc/schedule.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../chat/domain/coach_prompt.dart';

/// What the coach is told in the conversation of [plan], at [now]: what it
/// is for, how far it is, and the one thing to do next.
///
/// A schema is built step by step: first the outline, then one session per
/// request, each approved by the user before the next is made. The state of
/// it all goes along here, so the coach does not have to look it up - and
/// the conversation itself can stay short.
Future<String> describePlanOf(
  AppDatabase db,
  TrainingPlanRow plan,
  DateTime now,
) async {
  final sessions = await db.plansDao.sessions(plan.id);
  final lines = <String>[];
  for (final (i, session) in sessions.indexed) {
    final head =
        '${i + 1}. ${session.name}'
        '${session.planWeekday == null ? '' : ' (${Formatters.weekdayName(session.planWeekday!)})'}'
        '${session.planFocus == null ? '' : ': ${session.planFocus}'}';
    final state = session.sessionState;
    if (state == PlanSessionState.planned) {
      lines.add('$head - nog te maken');
      continue;
    }
    final detail = await db.routinesDao.getRoutineDetail(session.id);
    final exercises = [
      for (final item in detail?.exercises ?? const [])
        _short(item.exercise.name, item.sets),
    ].join('; ');
    lines.add(
      '$head - ${state == PlanSessionState.proposed ? 'wacht op akkoord' : 'goedgekeurd'}: '
      '$exercises',
    );
  }

  final week = plan.weekAt(now);
  final next = sessions
      .where((s) => s.sessionState == PlanSessionState.planned)
      .firstOrNull;
  final waiting = sessions
      .where((s) => s.sessionState == PlanSessionState.proposed)
      .firstOrNull;
  final step = switch (plan.state) {
    PlanStatus.done => 'Het schema is afgelopen en verandert niet meer.',
    PlanStatus.running =>
      '${week >= 1 ? 'Het schema loopt, week $week${plan.weeks == null ? '' : ' van ${plan.weeks}'}.' : 'Het schema is gestart en begint maandag.'} '
          'Pas het alleen aan als de gebruiker erom vraagt: één sessie met '
          'save_plan_session, de opzet met save_plan_outline. Wat al gedaan '
          'is, blijft.',
    PlanStatus.draft when sessions.isEmpty =>
      'Stap 1: stel de opzet voor met save_plan_outline - een naam, de weken '
          '(4 tot 12, meestal met een deload als laatste), de sessies van een '
          'week met hun dag en hun focus in een paar woorden, en hoeveel '
          'werksets per spiergroep per week. Nog geen oefeningen. Vraag dan '
          'of de opzet goed is.',
    PlanStatus.draft when !plan.outlineApproved =>
      'De opzet wacht op het akkoord van de gebruiker. Vraagt die iets '
          'anders, pas ze dan aan met save_plan_outline; maak nog geen '
          'sessies.',
    PlanStatus.draft when waiting != null =>
      'Sessie ${waiting.name} wacht op het akkoord van de gebruiker. Vraagt '
          'die een wijziging, pas dan alleen ${waiting.name} aan met '
          'save_plan_session.',
    PlanStatus.draft when next != null =>
      'Maak nu alleen sessie ${next.name} met save_plan_session. Zoek elke '
          'oefening op met search_exercises en neem de naam exact over; kies '
          'gewichten uit exercise_history; houd rekening met de sessies die '
          'al goedgekeurd zijn en met de werksets per spiergroep. Leg daarna '
          'kort uit wat je koos en vraag of ze goed is.',
    PlanStatus.draft =>
      'Alle sessies zijn goedgekeurd: de gebruiker kan het schema starten.',
  };

  final volume = plan.weeklySets;
  return describePlanThread(
    step: step,
    goal: plan.goal,
    split: switch (plan.splitKind) {
      PlanSplit.coach =>
        'kies zelf een split die past bij het doel en de dagen',
      PlanSplit.custom =>
        'zoals de gebruiker het beschrijft: "${plan.splitNote ?? ''}"',
      final split => split.label,
    },
    days: [
      for (var d = DateTime.monday; d <= DateTime.sunday; d++)
        if (WeekdaySet(plan.days).has(d)) Formatters.weekdayName(d),
    ],
    coachSetsNumbers: plan.progressionKind == PlanProgression.coach,
    outline: [
      if (plan.weeks != null)
        'Opzet "${plan.name}": ${plan.weeks} weken'
            '${_deloads(plan)}.',
      if (volume.isNotEmpty)
        'Werksets per week: '
            '${[for (final MapEntry(:key, :value) in volume.entries) '$key $value'].join(', ')}.',
      if (lines.isNotEmpty) 'Sessies:\n${lines.join('\n')}',
    ],
  );
}

String _deloads(TrainingPlanRow plan) {
  final weeks = [
    for (final (i, week) in plan.planWeeks.indexed)
      if (week.isDeload) i + 1,
  ];
  return weeks.isEmpty ? '' : ', deload in week ${weeks.join(' en ')}';
}

/// `Bench Press 4×6 @ 100 kg` - the working sets of an exercise, short.
String _short(String name, List<RoutineSetRow> sets) {
  final working = [
    for (final s in sets)
      if (SetType.fromWire(s.setType) != SetType.warmup) s,
  ];
  if (working.isEmpty) return name;
  final first = working.first;
  final reps = first.targetReps ?? first.targetDurationSeconds;
  final weight = first.targetWeightKg;
  return '$name ${working.length}'
      '${reps == null ? '' : '×$reps${first.targetReps == null ? 's' : ''}'}'
      '${weight == null ? '' : ' @ ${_kg(weight)} kg'}';
}

String _kg(double kg) =>
    kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);
