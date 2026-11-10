import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:fitlog/routing/open_workout.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The session opened from outside the app: the home-screen shortcut, the
/// notification, the panel (DECISIONS 246).
///
/// Those opened it with `go`, which replaces everything: no page lay under
/// the session. "Verbergen" threw, and "Workout weggooien" stopped on the
/// same throw before the session was thrown away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late String workoutId;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    workoutId = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
  });

  tearDown(() => db.close());

  /// A few frames: the session's clock ticks every second, so it never
  /// settles.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The tree taken down, and the moment drift needs to let its queries go.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// The session alone on the stack, as `go` left it.
  Future<GoRouter> pumpAlone(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: Routes.workout,
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (context, state) => const Scaffold(body: Text('Start')),
        ),
        GoRoute(
          path: Routes.workout,
          builder: (context, state) => const ActiveWorkoutScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return router;
  }

  testWidgets('Verbergen goes to Start', (tester) async {
    await pumpAlone(tester);

    await tester.tap(find.byTooltip('Verbergen'));
    await frames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Start'), findsOneWidget);
    await done(tester);
  });

  testWidgets('Workout weggooien throws it away, and goes to Start', (
    tester,
  ) async {
    await pumpAlone(tester);

    await tester.tap(find.byTooltip('Menu tonen').first);
    await frames(tester);
    await tester.tap(find.text('Workout weggooien'));
    await frames(tester);
    await tester.tap(find.text('Weggooien'));
    await frames(tester);

    expect(tester.takeException(), isNull);
    expect(
      await tester.runAsync(() => db.workoutsDao.getWorkoutDetail(workoutId)),
      isNull,
    );
    expect(find.text('Start'), findsOneWidget);
    await done(tester);
  });

  testWidgets('opening it from outside leaves Start underneath', (
    tester,
  ) async {
    final router = GoRouter(
      // Somewhere else in the app, the session alone on top as `go` left it.
      initialLocation: Routes.workout,
      routes: [
        GoRoute(path: Routes.dashboard, builder: (_, _) => const SizedBox()),
        GoRoute(path: Routes.workout, builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    openWorkoutFromOutside(router);
    await tester.pumpAndSettle();

    final shown = router.routerDelegate.currentConfiguration;
    expect(shown.matches.first.matchedLocation, Routes.dashboard);
    expect(shown.last.matchedLocation, Routes.workout);
    expect(router.canPop(), isTrue);
  });
}
