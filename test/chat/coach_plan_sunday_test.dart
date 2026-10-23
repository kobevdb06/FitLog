import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/morning/data/morning_reporter.dart'
    show ReportClientFactory;
import 'package:fitlog/features/plans/data/plan_actions.dart';
import 'package:fitlog/features/plans/data/plan_week_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// Sunday evening: the coach looks back on the schema's week, proposes
/// instead of changing, and - while it keeps the numbers - sets next week's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late List<String> sent;
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final lastMonday = DateTime(monday.year, monday.month, monday.day - 7);

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
    for (final (id, name) in [
      ('ex-bench', 'Bench Press'),
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
  });

  tearDown(() => db.close());

  Map<String, Object?> layout({String lowerDay = '4', int weeks = 4}) => {
    'name': 'Kracht',
    'change': 'Twee dagen.',
    'weeks': [
      for (var i = 0; i < weeks; i++) {'kind': 'build'},
    ],
    'sessions': [
      {
        'name': 'Upper',
        'weekday': 1,
        'exercises': [
          {
            'exercise': 'Bench Press',
            'sets': [
              for (var i = 0; i < 3; i++) {'reps': 5, 'weight_kg': 60},
            ],
          },
        ],
      },
      {
        'name': 'Lower',
        'weekday': int.parse(lowerDay),
        'exercises': [
          {
            'exercise': 'Squat',
            'sets': [
              for (var i = 0; i < 3; i++) {'reps': 5, 'weight_kg': 80},
            ],
          },
        ],
      },
    ],
  };

  /// A running schema that began last Monday - so last week was week 1 -
  /// with its conversation.
  Future<void> running({
    PlanProgression progression = PlanProgression.app,
    int weeks = 4,
  }) async {
    await db.plansDao.createDraft(
      id: 'p-1',
      goal: 'Sterker',
      split: PlanSplit.upperLower,
      days: 0x09,
      progression: progression,
      at: now,
    );
    await db.chatDao.createThread('t-1', 'Kracht', planId: 'p-1');
    await CoachTools(db, planId: 'p-1').run('save_plan', layout(weeks: weeks));
    await PlanActions.start(db, 'p-1', from: lastMonday);
  }

  Future<void> didLastWeek(String session) async {
    final routine = (await db.plansDao.sessions('p-1'))
        .firstWhere((s) => s.name == session);
    final at = DateTime(
      lastMonday.year,
      lastMonday.month,
      lastMonday.day + 1,
      18,
    );
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-$session',
            routineId: Value(routine.id),
            name: session,
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(at.millisecondsSinceEpoch + 3600000),
          ),
        );
  }

  ReportClientFactory apiSaying(String text) =>
      (key, provider) => AiClient(
        apiKey: key,
        provider: provider,
        client: MockClient((request) async {
          sent.add(request.body);
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'role': 'model',
                    'parts': [
                      {'text': text},
                    ],
                  },
                },
              ],
              'usageMetadata': {
                'promptTokenCount': 900,
                'candidatesTokenCount': 30,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

  group('on Sunday the coach', () {
    test('may read and propose, not lay out', () async {
      await running();
      String names(CoachTools tools) =>
          [for (final tool in tools.offered) tool['name']].join(',');
      final sunday = CoachTools(db, planId: 'p-1', sunday: true);
      expect(names(sunday), contains('propose_plan_change'));
      expect(names(sunday), isNot(contains('save_plan')));
      expect(names(sunday), isNot(contains('set_week_numbers')));
      expect(names(sunday), isNot(contains('remember')));
      expect(
        names(CoachTools(db, planId: 'p-1', sunday: true, numbers: true)),
        contains('set_week_numbers'),
      );
      // And not the other way round.
      expect(
        names(CoachTools(db, planId: 'p-1')),
        isNot(contains('propose_plan_change')),
      );

      final refused = await sunday.run('save_plan', layout());
      expect(decode(refused)['error'], contains('propose_plan_change'));
    });

    test('proposes: nothing changes until it is accepted', () async {
      await running();
      final lookup = await CoachTools(
        db,
        planId: 'p-1',
        sunday: true,
      ).run('propose_plan_change', layout(lowerDay: '6'));

      expect(decode(lookup)['ok'], isTrue);
      final card = lookup.proposal!;
      expect(card.kind, ProposalKind.planChange);
      expect(card.planId, 'p-1');
      expect(card.planChange!.layout.sessions.last.weekday, 6);
      final lower = (await db.plansDao.sessions('p-1')).last;
      expect(lower.planWeekday, 4);
      // As it is stored with the answer, and read back.
      final stored = parseProposals(encodeProposals([card])).single;
      expect(stored.planChange!.input['name'], 'Kracht');
    });

    test('Aanvaarden lays it out; Houden leaves it', () async {
      await running();
      final card = (await CoachTools(
        db,
        planId: 'p-1',
        sunday: true,
      ).run('propose_plan_change', layout(lowerDay: '6'))).proposal!;
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Lower op zaterdag?',
        proposals: encodeProposals([card, card]),
      );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final coach = container.read(coachControllerProvider.notifier);

      // Read fresh each time: deciding rewrites the cards.
      var row = (await db.chatDao.messages('t-1')).single;
      await coach.keepPlan(message: row, index: 1);
      row = (await db.chatDao.messages('t-1')).single;
      await coach.accept(message: row, index: 0);

      expect((await db.plansDao.sessions('p-1')).last.planWeekday, 6);
      final cards = parseProposals(
        (await db.chatDao.messages('t-1')).single.proposals,
      );
      expect(cards[0].appliedId, 'p-1');
      expect(cards[1].planChange!.kept, isTrue);
    });

    test('sets next week\'s numbers only while it keeps them', () async {
      await running(progression: PlanProgression.coach);
      final tools = CoachTools(db, planId: 'p-1', sunday: true, numbers: true);
      final lookup = await tools.run('set_week_numbers', {
        'sessions': [
          {
            'name': 'upper',
            'exercises': [
              {
                'exercise': 'bench press',
                'sets': [
                  for (var i = 0; i < 4; i++) {'reps': 5, 'weight_kg': 62.5},
                ],
              },
            ],
          },
        ],
      });

      expect(decode(lookup)['ok'], isTrue);
      final upper = (await db.plansDao.sessions('p-1')).first;
      final detail = (await db.routinesDao.getRoutineDetail(upper.id))!;
      expect(
        [for (final s in detail.exercises.single.sets) s.targetWeightKg],
        [62.5, 62.5, 62.5, 62.5],
      );
      expect(await db.routinesDao.watchVersions(upper.id).first, isNotEmpty);

      final other = await tools.run('set_week_numbers', {
        'sessions': [
          {
            'name': 'Upper',
            'exercises': [
              {
                'exercise': 'Squat',
                'sets': [
                  {'reps': 5},
                ],
              },
            ],
          },
        ],
      });
      expect(decode(other)['error'], contains('staat niet in Upper'));
    });
  });

  group('the check on Sunday evening', () {
    test('without a schema, nothing', () async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      final outcome = await PlanWeekCheck(
        db,
        clientFactory: apiSaying('ok'),
      ).run(lastMonday, now: now);
      expect(outcome, PlanCheckOutcome.nothing);
      expect(sent, isEmpty);
    });

    test('a week with every session done asks nothing, while FitLog keeps '
        'the numbers', () async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await running();
      await didLastWeek('Upper');
      await didLastWeek('Lower');
      final outcome = await PlanWeekCheck(
        db,
        clientFactory: apiSaying('ok'),
      ).run(lastMonday, now: now);
      expect(outcome, PlanCheckOutcome.nothing);
      expect(sent, isEmpty);
    });

    test('a missed session: the coach is asked in the schema\'s '
        'conversation', () async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await running();
      await didLastWeek('Upper');
      final outcome = await PlanWeekCheck(
        db,
        clientFactory: apiSaying('Lower schuift naar maandag.'),
      ).run(lastMonday, now: now);

      expect(outcome, PlanCheckOutcome.answered);
      expect(sent.single, contains('Niet gedaan: Lower.'));
      expect(sent.single, contains('propose_plan_change'));
      expect(sent.single, isNot(contains('"save_plan"')));
      final messages = await db.chatDao.messages('t-1');
      expect(messages.last.role, 'assistant');
      expect(messages.last.content, 'Lower schuift naar maandag.');
    });

    test('without a key there is no coach to ask', () async {
      await running();
      final outcome = await PlanWeekCheck(
        db,
        clientFactory: apiSaying('ok'),
      ).run(lastMonday, now: now);
      expect(outcome, PlanCheckOutcome.unavailable);
    });

    test('after the last week, nothing to adjust', () async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await running(weeks: 2);
      final outcome = await PlanWeekCheck(
        db,
        clientFactory: apiSaying('ok'),
      ).run(monday, now: now);
      expect(outcome, PlanCheckOutcome.ended);
      expect(sent, isEmpty);
    });
  });
}
