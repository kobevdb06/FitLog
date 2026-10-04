import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/features/chat/presentation/coach_screen.dart';
import 'package:fitlog/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:fitlog/features/progress/presentation/progress_screen.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:fitlog/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// An exercise that stopped going forward: where it shows, and the way from
/// there to the coach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;

  /// One session of [exerciseId]: three sets of five at [weight].
  Future<void> log(String exerciseId, DateTime at, double weight) async {
    final id = '$exerciseId-${at.millisecondsSinceEpoch}';
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: id,
            name: 'Training',
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(
              at.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$id',
            workoutId: id,
            exerciseId: exerciseId,
            sortOrder: 0,
          ),
        );
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.workoutSetsTable)
          .insert(
            WorkoutSetsTableCompanion.insert(
              id: 'ws-$id-$i',
              workoutExerciseId: 'we-$id',
              sortOrder: i,
              weightKg: Value(weight),
              reps: const Value(5),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    for (final (id, name, muscle) in [
      ('ex-bench', 'Bench Press', 'borst'),
      ('ex-squat', 'Back Squat', 'quadriceps'),
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

    final now = DateTime.now();
    DateTime weeksAgo(int w) => now.subtract(Duration(days: 7 * w, hours: 2));
    // Bench: tot zes weken geleden vooruit, sindsdien niets beter.
    for (final (w, weight) in [
      (8, 80.0),
      (7, 82.5),
      (6, 85.0),
      (5, 85.0),
      (4, 82.5),
      (3, 85.0),
      (2, 85.0),
      (1, 82.5),
      (0, 85.0),
    ]) {
      await log('ex-bench', weeksAgo(w), weight);
    }
    // Squat: elke week beter.
    for (var w = 8; w >= 0; w--) {
      await log(
        'ex-squat',
        weeksAgo(w).add(const Duration(days: 2)),
        100 + (8 - w) * 2.5,
      );
    }
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appControllerProvider.overrideWith(() => _Ready(db)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          routerConfig: container!.read(routerProvider),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('bovenaan Voortgang, en van daar naar de grafiek', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Voortgang').last);
    await tester.pumpAndSettle();

    final progress = find.byType(ProgressScreen);
    expect(
      find.descendant(of: progress, matching: find.text('STAAT STIL')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: progress,
        matching: find.text('6 weken geen vooruitgang · beste 99,25 kg'),
      ),
      findsOneWidget,
    );
    // Wat vooruitgaat, staat er niet.
    expect(
      find.descendant(of: progress, matching: find.text('Back Squat')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: progress, matching: find.text('Bench Press')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    expect(find.textContaining('Staat stil sinds'), findsOneWidget);
    expect(
      find.textContaining(
        'Je geschatte 1RM kwam in 6 weken niet boven 99,25 kg',
      ),
      findsOneWidget,
    );
    expect(find.text('Keer per week'), findsOneWidget);
    expect(find.text('Herhalingen'), findsOneWidget);
    expect(find.text('meestal 5'), findsOneWidget);
    expect(find.text('Sets voor borst per week'), findsOneWidget);
    expect(find.text('Nog niet hersteld'), findsOneWidget);
    // Zonder sleutel geen coach om iets te vragen.
    expect(find.text('Vraag de coach'), findsNothing);
  });

  testWidgets('een stil teken op de oefening zelf', (tester) async {
    await pumpApp(tester);
    container!.read(routerProvider).push(Routes.exerciseDetail('ex-bench'));
    await tester.pumpAndSettle();

    expect(find.text('Staat 6 weken stil'), findsOneWidget);
    expect(find.textContaining('Staat stil sinds'), findsNothing);

    await tester.tap(find.text('Staat 6 weken stil'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Staat stil sinds'), findsOneWidget);
  });

  testWidgets('en wat vooruitgaat, krijgt niets', (tester) async {
    await pumpApp(tester);
    container!.read(routerProvider).push(Routes.exerciseCharts('ex-squat'));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    expect(find.textContaining('Staat stil'), findsNothing);
  });

  testWidgets('de coach krijgt de vraag klaar, in een nieuw gesprek', (
    tester,
  ) async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    // Een eerder gesprek, dat de coach anders zou openen.
    await db.chatDao.createThread('t-old', 'Een oude vraag');
    await db.chatDao.addMessage(
      id: 'm-old',
      threadId: 't-old',
      role: 'user',
      content: 'Een oude vraag',
    );
    await pumpApp(tester);

    container!.read(routerProvider).push(Routes.exerciseCharts('ex-bench'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vraag de coach'));
    await tester.tap(find.text('Vraag de coach'));
    await tester.pumpAndSettle();

    expect(find.byType(CoachScreen), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(CoachScreen),
        matching: find.byType(TextField),
      ),
    );
    expect(
      field.controller!.text,
      'Mijn Bench Press staat al 6 weken stil. Wat zou je anders doen?',
    );
    expect(find.text('Een oude vraag'), findsNothing);
    // Klaargezet, niet verstuurd: dat kost geld, dus dat doe je zelf.
    final messages = await tester.runAsync(
      () => db
          .customSelect('SELECT COUNT(*) AS n FROM chat_messages')
          .getSingle(),
    );
    expect(messages!.read<int>('n'), 1);
  });
}

/// An app that is open and unlocked, so the shell is what the router shows.
class _Ready extends AppController {
  _Ready(this._db);

  final AppDatabase _db;

  @override
  AppState build() => AppReady(
    db: _db,
    security: const SecurityStatus(
      initialised: true,
      mode: LockMode.none,
      biometricEnabled: false,
      hasRecoveryPhrase: false,
      consecutiveFailures: 0,
      lastFailureAt: null,
    ),
  );
}
