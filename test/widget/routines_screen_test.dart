import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/routines/presentation/routines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const RoutinesScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('één oefening en één set, in het enkelvoud', (tester) async {
    await tester.runAsync(
      () => db.routinesDao.createRoutine(
        RoutineDraft(name: 'Kort', exercises: [exercise('ex-bench', 1)]),
      ),
    );
    await pump(tester);

    expect(find.textContaining('1 oefening '), findsOneWidget);
    expect(find.textContaining('1 oefeningen'), findsNothing);
    expect(find.textContaining('1 sets'), findsNothing);
  });
}
