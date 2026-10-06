import 'package:fitlog/core/app/app_controller.dart';
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

    await tester.tap(find.text('Ga verder'));
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
    await tester.runAsync(
      () => routine(
        'Een heel lange naam voor een routine met veel oefeningen',
        [exercise('ex-bench', 4), exercise('ex-fly', 4), exercise('ex-dip', 4)],
      ),
    );
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
}
