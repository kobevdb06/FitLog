import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/deload.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_prompt.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The coach and a deload: it knows what was set and what happened, it can
/// propose one - and only the user starts it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CoachTools tools;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  DateTime daysAgo(int days) =>
      DateTime(today.year, today.month, today.day - days, 10);

  String date(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    tools = CoachTools(db);
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() => db.close());

  /// A finished session on [on] with one set of Bench Press.
  Future<void> session(DateTime on, {bool deload = false}) async {
    final at = on.millisecondsSinceEpoch;
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-$at',
            name: 'Push',
            startedAt: at,
            endedAt: Value(at + 3600000),
            totalSets: const Value(1),
            isDeload: Value(deload),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$at',
            workoutId: 'w-$at',
            exerciseId: 'ex-bench',
            sortOrder: 0,
          ),
        );
    await db
        .into(db.workoutSetsTable)
        .insert(
          WorkoutSetsTableCompanion.insert(
            id: 'ws-$at',
            workoutExerciseId: 'we-$at',
            sortOrder: 0,
            setType: const Value('normal'),
            weightKg: Value(deload ? 72.5 : 80),
            reps: const Value(8),
            isCompleted: const Value(true),
            completedAt: Value(at),
          ),
        );
  }

  Future<void> set(AppSettingsTableCompanion changes) =>
      db.settingsDao.updateSettings(changes);

  group('wat de coach over deloads weet', () {
    test('wat je instelde, en dat er nog geen was', () async {
      final found = decode(await tools.run('deload', const {}));

      expect(found['settings'], {
        'sets_percent_less': 50,
        'weight_percent_less': 10,
        'reps_percent_less': 0,
        'drop_hard_sets': true,
        'pr_attempts': false,
        'default_days': 7,
        'default_start': 'today',
        'propose': true,
        'propose_after_weeks': 6,
        'propose_after_stalled_exercises': 2,
        'later_days': 3,
      });
      expect(found['current'], isNull);
      expect(found['earlier'], isEmpty);
      expect(found['weeks_without_break'], 0);
      expect(found['proposal_on_start'], {'state': 'not_due'});
    });

    test('de deload die loopt, met welke dag en wat er al gedaan is', () async {
      final yesterday = daysAgo(1);
      await db.deloadDao.start(
        from: yesterday,
        days: 5,
        plan: const DeloadPlan(setsPercent: 40),
        source: 'coach',
        now: yesterday,
      );
      await session(today.add(const Duration(hours: 9)), deload: true);

      final found = decode(await tools.run('deload', const {}));
      final current = found['current']! as Map<String, Object?>;

      expect(current['state'], 'going');
      expect(current['day'], 2);
      expect(current['start'], date(yesterday));
      expect(current['last_day'], date(daysAgo(-3)));
      expect(current['sets_percent_less'], 40);
      expect(current['started_by'], 'coach');
      expect(current['sessions'], 1);
      expect(found['proposal_on_start'], {'state': 'not_during_a_deload'});
    });

    test('een vorige die vroeger stopte', () async {
      final from = daysAgo(30);
      final id = await db.deloadDao.start(
        from: from,
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
        now: from,
      );
      await db.deloadDao.stop(id, at: daysAgo(28));

      final found = decode(await tools.run('deload', const {}));
      final earlier = (found['earlier']! as List).single as Map;

      expect(earlier['start'], date(from));
      expect(earlier['last_day'], date(daysAgo(28)));
      expect(earlier['stopped_early'], isTrue);
      expect(earlier['sessions'], 0);
    });

    test('weken zonder pauze, en dat het voorstel op Start staat', () async {
      for (var week = 0; week < 7; week++) {
        await session(daysAgo(7 * week));
      }

      final found = decode(await tools.run('deload', const {}));

      expect(found['weeks_without_break'], 7);
      expect(found['proposal_on_start'], {'state': 'shown'});
    });

    test('en of je het voorstel later vroeg of uitzette', () async {
      final until = DateTime(today.year, today.month, today.day + 2);
      await set(
        AppSettingsTableCompanion(
          deloadSnoozedUntil: Value(until.millisecondsSinceEpoch),
        ),
      );
      expect(decode(await tools.run('deload', const {}))['proposal_on_start'], {
        'state': 'later',
        'until': date(until),
      });

      await set(const AppSettingsTableCompanion(deloadSuggest: Value(false)));
      final off =
          decode(await tools.run('deload', const {}))['proposal_on_start']!
              as Map;
      expect(off['state'], 'off');
      expect(off['note'], contains('Instellingen, Training, Deload'));
    });
  });

  group('een deload voorstellen', () {
    test('zonder meer: zoals je het instelde, en er start niets', () async {
      final lookup = await tools.run('propose_deload', const {});
      final found = decode(lookup);

      expect(found['ok'], isTrue);
      expect(found['proposed'], {
        'start': date(today),
        'last_day': date(DateTime(today.year, today.month, today.day + 6)),
        'days': 7,
        'sets_percent_less': 50,
        'weight_percent_less': 10,
        'reps_percent_less': 0,
        'drop_hard_sets': true,
        'pr_attempts': false,
      });
      expect(found.containsKey('replaces'), isFalse);
      expect(lookup.proposal!.kind, ProposalKind.deload);
      expect(lookup.proposal!.deload!.from, today);
      expect(await db.deloadDao.all(), isEmpty);
    });

    test(
      'met maandag als begin en een eigen duur in de instellingen',
      () async {
        await set(
          const AppSettingsTableCompanion(
            deloadStart: Value('monday'),
            deloadDays: Value(5),
            deloadWeightPercent: Value(20),
          ),
        );

        final card = (await tools.run('propose_deload', const {})).proposal!;

        expect(card.deload!.from, nextMonday(today));
        expect(card.deload!.days, 5);
        expect(card.deload!.plan.weightPercent, 20);
        expect(card.title, 'Deload van 5 dagen');
      },
    );

    test('wat de coach anders wil, op de stappen van de schuifjes', () async {
      final lookup = await tools.run('propose_deload', {
        'start': date(DateTime(today.year, today.month, today.day + 1)),
        'days': 10,
        'sets_percent_less': 33,
        'weight_percent_less': 12,
        'reps_percent_less': 90,
        'drop_hard_sets': false,
        'pr_attempts': true,
        'reason': 'Twee oefeningen staan al vier weken stil.',
      });
      final deload = lookup.proposal!.deload!;

      expect(deload.from, DateTime(today.year, today.month, today.day + 1));
      expect(deload.days, 10);
      expect(deload.plan.setsPercent, 30);
      expect(deload.plan.weightPercent, 10);
      expect(deload.plan.repsPercent, 50);
      expect(deload.plan.dropHardSets, isFalse);
      expect(deload.plan.prAttempts, isTrue);
      expect(deload.reason, 'Twee oefeningen staan al vier weken stil.');
      // And it is told what it became.
      final proposed = decode(lookup)['proposed']! as Map;
      expect(proposed['sets_percent_less'], 30);
      expect(proposed['reps_percent_less'], 50);
    });

    test('een begin dat geen datum is, voorbij is of te ver ligt', () async {
      for (final start in [
        'morgen',
        date(daysAgo(1)),
        date(DateTime(today.year, today.month, today.day + 91)),
      ]) {
        final lookup = await tools.run('propose_deload', {'start': start});
        expect(decode(lookup)['ok'], isFalse, reason: start);
        expect(lookup.proposal, isNull, reason: start);
      }
    });

    test('en een duur buiten één tot eenentwintig dagen', () async {
      for (final days in [0, 22]) {
        final lookup = await tools.run('propose_deload', {'days': days});
        expect(decode(lookup)['error'], contains('days'), reason: '$days');
      }
    });

    test('zegt welke deload het zou vervangen', () async {
      await db.deloadDao.start(
        from: DateTime(today.year, today.month, today.day + 3),
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
      );

      final found = decode(await tools.run('propose_deload', const {}));

      expect(found['replaces'], {
        'start': date(DateTime(today.year, today.month, today.day + 3)),
        'state': 'planned',
      });
    });
  });

  group('de andere opzoekingen zien een deloadsessie', () {
    test('bij je sessies, bij één oefening en per week', () async {
      await session(daysAgo(8));
      await session(daysAgo(1), deload: true);

      final workouts =
          decode(await tools.run('recent_workouts', const {}))['workouts']!
              as List;
      expect((workouts[0] as Map)['deload'], isTrue);
      expect((workouts[1] as Map).containsKey('deload'), isFalse);

      final history =
          decode(
                await tools.run('exercise_history', {'exercise': 'bench'}),
              )['sessions']!
              as List;
      expect((history[0] as Map)['deload'], isTrue);
      expect((history[1] as Map).containsKey('deload'), isFalse);

      final weeks =
          decode(await tools.run('weekly_volume', {'weeks': 3}))['weeks']!
              as List;
      expect(weeks.where((w) => (w as Map)['deload'] == true), hasLength(1));
    });

    test('en in de training van nu', () async {
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w-now',
              name: 'Push',
              startedAt: now.millisecondsSinceEpoch,
              isDeload: const Value(true),
            ),
          );

      final found = decode(await tools.run('current_workout', const {}));

      expect(found['running'], isTrue);
      expect(found['deload'], isTrue);
    });
  });

  group('wat bewaard staat', () {
    test('een voorstel overleeft opschrijven en teruglezen', () {
      final read = parseProposals(
        encodeProposals([
          CoachProposal.ofDeload(
            DeloadProposal(
              from: DateTime(2026, 10, 19),
              days: 7,
              plan: const DeloadPlan(
                setsPercent: 30,
                weightPercent: 15,
                repsPercent: 10,
                dropHardSets: false,
                prAttempts: true,
              ),
              reason: 'Zeven weken zonder pauze.',
            ),
            appliedId: 'd-1',
          ),
        ]),
      ).single;

      expect(read.kind, ProposalKind.deload);
      expect(read.appliedId, 'd-1');
      expect(read.title, 'Deloadweek');
      final deload = read.deload!;
      expect(deload.from, DateTime(2026, 10, 19));
      expect(deload.days, 7);
      expect(deload.plan.setsPercent, 30);
      expect(deload.plan.weightPercent, 15);
      expect(deload.plan.repsPercent, 10);
      expect(deload.plan.dropHardSets, isFalse);
      expect(deload.plan.prAttempts, isTrue);
      expect(deload.reason, 'Zeven weken zonder pauze.');
    });

    test('en zonder datum kost het de kaart, niet het gesprek', () {
      expect(
        parseProposals(
          jsonEncode([
            {
              'kind': 'deload',
              'deload': {'from': 'ooit', 'days': 7},
            },
          ]),
        ),
        isEmpty,
      );
    });

    test('een voorbij begin start vandaag', () {
      final old = DeloadProposal(
        from: DateTime(2026, 10, 1),
        days: 7,
        plan: const DeloadPlan(),
      );
      expect(old.startAt(DateTime(2026, 10, 18, 15)), DateTime(2026, 10, 18));
      expect(old.startAt(DateTime(2026, 9, 30, 15)), DateTime(2026, 10, 1));
    });
  });

  group('de knop', () {
    late Directory home;
    ProviderContainer? container;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('fitlog_deload');
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appPathsProvider.overrideWith((ref) => AppPaths(home)),
          coachClientFactoryProvider.overrideWithValue(
            (apiKey, provider) => AiClient(
              apiKey: apiKey,
              provider: provider,
              client: MockClient((request) async => http.Response('{}', 500)),
            ),
          ),
        ],
      );
    });

    tearDown(() async {
      container?.dispose();
      if (await home.exists()) await home.delete(recursive: true);
    });

    Future<ChatMessageRow> answerWith(DeloadProposal deload) async {
      await db.chatDao.createThread('t-1', 'Deload?');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Neem een deloadweek.',
        proposals: encodeProposals([CoachProposal.ofDeload(deload)]),
      );
      return (await db.chatDao.messages('t-1')).single;
    }

    test(
      'Starten start ze, door de coach, en tweemaal tikken is één',
      () async {
        final coach = container!.read(coachControllerProvider.notifier);
        // Proposed a week ago, tapped today: it starts today.
        final message = await answerWith(
          DeloadProposal(
            from: DateTime(today.year, today.month, today.day - 7),
            days: 5,
            plan: const DeloadPlan(setsPercent: 40),
          ),
        );

        final id = await coach.accept(message: message, index: 0);
        final deload = (await db.deloadDao.onAt(now))!;
        expect(deload.id, id);
        expect(deload.from, today);
        expect(deload.days, 5);
        expect(deload.source, 'coach');
        expect(deload.plan.setsPercent, 40);

        final stored = parseProposals(
          (await db.chatDao.messages('t-1')).single.proposals,
        ).single;
        expect(stored.appliedId, id);
        expect(stored.deload!.from, today);

        final again = await coach.accept(
          message: (await db.chatDao.messages('t-1')).single,
          index: 0,
        );
        expect(again, id);
        expect(await db.deloadDao.all(), hasLength(1));
      },
    );

    test('na Aanpassen houdt de kaart wat er gestart werd', () async {
      final coach = container!.read(coachControllerProvider.notifier);
      final message = await answerWith(
        DeloadProposal(from: today, days: 7, plan: const DeloadPlan()),
      );
      // What the start sheet does with the numbers changed.
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final id = await db.deloadDao.start(
        from: tomorrow,
        days: 4,
        plan: const DeloadPlan(weightPercent: 20),
        source: 'coach',
      );

      await coach.noteDeloadStarted(message: message, index: 0, id: id);

      final stored = parseProposals(
        (await db.chatDao.messages('t-1')).single.proposals,
      ).single;
      expect(stored.appliedId, id);
      expect(stored.deload!.from, tomorrow);
      expect(stored.deload!.days, 4);
      expect(stored.deload!.plan.weightPercent, 20);
      expect(stored.title, 'Deload van 4 dagen');
    });
  });

  group('wat meegaat met een vraag', () {
    late Directory home;
    ProviderContainer? container;
    late List<String> sent;

    setUp(() async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      home = await Directory.systemTemp.createTemp('fitlog_deload_ask');
      sent = [];
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appPathsProvider.overrideWith((ref) => AppPaths(home)),
          coachClientFactoryProvider.overrideWithValue(
            (apiKey, provider) => AiClient(
              apiKey: apiKey,
              provider: provider,
              client: MockClient((request) async {
                sent.add(request.body);
                return http.Response(
                  jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {'text': 'Rustig aan deze week.'},
                          ],
                        },
                      },
                    ],
                    'usageMetadata': {
                      'promptTokenCount': 1200,
                      'candidatesTokenCount': 10,
                    },
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          ),
        ],
      );
    });

    tearDown(() async {
      container?.dispose();
      if (await home.exists()) await home.delete(recursive: true);
    });

    Future<ChatMessageRow> ask() async {
      final coach = container!.read(coachControllerProvider.notifier);
      final thread = await coach.startThread('Hoe zwaar?');
      await coach.ask(threadId: thread, question: 'Hoe zwaar vandaag?');
      return (await db.chatDao.messages(thread)).last;
    }

    test('een lopende deload, en het antwoord zegt dat die meeging', () async {
      await db.deloadDao.start(
        from: daysAgo(1),
        days: 7,
        plan: const DeloadPlan(),
        source: 'user',
        now: daysAgo(1),
      );

      final answer = await ask();

      expect(sent.single, contains('Er loopt een deload, dag 2 van 7'));
      expect(answer.lookups, contains('dat je in een deload zit'));
    });

    test('een geplande zegt dat ook', () async {
      await db.deloadDao.start(
        from: DateTime(today.year, today.month, today.day + 2),
        days: 5,
        plan: const DeloadPlan(),
        source: 'user',
      );

      final answer = await ask();

      expect(sent.single, contains('Er staat een deload gepland'));
      expect(answer.lookups, contains('dat er een deload gepland staat'));
    });

    test('zonder deload gaat er niets over mee', () async {
      final answer = await ask();

      expect(sent.single, isNot(contains('Er loopt een deload')));
      expect(sent.single, isNot(contains('deload gepland')));
      expect(answer.lookups, isNull);
    });
  });

  group('de prompt', () {
    test('zegt in één regel dat er een deload loopt of gepland staat', () {
      expect(
        describeDeload(
          day: 2,
          days: 7,
          from: DateTime(2026, 10, 17),
          lastDay: DateTime(2026, 10, 23),
        ),
        'Er loopt een deload, dag 2 van 7, tot en met 2026-10-23: lichter is '
        'nu de bedoeling.',
      );
      expect(
        describeDeload(
          day: null,
          days: 5,
          from: DateTime(2026, 10, 19),
          lastDay: DateTime(2026, 10, 23),
        ),
        'Er staat een deload gepland: 5 dagen vanaf 2026-10-19.',
      );
    });

    test('alleen als die er is, en binnen het budget zonder', () {
      final line = describeDeload(
        day: 1,
        days: 7,
        from: DateTime(2026, 10, 18),
        lastDay: DateTime(2026, 10, 24),
      );
      final plain = buildCoachPrompt(
        now: DateTime(2026, 10, 18),
        weightUnit: 'kg',
      );

      expect(
        buildCoachPrompt(
          now: DateTime(2026, 10, 18),
          weightUnit: 'kg',
          deload: line,
        ),
        contains(line),
      );
      expect(plain, isNot(contains('deload')));
      expect(plain.length, lessThan(4300));
    });

    test('en de coach kan het opvragen en voorstellen', () {
      final offered = {
        for (final tool in CoachTools.definitions()) tool['name'],
      };
      expect(offered, containsAll(['deload', 'propose_deload']));
      expect(CoachTools.names, containsAll(['deload', 'propose_deload']));
    });
  });
}
