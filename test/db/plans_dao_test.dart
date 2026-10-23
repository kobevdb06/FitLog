import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/db/dao/plans_dao.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Where the schema's are kept: one followed at a time, its sessions out of
/// the way of your own workouts, and its weeks counted on what was done.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final at = DateTime(2026, 10, 20, 12);

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> draft(String id) => db.plansDao.createDraft(
    id: id,
    goal: '  Sterker op bench  ',
    split: PlanSplit.pushPullLegs,
    days: 0x15,
    progression: PlanProgression.app,
    at: at,
  );

  Future<String> session(String plan, String name, int position) async {
    final id = await db.routinesDao.createRoutine(
      RoutineDraft(name: name, exercises: []),
    );
    await db.plansDao.placeSession(
      id,
      planId: plan,
      position: position,
      weekday: position + 1,
    );
    return id;
  }

  Future<void> done(String routineId, DateTime when) => db
      .into(db.workoutsTable)
      .insert(
        WorkoutsTableCompanion.insert(
          id: 'w-$routineId-${when.millisecondsSinceEpoch}',
          routineId: Value(routineId),
          name: 'Sessie',
          startedAt: when.millisecondsSinceEpoch,
          endedAt: Value(when.millisecondsSinceEpoch + 3600000),
        ),
      );

  test('a new schema is a draft with the goal in the user\'s words', () async {
    await draft('p-1');
    final plan = (await db.plansDao.plan('p-1'))!;
    expect(plan.state, PlanStatus.draft);
    expect(plan.name, PlansDao.unnamed);
    expect(plan.goal, 'Sterker op bench');
    expect(plan.splitKind, PlanSplit.pushPullLegs);
    expect(plan.splitNote, isNull);
    expect(plan.progressionKind, PlanProgression.app);
    expect(plan.weeks, isNull);
    expect(await db.plansDao.running(), isNull);
  });

  test('a custom split keeps its description, another split none', () async {
    await db.plansDao.createDraft(
      id: 'p-2',
      goal: 'Breder',
      split: PlanSplit.custom,
      splitNote: ' Borst en rug, dan benen ',
      days: 0,
      progression: PlanProgression.coach,
      at: at,
    );
    expect(
      (await db.plansDao.plan('p-2'))!.splitNote,
      'Borst en rug, dan benen',
    );
  });

  test('the sessions of a schema are not among your own workouts', () async {
    await draft('p-1');
    await db.routinesDao.createRoutine(
      const RoutineDraft(name: 'Eigen', exercises: []),
    );
    await session('p-1', 'Pull', 1);
    await session('p-1', 'Push', 0);

    final own = await db.routinesDao.watchRoutines().first;
    expect([for (final r in own) r.routine.name], ['Eigen']);
    final ofPlan = await db.routinesDao.watchRoutines(planId: 'p-1').first;
    expect([for (final r in ofPlan) r.routine.name], ['Push', 'Pull']);
    expect(
      [for (final r in await db.plansDao.sessions('p-1')) r.name],
      ['Push', 'Pull'],
    );
    expect((await db.routinesDao.suggestedRoutine())!.name, 'Eigen');
  });

  test('only one schema is followed: starting one stops the other', () async {
    await draft('p-1');
    await draft('p-2');
    await db.plansDao.start(
      'p-1',
      startDay: DateTime(2026, 10, 19, 15),
      at: at,
    );
    var running = (await db.plansDao.running())!;
    expect(running.id, 'p-1');
    expect(running.from, DateTime(2026, 10, 19));

    await db.plansDao.start('p-2', startDay: DateTime(2026, 10, 26), at: at);
    running = (await db.plansDao.running())!;
    expect(running.id, 'p-2');
    final stopped = (await db.plansDao.plan('p-1'))!;
    expect(stopped.state, PlanStatus.done);
    expect(stopped.endedAt, at.millisecondsSinceEpoch);
  });

  test('the weeks the coach laid out, and which one it is', () async {
    await draft('p-1');
    await db.plansDao.layOut(
      'p-1',
      name: 'Kracht en massa',
      weeks: const [
        PlanWeek(),
        PlanWeek(sets: 1),
        PlanWeek(kind: PlanWeekKind.deload),
      ],
      at: at,
    );
    await db.plansDao.start('p-1', startDay: DateTime(2026, 10, 19), at: at);
    final plan = (await db.plansDao.plan('p-1'))!;
    expect(plan.name, 'Kracht en massa');
    expect(plan.weeks, 3);
    expect(plan.weekAt(DateTime(2026, 10, 28)), 2);
    expect(plan.weekPlan(2).sets, 1);
    expect(plan.weekPlan(3).isDeload, isTrue);
    expect(plan.weekPlan(9), const PlanWeek());
    expect(plan.isOverAt(DateTime(2026, 11, 8, 23)), isFalse);
    expect(plan.isOverAt(DateTime(2026, 11, 9)), isTrue);
  });

  test('a week counts what was finished in it, on any day', () async {
    await draft('p-1');
    final push = await session('p-1', 'Push', 0);
    final pull = await session('p-1', 'Pull', 1);
    final legs = await session('p-1', 'Legs', 2);
    await db.plansDao.start('p-1', startDay: DateTime(2026, 10, 19), at: at);

    // Pull on Sunday of the week before, Push on Thursday, Legs next week.
    await done(pull, DateTime(2026, 10, 18, 10));
    await done(push, DateTime(2026, 10, 22, 18));
    await done(legs, DateTime(2026, 10, 26, 9));

    final plan = (await db.plansDao.plan('p-1'))!;
    final week = await db.plansDao.standing(plan, 1);
    expect(week.done, {push});
    expect(week.next, pull);
    expect(week.missing, [pull, legs]);
  });

  test('finishing keeps the sessions; deleting takes them along', () async {
    await draft('p-1');
    final push = await session('p-1', 'Push', 0);
    await db.plansDao.finish('p-1', at);
    expect((await db.plansDao.plan('p-1'))!.state, PlanStatus.done);
    expect(await db.routinesDao.getRoutine(push), isNotNull);

    await db.plansDao.deletePlan('p-1');
    expect(await db.plansDao.plan('p-1'), isNull);
    expect(await db.routinesDao.getRoutine(push), isNull);
  });

  test('an outline waits for approval, and so does every session', () async {
    await draft('p-1');
    await db.plansDao.saveOutline(
      'p-1',
      name: 'Kracht',
      weeks: const [
        PlanWeek(),
        PlanWeek(kind: PlanWeekKind.deload),
      ],
      volume: const {'borst': 12, 'rug': 14},
      at: at,
      approved: false,
    );
    final push = await db.routinesDao.createRoutine(
      const RoutineDraft(name: 'Push', exercises: []),
    );
    await db.plansDao.placeSession(
      push,
      planId: 'p-1',
      position: 0,
      focus: 'borst zwaar',
      state: PlanSessionState.planned,
    );

    var plan = (await db.plansDao.plan('p-1'))!;
    expect(plan.outlineApproved, isFalse);
    expect(plan.outlineAt, at.millisecondsSinceEpoch);
    expect(plan.weeklySets, {'borst': 12, 'rug': 14});
    var sessions = await db.plansDao.sessions('p-1');
    expect(sessions.single.planFocus, 'borst zwaar');
    expect(sessions.single.sessionState, PlanSessionState.planned);
    expect(planComplete(plan, sessions), isFalse);

    await db.plansDao.approveOutline('p-1', at);
    await db.plansDao.markSession(push, PlanSessionState.proposed);
    plan = (await db.plansDao.plan('p-1'))!;
    sessions = await db.plansDao.sessions('p-1');
    expect(plan.outlineApproved, isTrue);
    expect(planComplete(plan, sessions), isFalse);

    await db.plansDao.markSession(push, PlanSessionState.approved);
    sessions = await db.plansDao.sessions('p-1');
    expect(planComplete(plan, sessions), isTrue);
  });
}
