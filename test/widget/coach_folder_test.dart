import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/routines/presentation/routine_detail_screen.dart';
import 'package:fitlog/features/routines/presentation/routine_editor_screen.dart';
import 'package:fitlog/features/routines/presentation/routines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The folder the coach may change routines in: only there with a key, and
/// nothing of yours goes in without you saying you know what that means.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
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
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  RoutineDraft push({String? folderId, int reps = 8}) => RoutineDraft(
    name: 'Push',
    folderId: folderId,
    exercises: [
      RoutineExerciseDraft(
        exerciseId: 'ex-bench',
        sets: [
          for (var i = 0; i < 3; i++)
            RoutineSetDraft(targetReps: reps, targetWeightKg: 80),
        ],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithContainer(container, screen));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  group('in Trainen', () {
    setUp(() async {
      final folder = await db.routinesDao.ensureCoachFolder();
      await db.routinesDao.createRoutine(push(folderId: folder));
    });

    testWidgets('zonder sleutel geen map van de coach', (tester) async {
      await pump(tester, const RoutinesScreen());

      expect(find.text('COACH'), findsNothing);
      expect(find.text('Push'), findsNothing);
    });

    testWidgets('met een sleutel wel, en wat ze betekent', (tester) async {
      await tester.runAsync(() => db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg'));
      await pump(tester, const RoutinesScreen());

      expect(find.text('COACH'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      // The coach's face on the folder, and what it means under its menu.
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      await tester.tap(find.byTooltip('Map bewerken'));
      await tester.pumpAndSettle();
      expect(find.text('De map van de coach'), findsOneWidget);
      expect(
        find.textContaining('De coach mag de routines in deze map aanpassen.'),
        findsOneWidget,
      );
    });
  });

  group('een routine aan de coach geven', () {
    late String routineId;

    setUp(() async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      routineId = await db.routinesDao.createRoutine(push());
    });

    Future<void> chooseCoach(WidgetTester tester) async {
      await pump(tester, RoutineDetailScreen(routineId: routineId));
      await openMenu(tester, 'Verplaatsen naar map');
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();
    }

    FilledButton handOver(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'In de map Coach zetten'),
    );

    testWidgets('pas na het vinkje', (tester) async {
      await chooseCoach(tester);

      expect(find.text('Routine aan de coach geven?'), findsOneWidget);
      expect(handOver(tester).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(handOver(tester).onPressed, isNotNull);

      await tester.tap(find.text('In de map Coach zetten'));
      await tester.pumpAndSettle();

      final folder = (await tester.runAsync(db.routinesDao.coachFolder))!;
      final routine = (await tester.runAsync(
        () => db.routinesDao.getRoutine(routineId),
      ))!;
      expect(routine.folderId, folder.id);
      expect(
        find.textContaining('Deze routine staat in de map Coach'),
        findsOneWidget,
      );
    });

    testWidgets('en annuleren laat ze waar ze was', (tester) async {
      await chooseCoach(tester);

      await tester.tap(find.text('Annuleren'));
      await tester.pumpAndSettle();

      final routine = (await tester.runAsync(
        () => db.routinesDao.getRoutine(routineId),
      ))!;
      expect(routine.folderId, isNull);
      expect(await tester.runAsync(db.routinesDao.coachFolder), isNull);
    });

    testWidgets('zonder sleutel staat de coach niet in de keuze', (
      tester,
    ) async {
      await tester.runAsync(() => db.settingsDao.setApiKey(null));
      await tester.runAsync(() => db.routinesDao.createFolder('Benen'));
      await pump(tester, RoutineDetailScreen(routineId: routineId));
      await openMenu(tester, 'Verplaatsen naar map');

      expect(find.text('Benen'), findsOneWidget);
      expect(find.text('Coach'), findsNothing);
    });

    testWidgets('ook in de editor vraagt het eerst', (tester) async {
      await tester.runAsync(db.routinesDao.ensureCoachFolder);
      await pump(tester, RoutineEditorScreen(routineId: routineId));

      await tester.tap(find.text('Geen map'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coach'));
      await tester.pumpAndSettle();

      expect(find.text('Routine aan de coach geven?'), findsOneWidget);
      await tester.tap(find.text('Annuleren'));
      await tester.pumpAndSettle();
      // Niets gekozen: nog altijd geen map.
      expect(find.text('Geen map'), findsOneWidget);
    });
  });

  testWidgets('een vorige versie zet je terug via het menu', (tester) async {
    final id = await tester.runAsync(() async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      final folder = await db.routinesDao.ensureCoachFolder();
      final id = await db.routinesDao.createRoutine(push(folderId: folder));
      await db.routinesDao.keepVersion(id, 'Voor: meer herhalingen');
      await db.routinesDao.updateRoutine(id, push(folderId: folder, reps: 15));
      return id;
    });
    await pump(tester, RoutineDetailScreen(routineId: id!));

    await openMenu(tester, 'Vorige versies');
    expect(find.text('Voor: meer herhalingen'), findsOneWidget);
    await tester.tap(find.text('Voor: meer herhalingen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terugzetten'));
    await tester.pumpAndSettle();

    final detail = (await tester.runAsync(
      () => db.routinesDao.getRoutineDetail(id),
    ))!;
    expect(detail.exercises.single.sets.first.targetReps, 8);
    expect(find.text('Vorige versie teruggezet'), findsOneWidget);
  });
}
