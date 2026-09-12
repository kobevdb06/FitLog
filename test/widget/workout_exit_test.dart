import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// Leaving a running session.
///
/// Finishing or throwing one away empties the provider before the screen has
/// left. Without care the screen swaps to its "no session" state first and
/// slides *that* away - a flash of the wrong thing exactly where the eye is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  late String workoutId;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
    addTearDown(container.dispose);

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Bankdrukken',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: 0,
          ),
        );

    workoutId = await db.workoutsDao.startWorkout(
      name: 'Push',
      defaultRestSeconds: 90,
    );
    await db.workoutsDao.addExercises(
      workoutId,
      ['ex-bench'],
      defaultRestSeconds: 90,
    );
    final set = (await db.workoutsDao.getWorkoutDetail(
      workoutId,
    ))!.exercises.single.sets.single;
    await db.workoutsDao.updateSet(
      set.id,
      weightKg: const Value(100),
      reps: const Value(5),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// The screen on a route of its own, so leaving it has somewhere to go.
  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/thuis',
      routes: [
        GoRoute(
          path: '/thuis',
          builder: (context, state) => const Scaffold(body: Text('Thuis')),
        ),
        GoRoute(
          path: '/workout',
          // A page that takes time to leave, the way the real one does. The
          // window it leaves open is the whole point: the session ends while
          // the screen is still on its way out.
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            child: const ActiveWorkoutScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondary, child) =>
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
          ),
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
    // Pushed on top of something, the way it is in the app: leaving it has to
    // have somewhere to go back to.
    router.push('/workout');
    await tester.pumpAndSettle();
  }

  testWidgets('throwing one away does not flash the empty state first', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Bankdrukken'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout weggooien'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weggooien').last);

    // Frame by frame through the delete and the start of the exit: the
    // session has to stay on screen the whole way.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.text('Geen lopende workout'),
        findsNothing,
        reason: 'frame $i',
      );
    }

    await tester.pumpAndSettle();
    expect(await db.workoutsDao.getActiveWorkoutRow(), isNull);
  });

  testWidgets('the session really is gone once the screen has left', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout weggooien'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weggooien').last);
    await tester.pumpAndSettle();

    expect(
      await db.workoutsDao.getWorkoutDetail(workoutId),
      isNull,
      reason: 'weggooien gooit hem echt weg',
    );
  });
}
