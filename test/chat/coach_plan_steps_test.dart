import 'dart:convert';

import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/plans/data/plan_builder.dart';
import 'package:fitlog/features/plans/data/plan_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// A schema built step by step: the outline first, then one session at a
/// time, each approved by the user before the coach makes the next.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late CoachTools tools;
  final now = DateTime(2026, 10, 20);

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name) in [
      ('ex-bench', 'Bench Press'),
      ('ex-row', 'Barbell Row'),
      ('ex-squat', 'Squat'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }
    await db.plansDao.createDraft(
      id: 'p-1',
      goal: '140 kg bench',
      split: PlanSplit.pushPullLegs,
      days: WeekdaySet.of([1, 3, 5]).mask,
      progression: PlanProgression.app,
      at: now,
    );
    await db.chatDao.createThread('t-1', 'Nieuw schema', planId: 'p-1');
    tools = CoachTools(db, planId: 'p-1');
  });

  tearDown(() => db.close());

  Map<String, Object?> outline({List<String> names = const ['Push', 'Pull']}) =>
      {
        'name': 'Kracht',
        'change': 'Twee dagen.',
        'weeks': [
          {'kind': 'build'},
          {'kind': 'build', 'sets': 1},
          {'kind': 'deload'},
        ],
        'sessions': [
          for (final (i, name) in names.indexed)
            {'name': name, 'weekday': 1 + 2 * i, 'focus': '$name zwaar'},
        ],
        'volume': [
          {'muscle': 'borst', 'sets': 12},
          {'muscle': 'rug', 'sets': 14},
        ],
      };

  Map<String, Object?> session(String name, {int sets = 4}) => {
    'session': name,
    'change': 'Zwaar en kort.',
    'exercises': [
      {
        'exercise': 'bench press',
        'warmup_sets': 1,
        'sets': sets,
        'reps': 6,
        'weight_kg': 100,
        'rest_seconds': 180,
        'notes': 'Pauze op de borst',
      },
      {'exercise': 'Barbell Row', 'sets': 3, 'reps': 8, 'weight_kg': 70},
    ],
  };

  Future<RoutineRow> named(String name) async =>
      (await db.plansDao.sessions('p-1')).firstWhere((s) => s.name == name);

  group('the outline', () {
    test('comes first: sessions with a focus and no exercises, waiting for '
        'approval', () async {
      final lookup = await tools.run('save_plan_outline', outline());

      expect(decode(lookup)['ok'], isTrue);
      final plan = (await db.plansDao.plan('p-1'))!;
      expect(plan.name, 'Kracht');
      expect(plan.weeks, 3);
      expect(plan.weeklySets, {'borst': 12, 'rug': 14});
      expect(plan.outlineApproved, isFalse);
      final sessions = await db.plansDao.sessions('p-1');
      expect([for (final s in sessions) s.name], ['Push', 'Pull']);
      expect(
        [for (final s in sessions) s.planFocus],
        ['Push zwaar', 'Pull zwaar'],
      );
      expect(
        sessions.every((s) => s.sessionState == PlanSessionState.planned),
        isTrue,
      );
      expect(
        (await db.routinesDao.getRoutineDetail(sessions.first.id))!.exercises,
        isEmpty,
      );

      final card = lookup.proposal!;
      expect(card.kind, ProposalKind.planOutline);
      expect(card.outline!.at, plan.outlineAt);
      expect(card.outline!.sessions.first.focus, 'Push zwaar');
      final stored = parseProposals(encodeProposals([card])).single;
      expect(stored.outline!.volume, {'borst': 12, 'rug': 14});
    });

    test('again keeps a session that was made, and waits again', () async {
      await tools.run('save_plan_outline', outline());
      await db.plansDao.approveOutline('p-1', now);
      await tools.run('save_plan_session', session('Push'));
      await db.plansDao.markSession(
        (await named('Push')).id,
        PlanSessionState.approved,
      );

      await tools.run(
        'save_plan_outline',
        outline(names: const ['Push', 'Legs']),
      );

      final push = await named('Push');
      expect(push.sessionState, PlanSessionState.approved);
      expect(
        (await db.routinesDao.getRoutineDetail(push.id))!.exercises,
        hasLength(2),
      );
      expect((await named('Legs')).sessionState, PlanSessionState.planned);
      expect(
        (await db.plansDao.sessions('p-1')).map((s) => s.name),
        isNot(contains('Pull')),
      );
      expect((await db.plansDao.plan('p-1'))!.outlineApproved, isFalse);
    });
  });

  group('a session', () {
    test('is not made before the outline is approved', () async {
      await tools.run('save_plan_outline', outline());
      final lookup = await tools.run('save_plan_session', session('Push'));
      expect(decode(lookup)['error'], contains('nog niet goedgekeurd'));
    });

    test('is made whole, and waits for approval', () async {
      await tools.run('save_plan_outline', outline());
      await db.plansDao.approveOutline('p-1', now);
      final lookup = await tools.run('save_plan_session', session('push'));

      expect(decode(lookup)['ok'], isTrue);
      final push = await named('Push');
      expect(push.sessionState, PlanSessionState.proposed);
      final sets = (await db.routinesDao.getRoutineDetail(push.id))!
          .exercises
          .first
          .sets;
      expect(sets, hasLength(5));

      final card = lookup.proposal!.session!;
      expect(card.routineId, push.id);
      expect(card.savedAt, push.updatedAt);
      expect(card.focus, 'Push zwaar');
      final bench = card.exercises.first;
      expect(bench.name, 'Bench Press');
      expect((bench.warmups, bench.sets, bench.reps), (1, 4, 6));
      expect(bench.weightKg, 100);
      expect(bench.restSeconds, 180);
      expect(bench.notes, 'Pauze op de borst');
    });

    test('that is not in the outline is refused', () async {
      await tools.run('save_plan_outline', outline());
      await db.plansDao.approveOutline('p-1', now);
      final lookup = await tools.run('save_plan_session', session('Legs'));
      expect(decode(lookup)['error'], contains('geen sessie "Legs"'));
    });

    test('of a running schema changes at once, the old one kept', () async {
      await tools.run('save_plan_outline', outline());
      await db.plansDao.approveOutline('p-1', now);
      await tools.run('save_plan_session', session('Push'));
      await db.plansDao.start('p-1', startDay: now, at: now);

      await tools.run('save_plan_session', session('Push', sets: 5));

      final push = await named('Push');
      expect(push.sessionState, PlanSessionState.approved);
      expect(await db.routinesDao.watchVersions(push.id).first, hasLength(1));
    });
  });

  test('Goedkeuren asks for the next session, until there is none', () async {
    await tools.run('save_plan_outline', outline());

    expect(
      await PlanBuilder.approveOutline(db, 'p-1'),
      'De opzet is goed. Maak nu Push.',
    );
    await tools.run('save_plan_session', session('Push'));
    expect(
      await PlanBuilder.approveSession(db, 'p-1', (await named('Push')).id),
      'Push is goed. Maak nu Pull.',
    );
    await tools.run('save_plan_session', session('Pull'));
    expect(
      await PlanBuilder.approveSession(db, 'p-1', (await named('Pull')).id),
      isNull,
    );
    expect(
      planComplete(
        (await db.plansDao.plan('p-1'))!,
        await db.plansDao.sessions('p-1'),
      ),
      isTrue,
    );
  });

  group('the coach is told the one step to take', () {
    Future<String> brief() async =>
        describePlanOf(db, (await db.plansDao.plan('p-1'))!, now);

    test('the outline, then waiting for it', () async {
      expect(await brief(), contains('Stap 1'));
      await tools.run('save_plan_outline', outline());
      final waiting = await brief();
      expect(waiting, contains('De opzet wacht op het akkoord'));
      expect(waiting, contains('1. Push (maandag): Push zwaar - nog te maken'));
      expect(waiting, contains('Werksets per week: borst 12, rug 14.'));
    });

    test('the next session, then waiting for that one', () async {
      await tools.run('save_plan_outline', outline());
      await db.plansDao.approveOutline('p-1', now);
      expect(await brief(), contains('Maak nu alleen sessie Push'));

      await tools.run('save_plan_session', session('Push'));
      final waiting = await brief();
      expect(waiting, contains('Sessie Push wacht op het akkoord'));
      expect(
        waiting,
        contains('wacht op akkoord: Bench Press 4×6 @ 100 kg; Barbell Row 3×8'),
      );
    });

    test('and when all are approved, that it can start', () async {
      await tools.run('save_plan_outline', outline(names: const ['Push']));
      await PlanBuilder.approveOutline(db, 'p-1');
      await tools.run('save_plan_session', session('Push'));
      await PlanBuilder.approveSession(db, 'p-1', (await named('Push')).id);
      expect(await brief(), contains('Alle sessies zijn goedgekeurd'));
    });
  });

  test('only the last few turns ride along: the state goes with the '
      'instructions', () async {
    late Map<String, Object?> body;
    await Coach(
      client: AiClient(
        apiKey: 'AQ.Ab8RNiZhX2Mkg',
        provider: CoachProvider.gemini,
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'role': 'model',
                    'parts': [
                      {'text': 'ok'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
      tools: tools,
      model: 'gemini-3-flash-lite',
      system: 'Je bent een coach.',
    ).ask(
      history: [
        for (var i = 0; i < 20; i++)
          CoachTurn(role: i.isEven ? 'user' : 'assistant', text: 'beurt $i'),
      ],
      question: 'Push is goed. Maak nu Pull.',
    );

    expect(body['contents'], hasLength(kPlanHistoryTurns + 1));
  });
}
