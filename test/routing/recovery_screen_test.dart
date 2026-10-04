import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/health/presentation/health_overview_screen.dart';
import 'package:fitlog/features/health/presentation/heart_rate_week_screen.dart';
import 'package:fitlog/features/health/presentation/steps_week_screen.dart';
import 'package:fitlog/features/morning/presentation/morning_providers.dart';
import 'package:fitlog/features/morning/presentation/report_week_screen.dart';
import 'package:fitlog/features/progress/presentation/sleep_section.dart';
import 'package:fitlog/features/progress/presentation/sleep_week_screen.dart';
import 'package:fitlog/features/progress/presentation/progress_screen.dart';
import 'package:fitlog/features/progress/presentation/recovery_screen.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:fitlog/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Herstel: the screen, the two ways into it, and the three answers on it.
///
/// Through the app's real router, because the screen is opened from two
/// different tabs - and a route pushed from a branch it does not belong to is
/// exactly how this app once showed an empty white page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  /// One finished session of squats, a few hours ago.
  Future<void> trainedLegs() async {
    final at = DateTime.now().subtract(const Duration(hours: 3));
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-squat',
            name: 'Barbell Squat',
            primaryMuscle: 'quadriceps',
            category: 'barbell',
            createdAt: 0,
          ),
        );
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-legs',
            name: 'Benen',
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
            id: 'we-squat',
            workoutId: 'w-legs',
            exerciseId: 'ex-squat',
            sortOrder: 0,
          ),
        );
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.workoutSetsTable)
          .insert(
            WorkoutSetsTableCompanion.insert(
              id: 's$i',
              workoutExerciseId: 'we-squat',
              sortOrder: i,
              weightKg: const Value(100),
              reps: const Value(5),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1100, 2400),
  }) async {
    tester.view.physicalSize = size;
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

  group('de weg erheen', () {
    testWidgets('vanuit Voortgang', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Voortgang').last);
      await tester.pumpAndSettle();

      final entry = find.descendant(
        of: find.byType(ProgressScreen),
        matching: find.text('Herstel'),
      );
      await tester.scrollUntilVisible(
        entry,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ProgressScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryScreen), findsOneWidget);
    });

    testWidgets('en Gezondheid staat ernaast, in plaats van de grafiek', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Voortgang').last);
      await tester.pumpAndSettle();

      final entry = find.descendant(
        of: find.byType(ProgressScreen),
        matching: find.text('Gezondheid'),
      );
      await tester.scrollUntilVisible(
        entry,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ProgressScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Grafiek per oefening'), findsNothing);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(HealthOverviewScreen), findsOneWidget);
    });

    testWidgets('en vanuit Gezondheid naar de nachten en de trainingen', (
      tester,
    ) async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      final today = DateTime.now();
      await db.recoveryDao.setSleep(
        fellAsleepAt: DateTime(today.year, today.month, today.day - 1, 23),
        wokeAt: DateTime(today.year, today.month, today.day, 7),
      );
      await pumpApp(tester);
      container!.read(routerProvider).push(Routes.health);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alle nachten'));
      await tester.pumpAndSettle();
      expect(find.byType(SleepWeekScreen), findsOneWidget);

      container!.read(routerProvider).pop();
      await tester.pumpAndSettle();
      final earlier = find.text('Eerdere trainingen');
      await tester.scrollUntilVisible(
        earlier,
        200,
        scrollable: find
            .descendant(
              of: find.byType(HealthOverviewScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(earlier);
      await tester.pumpAndSettle();
      expect(find.byType(HeartRateWeekScreen), findsOneWidget);
    });

    testWidgets('stappen staan op het startscherm, en openen per week', (
      tester,
    ) async {
      final now = DateTime.now();
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
      );
      await db.healthDao.setSteps(DateTime(now.year, now.month, now.day), 8432);
      await pumpApp(tester);

      final block = find.text('STAPPEN');
      await tester.scrollUntilVisible(
        block,
        200,
        scrollable: find
            .descendant(
              of: find.byType(DashboardScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('8.432'), findsOneWidget);

      await tester.tap(block);
      await tester.pumpAndSettle();
      expect(find.byType(StepsWeekScreen), findsOneWidget);
    });

    testWidgets('en zonder Health Connect staat dat blok er niet', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('STAPPEN'), findsNothing);
    });

    testWidgets('en vanaf het blok op het startscherm', (tester) async {
      // Het blok staat er pas als er iets te herstellen valt.
      await trainedLegs();
      await pumpApp(tester);
      await tester.pumpAndSettle();

      // De blokken schrijven hun titel in hoofdletters.
      final block = find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.text('HERSTEL'),
      );
      await tester.scrollUntilVisible(
        block,
        200,
        scrollable: find
            .descendant(
              of: find.byType(DashboardScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(block);
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryScreen), findsOneWidget);
    });
  });

  group('het scherm', () {
    Future<void> openRecovery(WidgetTester tester) async {
      await pumpApp(tester);
      container!.read(routerProvider).push(Routes.muscleRecovery);
      await tester.pumpAndSettle();
    }

    testWidgets('zonder training is er niets om naar te vragen', (
      tester,
    ) async {
      await openRecovery(tester);

      expect(find.textContaining('Nog niets om te herstellen'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('bovenaan staat het rapport van vandaag, op verzoek', (
      tester,
    ) async {
      await trainedLegs();
      await openRecovery(tester);
      expect(find.text('Nog geen rapport van vandaag'), findsOneWidget);

      // Wat de knop doet, met echte tijd: het rapport leest de hele
      // herstelschatting in, en dat loopt niet op de klok van de test.
      await tester.runAsync(
        () => container!.read(morningControllerProvider.notifier).makeNow(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nog geen rapport van vandaag'), findsNothing);
      expect(find.text('slaapscore'), findsOneWidget);
      expect(find.text('1 in herstel'), findsOneWidget);
      expect(find.textContaining('Nog in herstel: quadriceps'), findsOneWidget);
      expect(find.text('Opnieuw opstellen'), findsOneWidget);
      expect(await db.select(db.morningReportsTable).get(), hasLength(1));
    });

    testWidgets('met een training vraagt het hoe die spier voelt', (
      tester,
    ) async {
      await trainedLegs();
      await openRecovery(tester);

      expect(find.text('quadriceps'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Fris'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Stijf'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pijnlijk'), findsOneWidget);
    });

    testWidgets('en een antwoord wordt bewaard en meteen meegeteld', (
      tester,
    ) async {
      await trainedLegs();
      await openRecovery(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Pijnlijk'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.sorenessChecksTable).get();
      expect(rows.single.muscle, 'quadriceps');
      expect(rows.single.level, SorenessLevel.sore.wire);
      // En het scherm zegt waarom de schatting nu is wat ze is.
      expect(find.textContaining('vandaag pijnlijk'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pijnlijk'))
            .selected,
        isTrue,
      );
    });

    testWidgets('een ander antwoord vervangt het eerste', (tester) async {
      await trainedLegs();
      await openRecovery(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Pijnlijk'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Stijf'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.sorenessChecksTable).get();
      expect(rows.single.level, SorenessLevel.stiff.wire);
    });

    testWidgets('en nog eens tikken neemt het terug', (tester) async {
      await trainedLegs();
      await openRecovery(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Stijf'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Stijf'));
      await tester.pumpAndSettle();

      expect(await db.select(db.sorenessChecksTable).get(), isEmpty);
    });
  });

  group('slaap', () {
    Future<void> openRecovery(WidgetTester tester) async {
      await pumpApp(tester);
      container!.read(routerProvider).push(Routes.muscleRecovery);
      await tester.pumpAndSettle();
    }

    Future<void> openSheet(WidgetTester tester) async {
      final button = find.text('Afgelopen nacht invullen');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .descendant(
              of: find.byType(RecoveryScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('een nacht is twee tijden, en meer niet', (tester) async {
      await openRecovery(tester);
      await openSheet(tester);

      expect(find.text('In slaap gevallen'), findsOneWidget);
      expect(find.text('Wakker geworden'), findsOneWidget);
      // Zonder de schakelaar geen fasen.
      expect(find.text('Diep'), findsNothing);

      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      final row = (await db.select(db.sleepEntriesTable).get()).single;
      expect(
        Duration(milliseconds: row.wokeAt - row.fellAsleepAt),
        const Duration(hours: 8),
      );
      // En de knop is weg: die nacht staat erin.
      expect(find.text('Afgelopen nacht invullen'), findsNothing);
      expect(find.textContaining('8 u'), findsWidgets);
      // Acht uur, zonder fasen of horloge: de volle score.
      expect(find.textContaining('slaapscore 100'), findsOneWidget);
    });

    testWidgets('een uur na twaalf typ je ook op een gsm met AM en PM', (
      tester,
    ) async {
      // Een toestel op 12 uur tijd liet het getypte 23 weigeren: de klok
      // toonde 24 uur, maar het invoerveld hield zich aan AM en PM.
      await openRecovery(tester);
      await openSheet(tester);
      await tester.tap(find.text('In slaap gevallen'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '23');
      await tester.enterText(fields.at(1), '15');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Geef een geldige tijd op'), findsNothing);
      expect(find.textContaining('23:15'), findsWidgets);
    });

    testWidgets('alleen afgelopen nacht, en de rest per week', (tester) async {
      final today = DateTime.now();
      await db.recoveryDao.setSleep(
        fellAsleepAt: DateTime(today.year, today.month, today.day - 1, 23),
        wokeAt: DateTime(today.year, today.month, today.day, 7),
      );
      await db.recoveryDao.setSleep(
        fellAsleepAt: DateTime(today.year, today.month, today.day - 2, 23),
        wokeAt: DateTime(today.year, today.month, today.day - 1, 6),
      );
      await openRecovery(tester);

      final earlier = find.text('Eerdere nachten');
      await tester.scrollUntilVisible(
        earlier,
        200,
        scrollable: find
            .descendant(
              of: find.byType(RecoveryScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Eén nacht op dit scherm: die van vannacht.
      expect(
        find.descendant(
          of: find.byType(SleepSection),
          matching: find.textContaining('slaapscore'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('7 u'), findsNothing);

      await tester.tap(earlier);
      await tester.pumpAndSettle();

      expect(find.byType(SleepWeekScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SleepWeekScreen),
          matching: find.byType(NightRow),
        ),
        // Op een maandag hoort de nacht van gisteren bij de vorige week.
        findsNWidgets(today.weekday == DateTime.monday ? 1 : 2),
      );
    });

    testWidgets('en eerdere rapporten hebben hun eigen scherm', (tester) async {
      await openRecovery(tester);
      await tester.runAsync(
        () => container!.read(morningControllerProvider.notifier).makeNow(),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eerdere rapporten'));
      await tester.pumpAndSettle();

      expect(find.byType(ReportWeekScreen), findsOneWidget);
      expect(find.text('Deze week'), findsOneWidget);
    });

    testWidgets('met de schakelaar aan vraagt ze ook de fasen', (tester) async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(trackSleepStages: Value(true)),
      );
      await openRecovery(tester);
      await openSheet(tester);

      expect(find.text('Licht'), findsOneWidget);
      expect(find.text('REM'), findsOneWidget);
      expect(find.text('Diep'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Diep'), '1:20');
      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      final row = (await db.select(db.sleepEntriesTable).get()).single;
      expect(row.deepMinutes, 80);
      expect(row.lightMinutes, isNull);
    });

    testWidgets('en fasen die langer zijn dan de nacht worden geweigerd', (
      tester,
    ) async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(trackSleepStages: Value(true)),
      );
      await openRecovery(tester);
      await openSheet(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Diep'), '9:00');
      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('langer dan de nacht'), findsOneWidget);
      expect(await db.select(db.sleepEntriesTable).get(), isEmpty);
    });
  });

  group('alcohol', () {
    Future<void> openRecovery(WidgetTester tester) async {
      await pumpApp(tester);
      container!.read(routerProvider).push(Routes.muscleRecovery);
      await tester.pumpAndSettle();
    }

    testWidgets('staat er niet tot je erom vraagt', (tester) async {
      await openRecovery(tester);

      expect(find.text('ALCOHOL'), findsNothing);
      expect(find.text('Vandaag'), findsNothing);
    });

    testWidgets('en met de schakelaar aan tel je de glazen', (tester) async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(trackAlcohol: Value(true)),
      );
      await openRecovery(tester);

      final plus = find.byTooltip('Een glas meer').first;
      await tester.scrollUntilVisible(
        plus,
        200,
        scrollable: find
            .descendant(
              of: find.byType(RecoveryScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pumpAndSettle();

      final row = (await db.select(db.drinkDaysTable).get()).single;
      expect(row.drinks, 2);
      final now = DateTime.now();
      expect(
        row.day,
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
      );
      expect(find.text('2 glazen'), findsOneWidget);
    });
  });

  testWidgets('en op een smalle gsm past alles, met alles aan', (tester) async {
    // De andere tests draaien breed. Een rij die niet past, geeft op 360
    // pixels een fout - en die faalt deze test.
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(
        trackSleepStages: Value(true),
        trackAlcohol: Value(true),
      ),
    );
    await trainedLegs();
    await pumpApp(tester, size: const Size(360, 780));
    container!.read(routerProvider).push(Routes.muscleRecovery);
    await tester.pumpAndSettle();

    // Het rapport staat bovenaan; de spiergroepen staan eronder.
    final sore = find.widgetWithText(ChoiceChip, 'Pijnlijk');
    await tester.ensureVisible(sore);
    await tester.pumpAndSettle();
    await tester.tap(sore);
    await tester.pumpAndSettle();

    final button = find.text('Afgelopen nacht invullen');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find
          .descendant(
            of: find.byType(RecoveryScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Diep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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
