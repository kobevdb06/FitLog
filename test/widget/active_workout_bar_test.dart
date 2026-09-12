import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:fitlog/routing/app_shell.dart';
import 'package:fitlog/routing/pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The blue bar that says a session is running.
///
/// Starting one pushes its own screen up over the shell, and the bar used to
/// appear underneath at that very moment: you saw it flash into the strip the
/// rising page had not covered yet. Ending one has to be the other way round.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late WorkoutController controller;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    controller = container.read(workoutControllerProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// The shell on its own, with a throwaway branch, so the bar can be watched
  /// without the whole app around it.
  Future<void> pumpShell(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/een',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            for (final path in ['/een', '/twee', '/drie', '/vier'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  final bar = find.text('Losse workout');

  testWidgets('no session, no bar', (tester) async {
    await pumpShell(tester);
    expect(bar, findsNothing);
  });

  testWidgets('starting one does not show it straight away', (tester) async {
    await pumpShell(tester);

    await controller.startEmpty(name: 'Losse workout');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The session's own screen is still on its way up; the bar must not be
    // seen arriving in the strip it has not covered yet.
    expect(bar, findsNothing);
  });

  testWidgets('it is there once that screen is up', (tester) async {
    await pumpShell(tester);

    await controller.startEmpty(name: 'Losse workout');
    await tester.pump();
    await tester.pump(kSheetRise + const Duration(milliseconds: 50));

    expect(bar, findsOneWidget);
  });

  testWidgets('ending one takes it away at once', (tester) async {
    await pumpShell(tester);
    final id = await controller.startEmpty(name: 'Losse workout');
    await tester.pump();
    await tester.pump(kSheetRise + const Duration(milliseconds: 50));
    expect(bar, findsOneWidget);

    await controller.cancel(id);
    await tester.pump();

    // Gone before the page sinks away, so what it uncovers is already right.
    expect(bar, findsNothing);
  });

  testWidgets('a session thrown away during the wait never shows a bar', (
    tester,
  ) async {
    await pumpShell(tester);

    final id = await controller.startEmpty(name: 'Losse workout');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await controller.cancel(id);
    await tester.pump();

    // Long past when the arrival would have fired.
    await tester.pump(kSheetRise * 2);
    expect(bar, findsNothing);
  });

  testWidgets('opening on a session already running shows it at once', (
    tester,
  ) async {
    await controller.startEmpty(name: 'Losse workout');

    await pumpShell(tester);

    // Nothing to hide behind here: you did not just start it.
    expect(bar, findsOneWidget);
  });
}
