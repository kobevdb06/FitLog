import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/plan_weeks.dart';
import 'package:fitlog/core/calc/recovery.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/app.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/dashboard/presentation/today_providers.dart';
import 'package:fitlog/features/progress/presentation/recovery_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:fitlog/features/routines/presentation/routines_screen.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The check before a session: on Vandaag, behind it, and under Schema's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;
  late Map<String, String> ids;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name, muscle) in [
      ('ex-squat', 'Squat', 'quadriceps'),
      ('ex-bench', 'Bench Press', 'borst'),
      ('ex-row', 'Barbell Row', 'lats'),
    ]) {
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: id,
              name: name,
              primaryMuscle: muscle,
              category: 'barbell',
              createdAt: 0,
            ),
          );
    }

    // A schema of three sessions, running since this Monday.
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
      weeks: const [PlanWeek(), PlanWeek(), PlanWeek()],
      at: DateTime.now(),
    );
    ids = {};
    for (final (i, (name, exercise)) in [
      ('Legs', 'ex-squat'),
      ('Push', 'ex-bench'),
      ('Pull', 'ex-row'),
    ].indexed) {
      final id = await db.routinesDao.createRoutine(
        RoutineDraft(
          name: name,
          exercises: [
            RoutineExerciseDraft(
              exerciseId: exercise,
              sets: [
                const RoutineSetDraft(
                  setType: SetType.warmup,
                  targetWeightKg: 40,
                  targetReps: 10,
                ),
                for (var s = 0; s < 4; s++)
                  const RoutineSetDraft(targetWeightKg: 80, targetReps: 8),
              ],
            ),
          ],
        ),
      );
      await db.plansDao.placeSession(
        id,
        planId: 'p-1',
        position: i,
        weekday: i * 2 + 1,
      );
      ids[name] = id;
    }
    final now = DateTime.now();
    await db.plansDao.start(
      'p-1',
      startDay: DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      at: now,
    );
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  /// Quadriceps trained 20 hours ago, with 40 still to go.
  RecoveryEstimate sore() => RecoveryEstimate(
    muscle: 'quadriceps',
    workoutId: 'w',
    trainedAt: DateTime.now().subtract(const Duration(hours: 20)),
    recovery: const Duration(hours: 60),
    loadRatio: 1,
    provisional: false,
  );

  /// Quadriceps trained four days ago, long recovered.
  RecoveryEstimate rested() => RecoveryEstimate(
    muscle: 'quadriceps',
    workoutId: 'w',
    trainedAt: DateTime.now().subtract(const Duration(hours: 90)),
    recovery: const Duration(hours: 48),
    loadRatio: 1,
    provisional: false,
  );

  /// A night that ended today - half an hour ago, or just after midnight.
  SleepEntryRow night(Duration length) {
    final now = DateTime.now();
    final ago = now.subtract(const Duration(minutes: 30));
    final woke = ago.day == now.day
        ? ago
        : DateTime(now.year, now.month, now.day, 0, 1);
    return SleepEntryRow(
      id: 'n',
      fellAsleepAt: woke.subtract(length).millisecondsSinceEpoch,
      wokeAt: woke.millisecondsSinceEpoch,
    );
  }

  final shortNight = const Duration(hours: 5, minutes: 10);
  final goodNight = const Duration(hours: 7, minutes: 40);

  Future<void> pump(
    WidgetTester tester, {
    List<RecoveryEstimate> estimates = const [],
    List<SleepEntryRow> nights = const [],
    Widget screen = const DashboardScreen(),
    Size size = const Size(1100, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        scheduledRoutinesProvider.overrideWith((ref) => Stream.value([])),
        favouriteRoutinesProvider.overrideWith((ref) => Stream.value([])),
        suggestedRoutineProvider.overrideWith((ref) async => null),
        recoveryEstimatesProvider.overrideWith(
          (ref) => Stream.value(estimates),
        ),
        sleepEntriesProvider.overrideWith((ref) => Stream.value(nights)),
        vitalsDaysProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen),
        GoRoute(
          path: Routes.workout,
          builder: (context, state) => const Text('de workout'),
        ),
        GoRoute(
          path: Routes.chat,
          builder: (context, state) => const Text('de coach'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          routerConfig: router,
          builder: appBuilder,
          theme: AppTheme.dark,
          locale: const Locale('nl'),
          supportedLocales: const [Locale('nl')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<WorkoutRow?> started(WidgetTester tester) =>
      tester.runAsync<WorkoutRow?>(db.workoutsDao.getActiveWorkoutRow);

  group('op Vandaag', () {
    testWidgets('twee seinen: Legs kan beter wachten, en Doe vandaag Push '
        'start Push', (tester) async {
      await pump(tester, estimates: [sore()], nights: [night(shortNight)]);

      expect(find.text('Kracht en massa · week 1 van 3'), findsOneWidget);
      expect(find.text('Legs kan beter wachten'), findsOneWidget);
      expect(
        find.textContaining('Quadriceps nog 40 u · 5 u 10 geslapen'),
        findsOneWidget,
      );
      expect(find.text('Toch Legs'), findsOneWidget);

      await tester.tap(find.text('Doe vandaag Push'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final workout = await started(tester);
      expect(workout?.routineId, ids['Push']);
      expect(workout?.isLight, isFalse);
      expect(find.text('de workout'), findsOneWidget);
    });

    testWidgets('Andere keuzes toont waar het vandaan komt, en lichter start '
        'Legs lichter', (tester) async {
      await pump(tester, estimates: [sore()], nights: [night(shortNight)]);

      await tester.tap(find.byTooltip('Andere keuzes'));
      await tester.pumpAndSettle();

      expect(find.text('Check voor Legs'), findsOneWidget);
      expect(find.text('Beter wachten'), findsOneWidget);
      expect(find.text('Quadriceps'), findsOneWidget);
      expect(find.text('4 sets'), findsOneWidget);
      expect(find.textContaining('nog 40 u'), findsWidgets);
      expect(find.textContaining('5 u 10 · score'), findsOneWidget);
      expect(find.text('Doe vandaag Push'), findsWidgets);

      final lighter = find.widgetWithText(OutlinedButton, 'Legs, lichter');
      await tester.ensureVisible(lighter);
      await tester.tap(lighter);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final workout = await started(tester);
      expect(workout?.routineId, ids['Legs']);
      expect(workout?.isLight, isTrue);
      expect(workout?.isDeload, isTrue);
    });

    testWidgets('Waarom? zet een vraag klaar voor de coach, niet verstuurd', (
      tester,
    ) async {
      await tester.runAsync(() => db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg'));
      await pump(tester, estimates: [sore()], nights: [night(shortNight)]);

      await tester.tap(find.byTooltip('Andere keuzes'));
      await tester.pumpAndSettle();
      final why = find.text('Waarom? Vraag de coach');
      await tester.ensureVisible(why);
      await tester.tap(why);
      await tester.pumpAndSettle();

      expect(find.text('de coach'), findsOneWidget);
      expect(
        container!.read(coachDraftProvider),
        startsWith(
          'Waarom kan Legs vandaag beter wachten? De check zegt: '
          'quadriceps nog 40 u',
        ),
      );
    });

    testWidgets('één sein: gewoon gaan, met een regel erbij', (tester) async {
      await pump(tester, estimates: [sore()]);

      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('Quadriceps nog 40 u'), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);
      expect(
        find.text('Volgende in je schema · 0 van 3 gedaan deze week'),
        findsOneWidget,
      );
    });

    testWidgets('klaar: één groene regel', (tester) async {
      await pump(tester, estimates: [rested()], nights: [night(goodNight)]);

      expect(
        find.text('Klaar: je spieren zijn hersteld, 7 u 40 geslapen'),
        findsOneWidget,
      );
      expect(find.text('Start workout'), findsOneWidget);
    });

    testWidgets('weet de check niets, dan zegt hij niets', (tester) async {
      await pump(tester);

      expect(find.text('Legs'), findsOneWidget);
      expect(find.textContaining('Klaar'), findsNothing);
      expect(find.text('Start workout'), findsOneWidget);
    });

    testWidgets('past op een smalle gsm met grote letters', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        estimates: [sore()],
        nights: [night(shortNight)],
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Legs kan beter wachten'), findsOneWidget);
      expect(find.byTooltip('Andere keuzes'), findsOneWidget);

      await tester.tap(find.byTooltip('Andere keuzes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Check voor Legs'), findsOneWidget);
    });

    testWidgets('en ook met één sein', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, estimates: [sore()], size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('Quadriceps nog 40 u'), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);
    });
  });

  testWidgets('onder Schema\'s: per sessie of ze vandaag klaar is, en Start '
      'bij de sessie die het meest klaar is', (tester) async {
    await pump(
      tester,
      estimates: [sore()],
      nights: [night(shortNight)],
      screen: const RoutinesScreen(),
    );
    await tester.tap(find.byTooltip("Schema's"));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    Finder row(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(ListTile));
    expect(
      find.descendant(of: row('Legs'), matching: find.text('beter wachten')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row('Push'),
        matching: find.widgetWithText(FilledButton, 'Start'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('Pull'), matching: find.text('let op')),
      findsOneWidget,
    );

    await tester.tap(find.text('beter wachten'));
    await tester.pumpAndSettle();
    expect(find.text('Check voor Legs'), findsOneWidget);
  });
}
