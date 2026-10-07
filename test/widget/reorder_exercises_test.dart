import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/widgets/reorderable_cards.dart';
import 'package:fitlog/features/routines/presentation/routine_editor_screen.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:fitlog/features/workout/presentation/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Putting exercises in another order by their handle, in a running session
/// and in the routine editor: the same handle, the same lifted card, and an
/// exercise that stays where you put it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  const exercises = [
    ('ex-squat', 'Barbell Squat', 'quadriceps'),
    ('ex-bench', 'Barbell Bench Press', 'borst'),
    ('ex-row', 'Barbell Row', 'bovenrug'),
  ];

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name, muscle) in exercises) {
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

  /// The handle, whichever icon a screen gives it.
  final handles = find.byWidgetPredicate(
    (w) =>
        w is Icon &&
        (w.icon == Icons.drag_indicator || w.icon == Icons.drag_handle),
  );

  /// A phone: tall cards of six sets do not fit on it.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The names top to bottom, as they stand on screen.
  List<String> onScreen(WidgetTester tester) {
    final names = [for (final (_, name, _) in exercises) name];
    final shown = [
      for (final name in names)
        if (find.text(name).evaluate().isNotEmpty) name,
    ];
    shown.sort(
      (a, b) => tester
          .getTopLeft(find.text(a).first)
          .dy
          .compareTo(tester.getTopLeft(find.text(b).first).dy),
    );
    return shown;
  }

  /// Picks the exercise up by its handle, moves it a little - past the
  /// slop, not past anything - and holds it there before letting go.
  Future<void> pickUpAndHold(WidgetTester tester, Finder handle) async {
    final drag = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();
  }

  /// Picks up the first exercise and carries it down past the second.
  Future<void> carryFirstDown(WidgetTester tester) async {
    final drag = await tester.startGesture(tester.getCenter(handles.first));
    // Picked up: past the slop, and a few frames for the cards to fold.
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Then a little over one folded row, the way a finger moves: in small
    // steps. Open, a card of ten sets is several times that.
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();
  }

  /// Holds the first exercise up and hands back what [look] saw meanwhile.
  Future<T> whileHolding<T>(WidgetTester tester, T Function() look) async {
    final drag = await tester.startGesture(tester.getCenter(handles.first));
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    final seen = look();
    await drag.up();
    await tester.pumpAndSettle();
    return seen;
  }

  void sameHandle() {
    // Only the cards on screen are built; each has the same handle.
    expect(find.byIcon(Icons.drag_indicator), findsWidgets);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(
      find.byIcon(Icons.drag_indicator).evaluate().length,
      find.byType(ReorderHandle).evaluate().length,
    );
  }

  /// The card you hold is the card, lifted - not a strip the width of the
  /// screen with the card in it.
  void notABar(String held) {
    expect(
      find.ancestor(
        of: find.text(held),
        matching: find.byWidgetPredicate(
          (w) => w is Material && w.elevation > 0,
        ),
      ),
      findsNothing,
    );
  }

  group('in een lopende workout', () {
    late String workoutId;

    setUp(() async {
      final controller = container.read(workoutControllerProvider);
      workoutId = await controller.startEmpty(name: 'Push A');
      await controller.addExercises(workoutId, [
        for (final (id, _, _) in exercises) id,
      ]);
      final detail = (await db.workoutsDao.getWorkoutDetail(workoutId))!;
      for (final exercise in detail.exercises) {
        for (var i = 0; i < 9; i++) {
          await db.workoutsDao.addSet(exercise.workoutExercise.id);
        }
      }
    });

    Future<List<String>> order() async =>
        (await db.workoutsDao.getWorkoutDetail(workoutId))!.exercises
            .map((e) => e.exercise.id)
            .toList();

    Future<void> pump(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(
        wrapWithContainer(container, const ActiveWorkoutScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('oppakken en stilhouden laat de oefening op haar plaats', (
      tester,
    ) async {
      await pump(tester);

      await pickUpAndHold(tester, handles.first);

      // It ran to the bottom: the card sticks out under the screen, and the
      // list scrolled after it for as long as it did.
      expect(await tester.runAsync(order), ['ex-squat', 'ex-bench', 'ex-row']);
    });

    testWidgets('slepen zet ze achter de volgende, en ze blijft in beeld', (
      tester,
    ) async {
      await pump(tester);

      await carryFirstDown(tester);

      expect(await tester.runAsync(order), ['ex-bench', 'ex-squat', 'ex-row']);
      final squat = tester.getRect(find.text('Barbell Squat').first);
      expect(squat.top, greaterThan(0));
      expect(squat.bottom, lessThan(740));
    });

    testWidgets('tijdens het slepen staat alles ingeklapt, als kaart', (
      tester,
    ) async {
      await pump(tester);

      final folded = await whileHolding(tester, () {
        notABar('Barbell Squat');
        return find.text('10 sets').evaluate().length;
      });

      expect(folded, 3);
      // And open again once it is down.
      expect(find.text('10 sets'), findsNothing);
    });

    testWidgets('dezelfde greep als in de editor', (tester) async {
      await pump(tester);
      sameHandle();
    });
  });

  group('in de routine-editor', () {
    late String routineId;

    setUp(() async {
      routineId = await db.routinesDao.createRoutine(
        RoutineDraft(
          name: 'Push A',
          exercises: [
            for (final (id, _, _) in exercises)
              RoutineExerciseDraft(
                exerciseId: id,
                sets: [
                  for (var i = 0; i < 10; i++)
                    const RoutineSetDraft(targetReps: 8, targetWeightKg: 60),
                ],
              ),
          ],
        ),
      );
    });

    Future<void> pump(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(
        wrapWithContainer(container, RoutineEditorScreen(routineId: routineId)),
      );
      await tester.pumpAndSettle();
      // The name and the notes come first; bring the first exercise up.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
      await tester.pumpAndSettle();
    }

    testWidgets('oppakken en stilhouden laat de oefening op haar plaats', (
      tester,
    ) async {
      await pump(tester);

      await pickUpAndHold(tester, handles.first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();

      expect(onScreen(tester).first, 'Barbell Squat');
      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(
        () => db.routinesDao.getRoutineDetail(routineId),
      );
      expect(saved!.exercises.map((e) => e.exercise.id), [
        'ex-squat',
        'ex-bench',
        'ex-row',
      ]);
    });

    testWidgets('slepen zet ze achter de volgende', (tester) async {
      await pump(tester);

      await carryFirstDown(tester);
      final squat = tester.getRect(find.text('Barbell Squat').first);
      expect(squat.top, greaterThan(0));
      expect(squat.bottom, lessThan(740));

      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(
        () => db.routinesDao.getRoutineDetail(routineId),
      );
      expect(saved!.exercises.map((e) => e.exercise.id), [
        'ex-bench',
        'ex-squat',
        'ex-row',
      ]);
      // The sets went with it.
      expect(saved.exercises[1].sets, hasLength(10));
    });

    testWidgets('de opgepakte oefening blijft een kaart, geen balk', (
      tester,
    ) async {
      await pump(tester);

      final folded = await whileHolding(tester, () {
        notABar('Barbell Squat');
        return find.text('10 sets').evaluate().length;
      });

      expect(folded, 3);
    });

    testWidgets('dezelfde greep als in een workout', (tester) async {
      await pump(tester);
      sameHandle();
    });
  });
}
