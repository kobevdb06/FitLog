import 'dart:async';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/routines/presentation/routine_start.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// A start that takes a while: lighter, a session is made lighter in the
/// database before it opens.
class _SlowStart extends WorkoutController {
  _SlowStart(super.ref);

  final gate = Completer<void>();

  @override
  Future<String> startFromRoutine(
    String routineId, {
    bool lighter = false,
  }) async {
    await gate.future;
    return 'w';
  }
}

/// Starting a session steps into it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() => db.close());

  testWidgets('ook als wat de start vroeg intussen weg is', (tester) async {
    late _SlowStart controller;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        workoutControllerProvider.overrideWith(
          (ref) => controller = _SlowStart(ref),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Vandaag: a card with a start on it, which a running session replaces.
    final shown = ValueNotifier(true);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ValueListenableBuilder(
            valueListenable: shown,
            builder: (context, card, _) => card
                ? Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () =>
                          startSession(context, ref, routineId: 'r'),
                      child: const Text('Start'),
                    ),
                  )
                : const Text('Je workout loopt'),
          ),
        ),
        GoRoute(
          path: Routes.workout,
          builder: (context, state) => const Text('de workout'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Start'));
    await tester.pump();
    // The session is there before the start is done, and the card that
    // asked for it is gone.
    shown.value = false;
    await tester.pump();
    controller.gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('de workout'), findsOneWidget);
  });
}
