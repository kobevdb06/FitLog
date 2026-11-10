import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/calc/milestones.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/domain/coach_prompt.dart'
    show kCoachLimits;
import 'package:fitlog/features/prompts/data/moment_answerer.dart';
import 'package:fitlog/features/prompts/data/moment_facts.dart';
import 'package:fitlog/features/prompts/data/prompt_alarm.dart';
import 'package:fitlog/features/prompts/domain/coach_moments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// The geplande prompts beyond the workout: when each asks, what it is
/// about, and that the alarm that carries the ones with a notification
/// keeps its own time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late List<String> sent;

  AiClient client(String apiKey, CoachProvider provider) => AiClient(
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
                  {'text': 'Tijd om weer te gaan: een halfuur volstaat.'},
                ],
              },
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 600,
            'candidatesTokenCount': 20,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  /// A finished session of one bench press set on [day].
  Future<String> session(DateTime day, {double kg = 80}) async {
    final id = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(id, ['ex-bench'], defaultRestSeconds: 90);
    final set = (await db.workoutsDao.getWorkoutDetail(id))!
        .exercises
        .single
        .sets
        .single;
    await db.workoutsDao.updateSet(
      set.id,
      weightKg: Value(kg),
      reps: const Value(6),
      isCompleted: const Value(true),
    );
    await db.workoutsDao.finishWorkout(id, discardPending: false);
    await db.customStatement(
      'UPDATE workouts SET started_at = ? WHERE id = ?',
      [day.millisecondsSinceEpoch, id],
    );
    return id;
  }

  Future<void> on(CoachMoment moment, {String? option}) => db.coachPromptsDao
      .savePrompt(moment: moment, enabled: true, option: option);

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bankdrukken',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );
  });

  tearDown(() => db.close());

  test('elk moment heeft dezelfde grenzen als de chat (DECISIONS 250)', () {
    for (final moment in CoachMoment.values) {
      final system = buildMomentSystem(
        prompt: MomentPrompt(moment: moment, enabled: true),
        notes: const ['Wil afvallen'],
      );
      expect(system, contains(kCoachLimits), reason: moment.name);
      expect(system, contains('<notities>'), reason: moment.name);
    }
  });

  group('wanneer de wekker afgaat', () {
    test('een tijd niet getraind: elke dag om 18:00, een vrij moment op zijn '
        'dag en uur, de maand op de eerste om 9:00 - de eerste van die', () {
      final friday = DateTime(2026, 10, 30, 12); // vrijdag
      const idle = PromptTimes(idle: true);
      expect(idle.nextAfter(friday), DateTime(2026, 10, 30, 18));
      expect(
        idle.nextAfter(DateTime(2026, 10, 30, 19)),
        DateTime(2026, 10, 31, 18),
      );

      const free = PromptTimes(free: (weekday: DateTime.monday, hour: 7));
      expect(free.nextAfter(friday), DateTime(2026, 11, 2, 7));

      const month = PromptTimes(month: true);
      expect(month.nextAfter(friday), DateTime(2026, 11, 1, 9));

      expect(
        const PromptTimes(
          idle: true,
          month: true,
        ).nextAfter(DateTime(2026, 10, 31, 19)),
        DateTime(2026, 11, 1, 9),
      );
      expect(const PromptTimes().nextAfter(friday), isNull);
    });

    test('de wekker draagt zijn tijden mee, zodat een pincode niet in de '
        'weg staat', () {
      const times = PromptTimes(
        idle: true,
        free: (weekday: DateTime.friday, hour: 18),
      );
      final back = PromptTimes.fromParams(times.toParams());
      expect(back.idle, isTrue);
      expect(back.free, (weekday: DateTime.friday, hour: 18));
      expect(back.month, isFalse);
    });
  });

  group('met een sleutel', () {
    setUp(() => db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg'));

    test('een tijd niet getraind: één keer per keer dat je stilvalt, als '
        'gesprek in de chat, één keer geteld', () async {
      await on(CoachMoment.idle, option: '5');
      final now = DateTime(2026, 10, 30, 18, 5);
      await session(DateTime(2026, 10, 24, 18));

      final runs = await runDuePrompts(db, now: now, clientFactory: client);

      expect(runs.single.moment, CoachMoment.idle);
      final thread = runs.single.answer.threadId!;
      final messages = await db.chatDao.watchMessages(thread).first;
      expect([for (final m in messages) m.role], ['user', 'assistant']);
      expect(messages.last.content, startsWith('Tijd om weer te gaan'));
      expect((await db.chatDao.usageSince(DateTime(2026, 10, 30))).requests, 1);

      // De volgende dag is het dezelfde stilte: niets nieuws.
      expect(
        await runDuePrompts(
          db,
          now: DateTime(2026, 10, 31, 18, 5),
          clientFactory: client,
        ),
        isEmpty,
      );
      expect(sent, hasLength(1));
    });

    test('een tijd niet getraind vraagt niets voor de dagen om zijn', () async {
      await on(CoachMoment.idle, option: '5');
      await session(DateTime(2026, 10, 27, 18));

      expect(
        await runDuePrompts(
          db,
          now: DateTime(2026, 10, 30, 18, 5),
          clientFactory: client,
        ),
        isEmpty,
      );
      expect(sent, isEmpty);
    });

    test('een vrij moment op zijn dag, en niet nog eens de dag erna', () async {
      await on(
        CoachMoment.free,
        option: freeTimeOption((weekday: DateTime.friday, hour: 18)),
      );
      await session(DateTime(2026, 10, 28, 18));

      final runs = await runDuePrompts(
        db,
        now: DateTime(2026, 10, 30, 18, 2),
        clientFactory: client,
      );
      expect(runs.single.subject, '20261030');
      expect(
        await runDuePrompts(
          db,
          now: DateTime(2026, 10, 31, 10),
          clientFactory: client,
        ),
        isEmpty,
      );
    });

    test('de maand op de eerste, over de maand ervoor; zonder trainingen '
        'niets', () async {
      await on(CoachMoment.month);
      await session(DateTime(2026, 10, 12, 18));

      final runs = await runDuePrompts(
        db,
        now: DateTime(2026, 11, 1, 9, 5),
        clientFactory: client,
      );
      expect(runs.single.subject, '2026-10');
      expect(sent.single, contains(r'\"workouts\":1'));

      sent.clear();
      expect(
        await runDuePrompts(
          db,
          now: DateTime(2026, 12, 1, 9, 5),
          clientFactory: client,
        ),
        isEmpty,
      );
      expect(sent, isEmpty);
    });

    test('een weging hoogstens één keer per week', () async {
      await on(CoachMoment.weighing);
      final answerer = MomentAnswerer(db, clientFactory: client);
      await db.coachPromptsDao.saveMomentAnswer(
        moment: CoachMoment.weighing,
        subject: '20261027',
        createdAt: DateTime(2026, 10, 27, 8),
        prompt: 'Hoe gaat mijn gewicht?',
        facts: '{}',
        coachText: 'Stabiel.',
      );

      expect(
        await answerer.isDue(
          CoachMoment.weighing,
          '20261030',
          now: DateTime(2026, 10, 30, 8),
        ),
        isFalse,
      );
      expect(
        await answerer.isDue(
          CoachMoment.weighing,
          '20261104',
          now: DateTime(2026, 11, 4, 8),
        ),
        isTrue,
      );
    });

    test('voor je workout: de sets zoals ze klaarstaan, de vorige keer en '
        'vandaag', () async {
      await session(DateTime(2026, 10, 27, 18), kg: 80);
      final id = await db.workoutsDao.startWorkout(
        name: 'Push',
        defaultRestSeconds: 90,
      );
      await db.workoutsDao.addExercises(id, [
        'ex-bench',
      ], defaultRestSeconds: 90);

      final facts = (await momentFacts(
        db,
        CoachMoment.before,
        id,
        health: false,
        now: DateTime.now(),
      ))!;

      final bench = (facts['exercises']! as List).single as Map;
      expect(bench['name'], 'Bankdrukken');
      expect((bench['last_time']! as Map)['sets'], [
        {'weight_kg': 80.0, 'reps': 6},
      ]);
      expect(facts.containsKey('vandaag'), isTrue);
    });
  });

  test('een mijlpaal: de eerste workout is er een, de tweede niet', () async {
    final first = await session(DateTime(2026, 10, 1, 18));
    final reached = await milestoneReachedBy(db, first);
    expect(reached?.kind, MilestoneKind.workouts);
    expect(MomentSubject.milestone(reached!.kind, reached.step), 'workouts:1');
    expect(milestoneLabel('workouts:1'), 'je eerste workout');

    final second = await session(DateTime(2026, 10, 2, 18));
    expect(await milestoneReachedBy(db, second), isNull);
  });

  group('de wekker zelf', () {
    late _Alarm alarm;
    late _Notices notices;
    late KeyManager keys;
    AppDatabase? opened;
    final evening = DateTime(2026, 10, 30, 18);

    setUp(() {
      alarm = _Alarm();
      notices = _Notices();
      keys = KeyManager(InMemorySecretStore());
      opened = null;
    });

    PromptAlarmHandler handler({bool handedOff = false}) => PromptAlarmHandler(
      times: const PromptTimes(idle: true),
      schedule: PromptSchedule(alarm),
      handOff: () async => handedOff,
      keys: keys,
      openDatabase: (key) async => opened = db,
      notices: notices,
      clientFactory: client,
      clock: () => evening,
    );

    test('met een pincode blijft het logboek dicht, en de volgende staat '
        'toch', () async {
      await keys.setPin(dek: Uint8List(32), pin: '1234');

      expect(await handler().handle(), PromptOutcome.locked);
      expect(opened, isNull);
      expect(notices.locked, 1);
      expect(alarm.at, DateTime(2026, 10, 31, 18));
    });

    test('is de app open, dan doet die het', () async {
      await keys.setDirectKey(Uint8List(32));

      expect(await handler(handedOff: true).handle(), PromptOutcome.handedOff);
      expect(opened, isNull);
    });

    test('zonder pincode: vragen en melden', () async {
      await keys.setDirectKey(Uint8List(32));
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await on(CoachMoment.idle, option: '3');
      await session(DateTime(2026, 10, 25, 18));

      expect(await handler().handle(), PromptOutcome.asked);
      expect(notices.shown.single.moment, CoachMoment.idle);
    });
  });
}

class _Alarm implements PromptAlarm {
  DateTime? at;

  @override
  Future<void> setAt(DateTime at, PromptTimes times) async => this.at = at;

  @override
  Future<void> cancel() async => at = null;
}

class _Notices implements PromptNotices {
  final List<PromptRun> shown = [];
  int locked = 0;

  @override
  Future<void> show(PromptRun run) async => shown.add(run);

  @override
  Future<void> showLocked() async => locked++;

  @override
  Future<bool> lockedShowing() async => false;
}
