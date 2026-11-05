import 'dart:convert';

import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// What was done in a running schema stays done, however the coach changes
/// it afterwards: a session keeps who it is, and a workout keeps the session
/// it was done for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late CoachTools tools;
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  final weeks = [
    {'kind': 'build'},
    {'kind': 'build', 'sets': 1},
    {'kind': 'deload'},
  ];

  Map<String, Object?> outline(
    List<Map<String, Object?>> sessions, {
    List<String>? remove,
  }) => {
    'name': 'Kracht',
    'change': 'Pull anders.',
    'weeks': weeks,
    'sessions': sessions,
    'volume': [
      {'muscle': 'borst', 'sets': 12},
    ],
    'remove': ?remove,
  };

  Map<String, Object?> day(String name, int weekday, {String? was}) => {
    'name': name,
    'weekday': weekday,
    'focus': '$name zwaar',
    'was': ?was,
  };

  final all = [day('Push', 1), day('Pull', 3), day('Legs', 5)];

  Map<String, Object?> session(String name, {int sets = 4}) => {
    'session': name,
    'change': 'Zwaarder.',
    'exercises': [
      {'exercise': 'Bench Press', 'sets': sets, 'reps': 6, 'weight_kg': 100},
    ],
  };

  Future<RoutineRow> named(String name) async =>
      (await db.plansDao.sessions('p-1')).firstWhere((s) => s.name == name);

  Future<Set<String>> doneThisWeek() async {
    final plan = (await db.plansDao.plan('p-1'))!;
    return (await db.plansDao.standing(plan, 1)).done;
  }

  /// Push done this week, in a running schema of Push, Pull and Legs.
  Future<String> pushDone() async {
    final push = await named('Push');
    final id = await db.workoutsDao.startWorkout(
      routineId: push.id,
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.finishWorkout(id, discardPending: false);
    return push.id;
  }

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
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
    await db.plansDao.createDraft(
      id: 'p-1',
      goal: '140 kg bench',
      split: PlanSplit.pushPullLegs,
      days: WeekdaySet.of([1, 3, 5]).mask,
      progression: PlanProgression.app,
      at: now,
    );
    await db.chatDao.createThread('t-1', 'Kracht', planId: 'p-1');
    tools = CoachTools(db, planId: 'p-1');
    await tools.run('save_plan_outline', outline(all));
    await db.plansDao.approveOutline('p-1', now);
    for (final name in ['Push', 'Pull', 'Legs']) {
      await tools.run('save_plan_session', session(name));
    }
    await db.plansDao.start('p-1', startDay: monday, at: now);
  });

  tearDown(() => db.close());

  test('a workout keeps the session it was done for, even once the session '
      'is gone', () async {
    final push = await named('Push');
    final id = await db.workoutsDao.startWorkout(
      routineId: push.id,
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.finishWorkout(id, discardPending: false);

    await db.routinesDao.deleteRoutine(push.id);

    final workout = (await db.workoutsDao.getWorkoutDetail(id))!.workout;
    expect(workout.routineId, isNull);
    expect(workout.planSessionId, push.id);
  });

  test('a workout of your own routine is no session of a schema', () async {
    final own = await db.routinesDao.createRoutine(
      const RoutineDraft(name: 'Thuis', exercises: []),
    );
    final id = await db.workoutsDao.startWorkout(
      routineId: own,
      defaultRestSeconds: 90,
    );
    expect(
      (await db.workoutsDao.getWorkoutDetail(id))!.workout.planSessionId,
      isNull,
    );
  });

  group('the outline of a running schema', () {
    test('with only the session that changes is refused, and every session '
        'stays, with what was done', () async {
      final push = await pushDone();

      final lookup = await tools.run(
        'save_plan_outline',
        outline([day('Pull', 3)]),
      );

      final answer = decode(lookup);
      expect(answer['ok'], isFalse);
      expect(answer['error'], allOf(contains('Push'), contains('Legs')));
      expect(answer['error'], contains('remove'));
      expect(
        [for (final s in await db.plansDao.sessions('p-1')) s.name],
        ['Push', 'Pull', 'Legs'],
      );
      expect(await doneThisWeek(), {push});
    });

    test('whole, with one session changed, keeps the others and what was '
        'done in them', () async {
      final push = await pushDone();

      final lookup = await tools.run('save_plan_outline', outline(all));
      expect(decode(lookup)['ok'], isTrue);
      await tools.run('save_plan_session', session('Pull', sets: 5));

      expect((await named('Push')).id, push);
      expect(await doneThisWeek(), {push});
    });

    test('a renamed session is the same session: its exercises, and what was '
        'done in it', () async {
      final push = await pushDone();

      await tools.run(
        'save_plan_outline',
        outline([
          day('Push zwaar', 1, was: 'Push'),
          day('Pull', 3),
          day('Legs', 5),
        ]),
      );

      final renamed = await named('Push zwaar');
      expect(renamed.id, push);
      expect(
        (await db.routinesDao.getRoutineDetail(push))!.exercises,
        hasLength(1),
      );
      expect(await doneThisWeek(), {push});
    });

    test('takes away what is named in remove; put back under its name, it is '
        'the same session again', () async {
      final push = await pushDone();

      final removed = await tools.run(
        'save_plan_outline',
        outline([day('Pull', 3), day('Legs', 5)], remove: const ['push']),
      );
      expect(decode(removed)['ok'], isTrue);
      expect(
        [for (final s in await db.plansDao.sessions('p-1')) s.name],
        ['Pull', 'Legs'],
      );

      await tools.run('save_plan_outline', outline(all));
      expect((await named('Push')).id, push);
      expect(await doneThisWeek(), {push});
    });
  });

  group('a change of the whole schema, accepted', () {
    Map<String, Object?> layout(List<(String, String?)> sessions) => {
      'name': 'Kracht',
      'change': 'Pull anders.',
      'weeks': weeks,
      'sessions': [
        for (final (i, (name, was)) in sessions.indexed)
          {
            'name': name,
            'weekday': 1 + 2 * i,
            'was': ?was,
            'exercises': [
              {'exercise': 'Bench Press', 'sets': 4, 'reps': 6},
            ],
          },
      ],
    };

    test('that leaves sessions out is refused, and nothing changes', () async {
      final push = await pushDone();

      final lookup = await tools.applyPlanLayout(layout([('Pull', null)]));

      expect(decode(lookup)['ok'], isFalse);
      expect(await db.plansDao.sessions('p-1'), hasLength(3));
      expect(await doneThisWeek(), {push});
    });

    test(
      'is not even proposed on Sunday when it leaves sessions out',
      () async {
        final lookup = await CoachTools(
          db,
          planId: 'p-1',
          sunday: true,
        ).run('propose_plan_change', layout([('Pull', null)]));

        expect(decode(lookup)['ok'], isFalse);
        expect(
          decode(lookup)['error'],
          allOf(contains('Push'), contains('Legs')),
        );
        expect(lookup.proposal, isNull);
      },
    );

    test('keeps a renamed session, with what was done in it', () async {
      final push = await pushDone();

      final lookup = await tools.applyPlanLayout(
        layout([('Push A', 'Push'), ('Pull', null), ('Legs', null)]),
      );

      expect(decode(lookup)['ok'], isTrue);
      expect((await named('Push A')).id, push);
      expect(await doneThisWeek(), {push});
    });
  });
}
