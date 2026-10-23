import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../chat/data/ai_client.dart';
import '../../chat/data/coach.dart';
import '../../chat/data/coach_tools.dart';
import '../../chat/domain/coach_budget.dart';
import '../../chat/domain/coach_prompt.dart';
import '../../chat/domain/coach_proposal.dart';
import '../../morning/data/morning_reporter.dart' show ReportClientFactory;
import 'plan_deload.dart';
import 'plan_prompt.dart';

const _uuid = Uuid();

/// What Sunday evening did with the schema being followed.
enum PlanCheckOutcome {
  /// No schema, or nothing to ask the coach.
  nothing,

  /// Its last week is over; Schema's says what next.
  ended,

  /// The coach proposed a change, waiting in the schema's conversation.
  proposed,

  /// The coach answered without a proposal.
  answered,

  /// There was something to ask, but no coach to ask: no key, the day's
  /// limit, or no connection.
  unavailable,
}

/// Sunday evening, for the schema being followed: how its week went.
///
/// A week in which every session was done needs nothing, unless the coach
/// keeps the numbers. Otherwise the coach looks back, in the schema's own
/// conversation: where a session was missed it proposes how to go on -
/// catch up, shift, or do the week again - as a card the user accepts or
/// leaves; and while it keeps the numbers it sets next week's. It writes
/// nothing else: on Sunday evening the coach proposes, it does not decide.
///
/// Runs with the weekly review, once a week, also from the alarm while the
/// app is closed.
class PlanWeekCheck {
  PlanWeekCheck(this.db, {ReportClientFactory? clientFactory})
    : _clientFactory =
          clientFactory ??
          ((key, provider) => AiClient(apiKey: key, provider: provider));

  final AppDatabase db;
  final ReportClientFactory _clientFactory;

  /// [weekStart] is the Monday of the week that ends.
  Future<PlanCheckOutcome> run(
    DateTime weekStart, {
    required DateTime now,
  }) async {
    final plan = await db.plansDao.running();
    if (plan == null) return PlanCheckOutcome.nothing;
    final week = plan.weekAt(weekStart);
    if (week < 1) return PlanCheckOutcome.nothing;
    // A deload week may have passed; the next one belongs on the calendar.
    await schedulePlanDeload(db, plan, now: now);
    final weeks = plan.weeks ?? plan.planWeeks.length;
    if (week >= weeks) return PlanCheckOutcome.ended;

    final standing = await db.plansDao.standing(plan, week);
    final numbers = plan.progressionKind == PlanProgression.coach;
    if (standing.missing.isEmpty && !numbers) return PlanCheckOutcome.nothing;

    final settings = await db.settingsDao.getSettings();
    final key = settings.anthropicApiKey;
    if (key == null || key.isEmpty) return PlanCheckOutcome.unavailable;
    final chosen = CoachProvider.fromWire(settings.chatProvider);
    final provider = chosen != null && kOfferedProviders.contains(chosen)
        ? chosen
        : kOfferedProviders.first;
    final spent = await db.chatDao.usageSince(coachDayStart(now, provider));
    final limit = settings.coachDailyLimit ?? kDefaultDailyLimit;
    if (limit > 0 && spent.requests >= limit) {
      return PlanCheckOutcome.unavailable;
    }

    final threadId = switch (await db.chatDao.threadForPlan(plan.id)) {
      final thread? => thread.id,
      null => await () async {
        final id = _uuid.v4();
        await db.chatDao.createThread(id, plan.name, planId: plan.id);
        return id;
      }(),
    };
    final sessions = {
      for (final session in await db.plansDao.sessions(plan.id))
        session.id: session.name,
    };
    String names(Iterable<String> ids) =>
        ids.map((id) => sessions[id] ?? '').join(', ');
    final done = [
      for (final id in standing.sessions)
        if (standing.done.contains(id)) id,
    ];
    final question = [
      'Het is zondagavond. Week $week van $weeks van het schema is voorbij.',
      'Gedaan: ${done.isEmpty ? 'niets' : names(done)}.',
      if (standing.missing.isNotEmpty) ...[
        'Niet gedaan: ${names(standing.missing)}.',
        'Stel met propose_plan_change voor hoe het verder moet: inhalen, de '
            'volgorde of de dagen verschuiven, of de week overdoen door er '
            'een week bij te zetten. De gebruiker beslist; zonder akkoord '
            'verandert er niets.',
      ],
      if (numbers)
        'Zet met set_week_numbers de gewichten en herhalingen van week '
            '${week + 1}, uit exercise_history: zwaarder waar alle sets '
            'lukten, gelijk waar niet.${plan.weekPlan(week + 1).isDeload ? ' Week ${week + 1} is een deloadweek; die maakt de app zelf lichter, dus zet de cijfers als voor een gewone week.' : ''}',
      'Schrijf daarna hoogstens drie korte zinnen voor de gebruiker.',
    ].join('\n');

    final notes = settings.coachMemory
        ? await db.coachNotesDao.notes()
        : const <CoachNoteRow>[];
    final history = [
      for (final row in await db.chatDao.messages(threadId))
        CoachTurn(role: row.role, text: row.content),
    ];
    final client = _clientFactory(key, provider);
    try {
      final answer = await Coach(
        client: client,
        tools: CoachTools(
          db,
          health: settings.coachSeesHealth,
          planId: plan.id,
          sunday: true,
          numbers: numbers,
        ),
        model: CoachModel.resolveWire(settings.chatModel, provider),
        system: buildCoachPrompt(
          now: now,
          weightUnit: settings.unitWeight,
          exerciseCount: await db.exercisesDao.countExercises(),
          seesHealth: settings.coachSeesHealth,
          notes: describeNotes([
            for (final note in notes)
              (id: note.id, kind: note.kind, text: note.note),
          ]),
          situation: 'zondagavond; je kijkt terug op week $week van het schema',
          plan: await describePlanOf(db, plan, now),
        ),
      ).ask(history: history, question: question);

      await db.chatDao.addMessage(
        id: _uuid.v4(),
        threadId: threadId,
        role: 'assistant',
        content: answer.text,
        lookups: answer.lookups.isEmpty ? null : answer.lookups.join('\n'),
        requests: answer.requests,
        proposals: answer.proposals.isEmpty
            ? null
            : encodeProposals(answer.proposals),
        inputTokens: answer.usage.inputTokens,
        outputTokens: answer.usage.outputTokens,
      );
      return answer.proposals.any((p) => p.kind == ProposalKind.planChange)
          ? PlanCheckOutcome.proposed
          : PlanCheckOutcome.answered;
    } on CoachException {
      return PlanCheckOutcome.unavailable;
    } finally {
      client.close();
    }
  }
}
