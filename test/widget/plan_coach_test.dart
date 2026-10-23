import 'dart:convert';
import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/presentation/coach_screen.dart';
import 'package:fitlog/features/chat/presentation/coach_session.dart';
import 'package:fitlog/features/plans/presentation/plan_new_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// A schema, made with the coach: the form, the card in its conversation,
/// and the schema's in the coach's panel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;
  late List<String> sent;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    sent = [];
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  CoachClientFactory apiSaying(String text) =>
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

  ProviderContainer makeContainer() => container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
      coachClientFactoryProvider.overrideWithValue(
        apiSaying('Hier is je schema.'),
      ),
    ],
  );

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// A draft p-1 with one session, its conversation t-1, and the coach's
  /// card in it.
  Future<void> seedDraft() async {
    await db.plansDao.createDraft(
      id: 'p-1',
      goal: 'Sterker op bench',
      split: PlanSplit.upperLower,
      days: 0x09,
      progression: PlanProgression.app,
      at: DateTime(2026, 10, 20),
    );
    await db.plansDao.layOut(
      'p-1',
      name: 'Kracht',
      weeks: const [
        PlanWeek(),
        PlanWeek(sets: 1),
        PlanWeek(kind: PlanWeekKind.deload),
      ],
      at: DateTime(2026, 10, 20),
    );
    await db.chatDao.createThread('t-1', 'Kracht', planId: 'p-1');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Drie weken, de laatste lichter.',
      proposals: encodeProposals([
        CoachProposal.ofPlan(
          const PlanProposal(
            name: 'Kracht',
            weeks: [
              PlanWeek(),
              PlanWeek(sets: 1, note: 'een set meer'),
              PlanWeek(kind: PlanWeekKind.deload),
            ],
            sessions: [
              ProposedPlanSession(
                name: 'Upper',
                weekday: 1,
                exercises: [
                  ProposedRoutineExercise(
                    exerciseId: 'ex-bench',
                    name: 'Bench Press',
                    sets: 3,
                    targetReps: 5,
                  ),
                ],
              ),
            ],
          ),
          appliedId: 'p-1',
          made: true,
          change: 'Twee dagen, boven en onder.',
        ),
      ]),
    );
  }

  testWidgets('de kaart toont het schema, en Start schema start het', (
    tester,
  ) async {
    bigScreen(tester);
    await seedDraft();
    makeContainer().read(coachSessionControllerProvider.notifier).show('t-1');
    await tester.pumpWidget(wrapWithContainer(container!, const CoachScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Schema van de coach'), findsOneWidget);
    expect(find.textContaining('3 weken'), findsOneWidget);
    expect(find.textContaining('deload in week 3'), findsOneWidget);
    expect(find.text('Week 2: een set meer'), findsOneWidget);
    expect(find.textContaining('Bench Press 3×5'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start schema'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Week 1 begint'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start schema').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final plan = await tester.runAsync(() => db.plansDao.plan('p-1'));
    expect(plan!.state, PlanStatus.running);
    expect(plan.from, firstPlanMonday(DateTime.now()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(FilledButton, 'Start schema'), findsNothing);
  });

  testWidgets('het paneel heeft Chats en Schema\'s, elk met het zijne', (
    tester,
  ) async {
    bigScreen(tester);
    await seedDraft();
    await db.chatDao.createThread('t-2', 'Hoeveel sets voor borst?');
    makeContainer();
    await tester.pumpWidget(wrapWithContainer(container!, const CoachScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Gesprekken'));
    await tester.pumpAndSettle();
    expect(find.text('Hoeveel sets voor borst?'), findsOneWidget);
    expect(find.text('Kracht'), findsNothing);

    await tester.tap(find.text("Schema's"));
    await tester.pumpAndSettle();
    expect(find.text('Nieuw schema'), findsOneWidget);
    expect(find.text('In voorbereiding'), findsWidgets);
    expect(find.text('Kracht'), findsOneWidget);
    expect(find.text('Hoeveel sets voor borst?'), findsNothing);
  });

  testWidgets('een voorstel van zondag: Houden laat het schema zoals het '
      'was', (tester) async {
    bigScreen(tester);
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
      goal: 'Sterker',
      split: PlanSplit.fullBody,
      days: 0x01,
      progression: PlanProgression.app,
      at: DateTime.now(),
    );
    await db.chatDao.createThread('t-1', 'Kracht', planId: 'p-1');
    final layout = {
      'name': 'Kracht',
      'change': 'De week overdoen.',
      'weeks': [
        for (var i = 0; i < 4; i++) {'kind': 'build'},
      ],
      'sessions': [
        {
          'name': 'Full body',
          'weekday': 1,
          'exercises': [
            {
              'exercise': 'Bench Press',
              'sets': [
                {'reps': 5},
              ],
            },
          ],
        },
      ],
    };
    await CoachTools(db, planId: 'p-1').run('save_plan', layout);
    final now = DateTime.now();
    await db.plansDao.start(
      'p-1',
      startDay: DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      at: now,
    );
    final card = (await CoachTools(db, planId: 'p-1', sunday: true).run(
      'propose_plan_change',
      layout
        ..['weeks'] = [
          for (var i = 0; i < 5; i++) {'kind': 'build'},
        ],
    )).proposal!;
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Doe de week nog eens.',
      proposals: encodeProposals([card]),
    );
    makeContainer().read(coachSessionControllerProvider.notifier).show('t-1');
    await tester.pumpWidget(wrapWithContainer(container!, const CoachScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Voorstel voor je schema'), findsOneWidget);
    expect(find.text('De week overdoen.'), findsOneWidget);
    await tester.tap(find.text('Houden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gehouden zoals het was.'), findsOneWidget);
    final plan = await tester.runAsync(() => db.plansDao.plan('p-1'));
    expect(plan!.weeks, 4);
  });

  group('het formulier', () {
    Future<void> pumpForm(WidgetTester tester) async {
      bigScreen(tester);
      makeContainer();
      final router = GoRouter(
        initialLocation: '/schema/nieuw',
        routes: [
          GoRoute(
            path: '/schema/nieuw',
            builder: (context, state) => const PlanNewScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const Text('het gesprek'),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container!,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('zegt wat er nog ontbreekt', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Custom: je eigen split'));
      await tester.pump();
      await tester.ensureVisible(find.text('Bespreek met de coach'));
      await tester.tap(find.text('Bespreek met de coach'));
      await tester.pump();

      expect(
        find.text('Schrijf wat je met dit schema wil bereiken.'),
        findsOneWidget,
      );
      expect(find.text('Beschrijf welke split je wil.'), findsOneWidget);
      expect(find.text('Kies minstens één dag.'), findsOneWidget);
      final plans = await tester.runAsync(() => db.plansDao.watchPlans().first);
      expect(plans, isEmpty);
    });

    testWidgets('maakt een ontwerp en vraagt de coach, in een gesprek van het '
        'schema', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Sterker op bench');
      await tester.tap(find.text('Upper/lower'));
      await tester.tap(find.text('ma'));
      await tester.tap(find.text('do'));
      await tester.pump();
      await tester.ensureVisible(find.text('Bespreek met de coach'));
      await tester.tap(find.text('Bespreek met de coach'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.text('het gesprek'), findsOneWidget);

      final plan = (await tester.runAsync(
        () => db.plansDao.watchPlans().first,
      ))!.single;
      expect(plan.state, PlanStatus.draft);
      expect(plan.goal, 'Sterker op bench');
      expect(plan.splitKind, PlanSplit.upperLower);
      final thread = (await tester.runAsync(
        () => db.chatDao.threadForPlan(plan.id),
      ))!;
      expect(
        container!.read(coachSessionControllerProvider).threadId,
        thread.id,
      );
      final messages = (await tester.runAsync(
        () => db.chatDao.messages(thread.id),
      ))!;
      expect(messages.first.content, contains('Dagen: maandag en donderdag'));
      // The coach was told what the conversation is for, and could lay it
      // out.
      expect(sent.single, contains('Dit gesprek hoort bij een schema'));
      expect(sent.single, contains('save_plan'));
    });
  });
}
