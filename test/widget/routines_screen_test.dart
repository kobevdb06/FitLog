import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/features/routines/presentation/routines_screen.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The Trainen tab.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name, muscle) in [
      ('ex-bench', 'Bench Press', 'borst'),
      ('ex-fly', 'Cable Fly', 'borst'),
      ('ex-dip', 'Dips', 'triceps'),
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
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  RoutineExerciseDraft exercise(String id, int sets) => RoutineExerciseDraft(
    exerciseId: id,
    sets: [for (var i = 0; i < sets; i++) const RoutineSetDraft(targetReps: 8)],
  );

  Future<String> routine(String name, List<RoutineExerciseDraft> exercises) =>
      db.routinesDao.createRoutine(
        RoutineDraft(name: name, exercises: exercises),
      );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const RoutinesScreen()),
    );
    await tester.pumpAndSettle();
  }

  /// The tab with somewhere to go: starting a routine opens the session.
  Future<void> pumpRouted(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const RoutinesScreen()),
        GoRoute(
          path: '/workout',
          builder: (context, state) => const Scaffold(body: Text('Sessie')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          locale: const Locale('nl'),
          supportedLocales: const [Locale('nl')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<WorkoutRow?> running(WidgetTester tester) =>
      tester.runAsync<WorkoutRow?>(db.workoutsDao.getActiveWorkoutRow);

  testWidgets('één oefening en één set, in het enkelvoud', (tester) async {
    await tester.runAsync(() => routine('Kort', [exercise('ex-bench', 1)]));
    await pump(tester);

    expect(find.textContaining('1 oefening ·'), findsOneWidget);
    expect(find.textContaining('1 oefeningen'), findsNothing);
  });

  testWidgets('een kaart zegt wat ze traint en hoe lang ze duurt', (
    tester,
  ) async {
    await tester.runAsync(
      () => routine('Push', [
        exercise('ex-dip', 2),
        exercise('ex-bench', 3),
        exercise('ex-fly', 3),
      ]),
    );
    await pump(tester);

    // Six sets of chest before two of triceps, whatever the order in it.
    expect(find.text('Borst · Triceps'), findsOneWidget);
    // 8 sets of 40 s, 7 rests of 90 s, two changes of a minute: nearly 18, so 20.
    expect(find.textContaining('3 oefeningen · ±20 min'), findsOneWidget);
    // The sets stay on the routine page.
    expect(find.textContaining('8 sets'), findsNothing);
  });

  testWidgets('the play button starts the routine without opening it', (
    tester,
  ) async {
    await tester.runAsync(() => routine('Push', [exercise('ex-bench', 3)]));
    await pumpRouted(tester);

    await tester.tap(find.byTooltip('Push starten'));
    await tester.pumpAndSettle();

    expect(find.text('Sessie'), findsOneWidget);
    final row = await running(tester);
    expect(row?.name, 'Push');
  });

  testWidgets('with a session running, play offers that one instead', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await routine('Push', [exercise('ex-bench', 3)]);
      await container
          .read(workoutControllerProvider)
          .startEmpty(name: 'Al bezig');
    });
    await pumpRouted(tester);

    await tester.tap(find.byTooltip('Push starten'));
    await tester.pumpAndSettle();
    expect(find.text('Er loopt al een workout'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ga verder'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sessie'), findsOneWidget);
    final row = await running(tester);
    expect(row?.name, 'Al bezig');
  });

  testWidgets('an empty routine has nothing to start', (tester) async {
    await tester.runAsync(() => routine('Leeg', const []));
    await pump(tester);

    final play = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.play_arrow),
        matching: find.byType(IconButton),
      ),
    );
    expect(play.onPressed, isNull);
  });

  testWidgets('fits a phone with large text', (tester) async {
    await tester.runAsync(() async {
      final id = await routine(
        'Een heel lange naam voor een routine met veel oefeningen',
        [exercise('ex-bench', 4), exercise('ex-fly', 4), exercise('ex-dip', 4)],
      );
      // Planned today too, so the card at the top is measured as well.
      await db.routinesDao.setScheduledDays(
        id,
        WeekdaySet.of([1, 2, 3, 4, 5, 6, 7]),
      );
    });
    tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      wrapWithContainer(container, const RoutinesScreen()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byTooltip(
        'Een heel lange naam voor een routine met veel oefeningen starten',
      ),
      findsOneWidget,
    );
  });

  group('bovenaan', () {
    testWidgets('wat vandaag gepland staat, met een knop om te beginnen', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final push = await routine('Push', [
          exercise('ex-bench', 3),
          exercise('ex-dip', 2),
        ]);
        final pull = await routine('Pull', [exercise('ex-fly', 3)]);
        // Every day, so today is one of them whatever day the test runs.
        for (final id in [push, pull]) {
          await db.routinesDao.setScheduledDays(
            id,
            WeekdaySet.of([1, 2, 3, 4, 5, 6, 7]),
          );
        }
      });
      await pumpRouted(tester);

      expect(find.text('VANDAAG GEPLAND'), findsOneWidget);
      expect(find.text('Borst · Triceps · ±10 min'), findsOneWidget);
      expect(find.text('Ook gepland: Pull'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      expect(find.text('Sessie'), findsOneWidget);
      expect((await running(tester))?.name, 'Push');
    });

    testWidgets('niets gepland, dan geen kaart', (tester) async {
      await tester.runAsync(() => routine('Push', [exercise('ex-bench', 3)]));
      await pump(tester);

      expect(find.text('VANDAAG GEPLAND'), findsNothing);
      expect(find.text('Lege training'), findsOneWidget);
      expect(find.text('Oefeningen'), findsOneWidget);
    });

    testWidgets('een lopende workout gaat voor op het plan', (tester) async {
      await tester.runAsync(() async {
        final push = await routine('Push', [exercise('ex-bench', 3)]);
        await db.routinesDao.setScheduledDays(
          push,
          WeekdaySet.of([1, 2, 3, 4, 5, 6, 7]),
        );
        await container
            .read(workoutControllerProvider)
            .startEmpty(name: 'Al bezig');
      });
      await pumpRouted(tester);

      expect(find.text('VANDAAG GEPLAND'), findsNothing);
      expect(find.text('WORKOUT LOOPT'), findsOneWidget);
      expect(find.text('Al bezig'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Ga verder'));
      await tester.pumpAndSettle();
      expect(find.text('Sessie'), findsOneWidget);
    });

    testWidgets('lege training begint een workout zonder routine', (
      tester,
    ) async {
      await tester.runAsync(() => routine('Push', [exercise('ex-bench', 3)]));
      await pumpRouted(tester);

      await tester.tap(find.text('Lege training'));
      await tester.pumpAndSettle();

      expect(find.text('Sessie'), findsOneWidget);
      final row = await running(tester);
      expect(row, isNotNull);
      expect(row!.routineId, isNull);
    });

    testWidgets('een map maken en scannen staan onder het menu', (
      tester,
    ) async {
      await tester.runAsync(() => routine('Push', [exercise('ex-bench', 3)]));
      await pump(tester);

      expect(find.text('Nieuwe map'), findsNothing);
      await tester.tap(find.byTooltip('Meer'));
      await tester.pumpAndSettle();
      expect(find.text('Nieuwe map'), findsOneWidget);
      expect(find.text('Routine scannen'), findsOneWidget);
    });
  });

  group('zoeken', () {
    Future<void> search(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    setUp(() async {
      final jan = await db.routinesDao.createFolder('Met Jan');
      await db.routinesDao.createRoutine(
        RoutineDraft(
          name: 'Push',
          folderId: jan,
          exercises: [exercise('ex-bench', 3)],
        ),
      );
      await db.routinesDao.createRoutine(
        RoutineDraft(name: 'Armen', exercises: [exercise('ex-dip', 3)]),
      );
      await db.routinesDao.createRoutine(
        RoutineDraft(name: 'Push zwaar', exercises: [exercise('ex-fly', 3)]),
      );
    });

    testWidgets('op naam, zonder op hoofdletters te letten', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Routine zoeken'));
      await tester.pumpAndSettle();
      // While searching, the top of the tab makes room for the field.
      expect(find.text('Lege training'), findsNothing);

      await search(tester, 'push');

      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Push zwaar'), findsOneWidget);
      expect(find.text('Armen'), findsNothing);
      // The folder it is in stays above it, so two of the same name are
      // still told apart.
      expect(find.text('MET JAN'), findsOneWidget);
    });

    testWidgets('op de naam van de map: alles wat erin zit', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Routine zoeken'));
      await tester.pumpAndSettle();

      await search(tester, 'jan');

      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Push zwaar'), findsNothing);
      expect(find.text('Armen'), findsNothing);
    });

    testWidgets('op spiergroep', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Routine zoeken'));
      await tester.pumpAndSettle();

      await search(tester, 'triceps');

      expect(find.text('Armen'), findsOneWidget);
      expect(find.text('Push'), findsNothing);
      // A folder with nothing that matches is not in the way.
      expect(find.text('MET JAN'), findsNothing);
    });

    testWidgets('niets gevonden, en sluiten zet alles terug', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Routine zoeken'));
      await tester.pumpAndSettle();

      await search(tester, 'benen');
      expect(find.text('Geen routine gevonden voor "benen".'), findsOneWidget);

      await tester.tap(find.byTooltip('Zoeken sluiten'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Armen'), findsOneWidget);
      expect(find.text('Lege training'), findsOneWidget);
    });
  });

  group('mappen', () {
    late String jan;

    setUp(() async {
      jan = await db.routinesDao.createFolder('Met Jan');
      for (final name in ['Push', 'Pull']) {
        await db.routinesDao.createRoutine(
          RoutineDraft(
            name: name,
            folderId: jan,
            exercises: [exercise('ex-bench', 3)],
          ),
        );
      }
    });

    Future<RoutineFolderRow> folder(WidgetTester tester) async =>
        (await tester.runAsync(db.routinesDao.getFolders))!.single;

    testWidgets('een map zegt hoeveel erin zit', (tester) async {
      await pump(tester);

      expect(find.text('MET JAN'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    });

    testWidgets('dichtklappen, en dat blijft zo', (tester) async {
      await pump(tester);
      expect(find.text('Push'), findsOneWidget);

      await tester.tap(find.text('MET JAN'));
      await tester.pumpAndSettle();

      expect(find.text('Push'), findsNothing);
      expect(find.text('Pull'), findsNothing);
      // Folded shut, the count is what is left to see.
      expect(find.text('2'), findsOneWidget);
      expect((await folder(tester)).isCollapsed, isTrue);

      // Back on the tab later, still shut.
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.text('Push'), findsNothing);

      await tester.tap(find.text('MET JAN'));
      await tester.pumpAndSettle();
      expect(find.text('Push'), findsOneWidget);
      expect((await folder(tester)).isCollapsed, isFalse);
    });

    testWidgets('zoeken kijkt ook in een dichte map', (tester) async {
      await tester.runAsync(() => db.routinesDao.setFolderCollapsed(jan, true));
      await pump(tester);
      expect(find.text('Pull'), findsNothing);

      await tester.tap(find.byTooltip('Routine zoeken'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pull');
      await tester.pumpAndSettle();

      expect(find.text('Pull'), findsOneWidget);
      expect(find.text('Push'), findsNothing);
      // Finding something does not open the folder for good.
      expect((await folder(tester)).isCollapsed, isTrue);
    });
  });
}
