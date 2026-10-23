import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/dashboard/presentation/today_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/routines/presentation/routines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Trainen in two: your own workouts, and the schema's - switched in the top
/// right corner, each with its own button floating over it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1100, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      wrapWithContainer(container!, const RoutinesScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> toPlans(WidgetTester tester) async {
    await tester.tap(find.byTooltip("Schema's"));
    // The schema, its sessions, then what was done in them: one after the
    // other.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// A running schema of three weeks, from this Monday, with [sessions].
  Future<List<String>> runningPlan({int sessions = 3}) async {
    await db.plansDao.createDraft(
      id: 'p-1',
      goal: 'Sterker',
      split: PlanSplit.pushPullLegs,
      days: 0x15,
      progression: PlanProgression.app,
      at: DateTime.now(),
    );
    await db.plansDao.layOut(
      'p-1',
      name: 'Kracht en massa',
      weeks: const [
        PlanWeek(note: 'rustig beginnen'),
        PlanWeek(sets: 1),
        PlanWeek(kind: PlanWeekKind.deload),
      ],
      at: DateTime.now(),
    );
    final ids = <String>[];
    for (var i = 0; i < sessions; i++) {
      final id = await db.routinesDao.createRoutine(
        RoutineDraft(name: 'Sessie ${i + 1}', exercises: const []),
      );
      await db.plansDao.placeSession(
        id,
        planId: 'p-1',
        position: i,
        weekday: i % 7 + 1,
      );
      ids.add(id);
    }
    final now = DateTime.now();
    await db.plansDao.start(
      'p-1',
      startDay: DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      at: now,
    );
    return ids;
  }

  testWidgets('Workouts is wat het was, met + Routine', (tester) async {
    await db.routinesDao.createRoutine(
      const RoutineDraft(name: 'Eigen routine', exercises: []),
    );
    await runningPlan();
    await pump(tester);

    expect(find.text('Eigen routine'), findsOneWidget);
    expect(find.text('Sessie 1'), findsNothing);
    expect(
      find.widgetWithText(FloatingActionButton, 'Routine'),
      findsOneWidget,
    );
  });

  testWidgets('zonder schema nodigt Schema\'s uit om er een te maken', (
    tester,
  ) async {
    await pump(tester);
    await toPlans(tester);

    expect(find.text('Nog geen schema'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Schema'), findsOneWidget);
    expect(find.byTooltip('Routine zoeken'), findsNothing);
  });

  testWidgets('het lopende schema: de week, wat gedaan is en wat volgt', (
    tester,
  ) async {
    final ids = await runningPlan();
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-1',
            routineId: Value(ids[0]),
            name: 'Sessie 1',
            startedAt: DateTime.now()
                .subtract(const Duration(minutes: 90))
                .millisecondsSinceEpoch,
            endedAt: Value(
              DateTime.now()
                  .subtract(const Duration(minutes: 30))
                  .millisecondsSinceEpoch,
            ),
          ),
        );
    await pump(tester);
    await toPlans(tester);

    expect(find.text('Kracht en massa'), findsOneWidget);
    expect(find.text('Week 1 van 3'), findsOneWidget);
    expect(find.text('Deze week: rustig beginnen'), findsOneWidget);
    expect(find.text('DEZE WEEK · 1 VAN 3'), findsOneWidget);
    expect(find.text('Gedaan'), findsOneWidget);
    // The next is the first not done, whatever day it is meant for.
    final start = find.widgetWithText(FilledButton, 'Start');
    expect(start, findsOneWidget);
    expect(
      find.ancestor(of: start, matching: find.byType(ListTile)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(of: start, matching: find.byType(ListTile)),
        matching: find.text('Sessie 2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('een voorstel van de coach staat bovenaan het schema', (
    tester,
  ) async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await runningPlan();
    await db.chatDao.createThread('t-1', 'Kracht en massa', planId: 'p-1');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Sessie 3 schuift op.',
      proposals: encodeProposals([
        CoachProposal.ofPlanChange(
          const PlanChangeProposal(
            layout: PlanProposal(
              name: 'Kracht en massa',
              weeks: [PlanWeek(), PlanWeek()],
              sessions: [],
            ),
            input: {'name': 'Kracht en massa'},
          ),
          planId: 'p-1',
          change: 'Sessie 3 schuift op.',
        ),
      ]),
    );
    await pump(tester);
    await toPlans(tester);

    expect(find.text('De coach stelt iets voor'), findsOneWidget);
    expect(find.text('Aanvaarden of houden'), findsOneWidget);
  });

  testWidgets('op Start biedt Vandaag de volgende sessie van het schema aan', (
    tester,
  ) async {
    final ids = await runningPlan();
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-1',
            routineId: Value(ids[0]),
            name: 'Sessie 1',
            startedAt: DateTime.now()
                .subtract(const Duration(minutes: 90))
                .millisecondsSinceEpoch,
            endedAt: Value(
              DateTime.now()
                  .subtract(const Duration(minutes: 30))
                  .millisecondsSinceEpoch,
            ),
          ),
        );
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        scheduledRoutinesProvider.overrideWith((ref) => Stream.value([])),
        favouriteRoutinesProvider.overrideWith((ref) => Stream.value([])),
        suggestedRoutineProvider.overrideWith((ref) async => null),
      ],
    );
    await tester.pumpWidget(
      wrapWithContainer(container!, const DashboardScreen()),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Kracht en massa · week 1 van 3'), findsOneWidget);
    expect(find.text('Sessie 2'), findsOneWidget);
    expect(
      find.text('Volgende in je schema · 1 van 3 gedaan deze week'),
      findsOneWidget,
    );
    expect(find.text('Nog deze week'), findsOneWidget);
  });

  testWidgets('het lopende schema past op een smalle gsm met grote letters', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await runningPlan(sessions: 5);
    await pump(tester, size: const Size(360, 800));
    await toPlans(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Week 1 van 3'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('wat onderaan staat, komt boven de knop uit', (tester) async {
    await runningPlan(sessions: 7);
    await pump(tester, size: const Size(360, 640));
    await toPlans(tester);

    final page = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    page.position.jumpTo(page.position.maxScrollExtent);
    await tester.pump();

    final last = tester.getRect(find.text('Sessie 7'));
    final button = tester.getRect(find.byType(FloatingActionButton));
    expect(last.bottom, lessThan(button.top));
  });
}
