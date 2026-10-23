import 'dart:convert';

import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_prompt.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/plans/presentation/plan_new_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// A schema laid out by the coach, in the conversation that belongs to it -
/// and nowhere else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late CoachTools tools;

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
      goal: 'Sterker op bench',
      split: PlanSplit.upperLower,
      days: WeekdaySet.of([1, 4]).mask,
      progression: PlanProgression.app,
      at: DateTime(2026, 10, 20),
    );
    await db.chatDao.createThread('t-1', 'Nieuw schema', planId: 'p-1');
    tools = CoachTools(db, planId: 'p-1');
  });

  tearDown(() => db.close());

  Map<String, Object?> exercise(String name, {int sets = 3, int reps = 5}) => {
    'exercise': name,
    'sets': [
      for (var i = 0; i < sets; i++) {'reps': reps, 'weight_kg': 60},
    ],
  };

  Map<String, Object?> layout({
    String upper = 'Upper',
    int benchSets = 3,
    List<Map<String, Object?>>? weeks,
  }) => {
    'name': 'Kracht',
    'change': 'Twee dagen, boven en onder.',
    'weeks':
        weeks ??
        [
          {'kind': 'build'},
          {'kind': 'build', 'sets': 1, 'note': 'een set meer'},
          {'kind': 'build', 'reps': -2},
          {'kind': 'deload'},
        ],
    'sessions': [
      {
        'name': upper,
        'weekday': 1,
        'exercises': [
          exercise('bench press', sets: benchSets),
          exercise('Barbell Row'),
        ],
      },
      {
        'name': 'Lower',
        'weekday': 4,
        'exercises': [exercise('Squat')],
      },
    ],
  };

  test('only the conversation of a schema is offered its two lookups', () {
    String names(CoachTools tools) =>
        [for (final tool in tools.offered) tool['name']].join(',');
    expect(names(tools), contains('save_plan'));
    expect(names(tools), contains(',plan'));
    expect(names(CoachTools(db)), isNot(contains('plan')));
  });

  test('outside it, asking for one anyway is refused', () async {
    final lookup = await CoachTools(db).run('save_plan', layout());
    expect(decode(lookup)['error'], contains('hoort niet bij een schema'));
    expect(await db.plansDao.sessions('p-1'), isEmpty);
  });

  test('a draft is laid out: its weeks, its sessions, and a card', () async {
    final lookup = await tools.run('save_plan', layout());

    expect(decode(lookup)['ok'], isTrue);
    final plan = (await db.plansDao.plan('p-1'))!;
    expect(plan.name, 'Kracht');
    expect(plan.weeks, 4);
    expect(plan.weekPlan(2), const PlanWeek(sets: 1, note: 'een set meer'));
    expect(plan.weekPlan(4).isDeload, isTrue);
    expect(plan.state, PlanStatus.draft);

    final sessions = await db.plansDao.sessions('p-1');
    expect([for (final s in sessions) s.name], ['Upper', 'Lower']);
    expect([for (final s in sessions) s.planWeekday], [1, 4]);
    final upper = (await db.routinesDao.getRoutineDetail(sessions[0].id))!;
    expect(
      [for (final e in upper.exercises) e.exercise.name],
      ['Bench Press', 'Barbell Row'],
    );
    // Not among the user's own routines.
    expect(await db.routinesDao.watchRoutines().first, isEmpty);
    // The conversation is called what the schema is.
    expect((await db.chatDao.thread('t-1'))!.title, 'Kracht');

    final card = lookup.proposal!;
    expect(card.kind, ProposalKind.plan);
    expect(card.appliedId, 'p-1');
    expect(card.made, isTrue);
    expect(card.plan!.sessions.first.exercises.first.name, 'Bench Press');
    // And it survives being stored with the answer.
    final stored = parseProposals(encodeProposals([card])).single;
    expect(stored.plan!.weeks, hasLength(4));
    expect(stored.plan!.sessions.last.weekday, 4);
  });

  test('a draft laid out again is simply made again', () async {
    await tools.run('save_plan', layout());
    final lookup = await tools.run('save_plan', layout(upper: 'Boven'));

    expect(lookup.proposal!.made, isFalse);
    final sessions = await db.plansDao.sessions('p-1');
    expect([for (final s in sessions) s.name], ['Boven', 'Lower']);
  });

  test(
    'a running schema keeps its sessions by name, and how they were',
    () async {
      await tools.run('save_plan', layout());
      final before = await db.plansDao.sessions('p-1');
      await db.plansDao.start(
        'p-1',
        startDay: DateTime(2026, 10, 19),
        at: DateTime(2026, 10, 20),
      );

      await tools.run('save_plan', layout(benchSets: 4));

      final after = await db.plansDao.sessions('p-1');
      expect([for (final s in after) s.id], [for (final s in before) s.id]);
      final versions = await db.routinesDao.watchVersions(after.first.id).first;
      expect(versions, hasLength(1));
      final upper = (await db.routinesDao.getRoutineDetail(after.first.id))!;
      expect(upper.exercises.first.sets, hasLength(4));
    },
  );

  test('what cannot be is refused, and nothing is written', () async {
    Future<String> error(Map<String, Object?> input) async =>
        '${decode(await tools.run('save_plan', input))['error']}';

    expect(
      await error(
        layout(
          weeks: [
            {'kind': 'build'},
          ],
        ),
      ),
      contains('2 tot 16 weken'),
    );
    final unknown = layout()
      ..['sessions'] = [
        {
          'name': 'Upper',
          'exercises': [exercise('Hammer Curl')],
        },
      ];
    expect(await error(unknown), contains('bestaan niet'));
    final twice = layout()
      ..['sessions'] = [
        {
          'name': 'Upper',
          'exercises': [exercise('Squat')],
        },
        {
          'name': 'upper',
          'exercises': [exercise('Squat')],
        },
      ];
    expect(await error(twice), contains('eigen naam'));
    expect(await db.plansDao.sessions('p-1'), isEmpty);
    expect((await db.plansDao.plan('p-1'))!.weeks, isNull);
  });

  test('a finished schema does not change any more', () async {
    await db.plansDao.finish('p-1', DateTime(2026, 10, 21));
    final lookup = await tools.run('save_plan', layout());
    expect(decode(lookup)['error'], contains('afgelopen'));
  });

  test('plan reads it back, with how this week stands', () async {
    await tools.run('save_plan', layout());
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    await db.plansDao.start('p-1', startDay: monday, at: now);

    final read = decode(await tools.run('plan', const {}));
    expect(read['status'], 'running');
    expect(read['goal'], 'Sterker op bench');
    expect(read['split'], 'upper_lower');
    expect(read['week'], 1);
    final sessions = read['sessions']! as List;
    expect((sessions.first as Map)['done_this_week'], isFalse);
    expect(((sessions.first as Map)['exercises'] as List), hasLength(2));
  });

  test('a whole session may be written short: sets as a number', () async {
    final lookup = await tools.run('save_plan', {
      'name': 'Kracht',
      'change': 'Kort opgeschreven.',
      'weeks': [
        {'kind': 'build'},
        {'kind': 'deload'},
      ],
      'sessions': [
        {
          'name': 'Upper',
          'exercises': [
            {
              'exercise': 'Bench Press',
              'warmup_sets': 1,
              'sets': 4,
              'reps': 6,
              'weight_kg': 100,
            },
          ],
        },
      ],
    });

    expect(decode(lookup)['ok'], isTrue);
    final upper = (await db.plansDao.sessions('p-1')).single;
    final sets = (await db.routinesDao.getRoutineDetail(upper.id))!
        .exercises
        .single
        .sets;
    expect(
      [for (final s in sets) s.setType],
      ['warmup', 'normal', 'normal', 'normal', 'normal'],
    );
    expect([for (final s in sets.skip(1)) s.targetReps], [6, 6, 6, 6]);
    expect(
      [for (final s in sets.skip(1)) s.targetWeightKg],
      [100, 100, 100, 100],
    );
    expect(lookup.proposal!.plan!.sessions.single.exercises.single.sets, 4);
  });

  test(
    'an answer cut off at its limit is said to be, not "geen antwoord"',
    () async {
      final coach = Coach(
        client: AiClient(
          apiKey: 'AQ.Ab8RNiZhX2Mkg',
          provider: CoachProvider.gemini,
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {'role': 'model'},
                    'finishReason': 'MAX_TOKENS',
                  },
                ],
                'usageMetadata': {'promptTokenCount': 900},
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
        tools: tools,
        model: 'gemini-3-flash-lite',
        system: 'Je bent een coach.',
      );

      await expectLater(
        coach.ask(history: const [], question: 'Maak een schema.'),
        throwsA(
          isA<CoachException>().having(
            (e) => e.message,
            'message',
            contains('afgebroken'),
          ),
        ),
      );
    },
  );

  test(
    'in the conversation of a schema the coach has room to write one',
    () async {
      late Map<String, Object?> body;
      final coach = Coach(
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
      );

      await coach.ask(history: const [], question: 'Maak een schema.');
      final config = body['generationConfig']! as Map<String, Object?>;
      expect(config['maxOutputTokens'], greaterThanOrEqualTo(kPlanMaxTokens));
    },
  );

  test(
    'making a schema may take more rounds of looking up than a question',
    () async {
      var asked = 0;
      AiClient lookingUp(int rounds) => AiClient(
        apiKey: 'AQ.Ab8RNiZhX2Mkg',
        provider: CoachProvider.gemini,
        client: MockClient((request) async {
          asked++;
          final part = asked <= rounds
              ? {
                  'functionCall': {
                    'name': 'search_exercises',
                    'args': {'query': 'bench'},
                  },
                }
              : {'text': 'Klaar.'};
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'role': 'model',
                    'parts': [part],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final answer = await Coach(
        client: lookingUp(6),
        tools: tools,
        model: 'gemini-3-flash-lite',
        system: 'Je bent een coach.',
      ).ask(history: const [], question: 'Maak een schema.');
      expect(answer.text, 'Klaar.');
      expect(answer.requests, 7);
      expect(kPlanToolRounds, greaterThan(Coach.maxToolRounds));
    },
  );

  test('a lookup the model wrote wrongly is tried once more', () async {
    var asked = 0;
    final answer = await Coach(
      client: AiClient(
        apiKey: 'AQ.Ab8RNiZhX2Mkg',
        provider: CoachProvider.gemini,
        client: MockClient((request) async {
          asked++;
          return http.Response(
            jsonEncode({
              'candidates': [
                asked == 1
                    ? {'finishReason': 'MALFORMED_FUNCTION_CALL'}
                    : {
                        'content': {
                          'role': 'model',
                          'parts': [
                            {'text': 'Klaar.'},
                          ],
                        },
                        'finishReason': 'STOP',
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
    ).ask(history: const [], question: 'Maak een schema.');

    expect(answer.text, 'Klaar.');
    expect(answer.requests, 2);
  });

  group('what the coach is told', () {
    test('in the conversation of a draft: lay it out, then ask', () {
      final prompt = buildCoachPrompt(
        now: DateTime(2026, 10, 20),
        weightUnit: 'kg',
        plan: describePlanThread(
          status: 'draft',
          goal: 'Sterker op bench',
          split: 'Upper/lower',
          days: const ['maandag', 'donderdag'],
          coachSetsNumbers: false,
        ),
      );
      expect(prompt, contains('Dit gesprek hoort bij een schema'));
      expect(prompt, contains('"Sterker op bench"'));
      expect(prompt, contains('maandag, donderdag'));
      expect(prompt, contains('stelt de app elke week bij'));
      expect(prompt, contains('Start schema'));
    });

    test('elsewhere, nothing about schema\'s', () {
      final prompt = buildCoachPrompt(
        now: DateTime(2026, 10, 20),
        weightUnit: 'kg',
      );
      expect(prompt, isNot(contains('save_plan')));
    });

    test('the form, as the first question', () {
      final request = planRequest(
        goal: ' Sterker op bench ',
        split: PlanSplit.custom,
        splitNote: 'Borst en rug, dan benen',
        days: WeekdaySet.of([1, 3, 5]),
        progression: PlanProgression.coach,
      );
      expect(request, contains('Wat ik wil: Sterker op bench'));
      expect(request, contains('Split: zelf gekozen: Borst en rug, dan benen'));
      expect(request, contains('Dagen: maandag, woensdag en vrijdag'));
      expect(request, contains('jij, elke zondag'));
    });
  });
}
