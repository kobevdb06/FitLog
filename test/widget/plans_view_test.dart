import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/formatting/formatters.dart';
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

  Finder semantics(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  /// A draft called [name], not started.
  Future<void> draft(String id, String name) async {
    await db.plansDao.createDraft(
      id: id,
      goal: 'Sterker',
      split: PlanSplit.upperLower,
      days: 0x15,
      progression: PlanProgression.app,
      at: DateTime.now(),
    );
    await db.plansDao.layOut(
      id,
      name: name,
      weeks: const [PlanWeek(), PlanWeek()],
      at: DateTime.now(),
    );
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

  testWidgets('de wissel staat precies in het midden, en het lijntje schuift '
      'mee', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, size: const Size(360, 800));
    expect(tester.takeException(), isNull);

    final workouts = tester.getCenter(find.byTooltip('Workouts'));
    final plans = tester.getCenter(find.byTooltip("Schema's"));
    expect((workouts.dx + plans.dx) / 2, closeTo(180, 0.5));
    // The title and the switch stay clear of each other.
    expect(
      tester.getRect(find.text('Trainen')).right,
      lessThan(tester.getRect(find.byTooltip('Workouts')).left),
    );

    Finder line() => find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.maxWidth == 28,
    );
    expect(tester.getCenter(line()).dx, closeTo(workouts.dx, 1));
    // Under the icon, at the bottom of the bar - not through it.
    expect(
      tester.getRect(line()).top,
      greaterThan(tester.getRect(find.byTooltip('Workouts')).bottom - 4),
    );

    await tester.tap(find.byTooltip("Schema's"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // On its way.
    final halfway = tester.getCenter(line()).dx;
    expect(halfway, greaterThan(workouts.dx + 1));
    expect(halfway, lessThan(plans.dx - 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(line()).dx, closeTo(plans.dx, 1));
    // Search and the menu belong to your own routines.
    expect(find.byTooltip('Routine zoeken'), findsNothing);
    expect(tester.takeException(), isNull);
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
    // The weeks are the ring, this week the line under the name.
    expect(semantics('Week 1 van 3'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Rustig beginnen · 1 van 3 gedaan'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'Gedaan'),
      findsOneWidget,
    );
    // And each of them once.
    expect(find.text('Week 1 van 3'), findsNothing);
    expect(find.textContaining('DEZE WEEK'), findsNothing);
    expect(find.textContaining('cijfers'), findsNothing);
    expect(find.text('dagen zijn een richtlijn'), findsNothing);
    // The next is the first not done, open with what is in it, whatever
    // day it is meant for.
    final start = find.widgetWithText(FilledButton, 'Start');
    expect(start, findsOneWidget);
    expect(
      tester.getTopLeft(start).dy,
      greaterThan(tester.getTopLeft(find.text('Sessie 2')).dy),
    );
    expect(
      tester.getTopLeft(start).dy,
      lessThan(tester.getTopLeft(find.text('Sessie 3')).dy),
    );
    expect(find.text('Nog geen oefeningen'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Lichter'), findsOneWidget);
  });

  testWidgets('een tik op een andere sessie zet die open', (tester) async {
    await runningPlan();
    await pump(tester);
    await toPlans(tester);

    await tester.tap(find.text('Sessie 3'));
    await tester.pump();

    final start = find.widgetWithText(FilledButton, 'Start');
    expect(start, findsOneWidget);
    expect(
      tester.getTopLeft(start).dy,
      greaterThan(tester.getTopLeft(find.text('Sessie 3')).dy),
    );
  });

  testWidgets('onder ⋮: een nieuw schema, wat dit schema is, en stoppen', (
    tester,
  ) async {
    await runningPlan();
    await pump(tester);
    await toPlans(tester);
    // While one is followed, nothing floats over its sessions.
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byTooltip('Meer'));
    await tester.pumpAndSettle();
    expect(find.text('Nieuw schema'), findsOneWidget);
    expect(find.text('Stoppen'), findsOneWidget);

    await tester.tap(find.text('Over dit schema'));
    await tester.pumpAndSettle();
    expect(find.text('push/pull/legs'), findsOneWidget);
    expect(find.text('FitLog stelt ze bij'), findsOneWidget);
    expect(find.text('Rustig beginnen'), findsOneWidget);
    expect(find.text('Deload: elke sessie lichter'), findsOneWidget);
  });

  testWidgets('over dit schema op een smalle gsm: elke waarde rechts, op '
      'één regel', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await runningPlan();
    // The coach sets the numbers: the longest of the two.
    await (db.update(db.trainingPlansTable)..where((t) => t.id.equals('p-1')))
        .write(const TrainingPlansTableCompanion(progression: Value('coach')));
    await pump(tester, size: const Size(360, 800));
    await toPlans(tester);

    await tester.tap(find.byTooltip('Meer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Over dit schema'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final split = tester.getRect(find.text('push/pull/legs'));
    final numbers = tester.getRect(find.text('De coach zet ze elke week'));
    final began = tester.getRect(
      find.text(Formatters.weekdayDayMonthShort(monday)),
    );
    // All the room beside its label, not half the row: in half,
    // "De coach zet ze elke week" broke over two lines on the phone. (The
    // test font is wider than the phone's, so the line itself is not what
    // to count here.)
    expect(
      numbers.left,
      closeTo(tester.getRect(find.text('Cijfers')).right + 12, 1),
    );
    // And all three against the right edge.
    expect(numbers.right, closeTo(split.right, 1));
    expect(began.right, closeTo(split.right, 1));
  });

  testWidgets('de andere schema\'s staan eronder, één regel per soort', (
    tester,
  ) async {
    await runningPlan();
    await draft('p-2', 'Volgende blok');
    await pump(tester);
    await toPlans(tester);

    expect(find.text('In voorbereiding'), findsOneWidget);
    expect(find.text('Volgende blok'), findsNothing);
    await tester.tap(find.text('In voorbereiding'));
    await tester.pumpAndSettle();
    expect(find.text('Volgende blok'), findsOneWidget);
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
    // And a dot on the conversation in the bar.
    expect(
      find.byWidgetPredicate((w) => w is Badge && w.isLabelVisible),
      findsOneWidget,
    );
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
        suggestedRoutineProvider.overrideWith((ref) => Stream.value(null)),
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
    expect(semantics('Week 1 van 3'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Lichter'), findsOneWidget);
    // The conversation and ⋮ fit beside the switch.
    expect(
      tester.getRect(find.byTooltip('Gesprek met de coach')).left,
      greaterThan(tester.getRect(find.byTooltip("Schema's")).right),
    );
  });

  testWidgets('een lopend schema: tot de laatste sessie in beeld', (
    tester,
  ) async {
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

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.getRect(find.text('Sessie 7')).bottom, lessThan(640));
  });

  testWidgets('zonder lopend schema komt wat onderaan staat boven de knop '
      'uit', (tester) async {
    for (var i = 1; i <= 9; i++) {
      await draft('d-$i', 'Ontwerp $i');
    }
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

    // Whichever of them comes last.
    final last = tester
        .widgetList<Text>(find.textContaining('Ontwerp '))
        .map((text) => tester.getRect(find.byWidget(text)))
        .reduce((a, b) => a.bottom > b.bottom ? a : b);
    final button = tester.getRect(find.byType(FloatingActionButton));
    expect(last.bottom, lessThan(button.top));
  });
}
