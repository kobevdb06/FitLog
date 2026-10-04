import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:fitlog/features/health/presentation/health_overview_screen.dart';
import 'package:fitlog/features/health/presentation/heart_rate_week_screen.dart';
import 'package:fitlog/features/health/presentation/steps_week_screen.dart';
import 'package:fitlog/features/morning/domain/morning_facts.dart';
import 'package:fitlog/features/morning/presentation/morning_report_card.dart';
import 'package:fitlog/features/progress/data/plateau_loader.dart';
import 'package:fitlog/features/progress/presentation/plateau_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The screens as they look on a real phone: about 412 points wide, with the
/// text a little larger than the default, as many people set it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
    );
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpPhone(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(412, 2400),
    double textScale = 1.15,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// One finished session of [exerciseId] [weeksAgo] weeks back: three sets
  /// of [reps] at [weight].
  Future<void> logSession(
    String exerciseId,
    int weeksAgo,
    double weight, {
    int reps = 8,
  }) async {
    final at = DateTime.now().subtract(Duration(days: 7 * weeksAgo, hours: 2));
    final id = '$exerciseId-$weeksAgo';
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: id,
            name: 'Training',
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(at.millisecondsSinceEpoch + 3600000),
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
              reps: Value(reps),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  Future<void> addExercise(String id, String name) => db
      .into(db.exercisesTable)
      .insert(
        ExercisesTableCompanion.insert(
          id: id,
          name: name,
          primaryMuscle: 'borst',
          category: 'barbell',
          createdAt: 0,
        ),
      );

  /// A real phone screen, with the text as large as on the user's.
  const phone = Size(412, 915);
  const largeText = 1.3;

  /// The tops of these texts, to see they sit on one line.
  List<double> tops(WidgetTester tester, List<String> texts) => [
    // The first: the same number can stand in a list further down.
    for (final text in texts) tester.getTopLeft(find.text(text).first).dy,
  ];

  /// That these numbers stand on one line. One that had to shrink stands on
  /// the same line as the rest, its bottom a hair higher at most for its
  /// smaller descent.
  void expectOnOneLine(WidgetTester tester, List<Finder> numbers) {
    final bottoms = [for (final n in numbers) tester.getBottomLeft(n).dy];
    for (final bottom in bottoms) {
      expect(bottom, closeTo(bottoms.first, 1.5), reason: 'niet op één lijn');
    }
  }

  testWidgets('de rapportkaart past, met beide knoppen', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(
      () => db.reportsDao.saveReport(
        day: now,
        createdAt: now,
        facts: jsonEncode(
          MorningFacts(
            day: DateTime(now.year, now.month, now.day),
            score: 100,
          ).toJson(),
        ),
        coachText: 'Een rapport.',
      ),
    );
    await pumpPhone(
      tester,
      const Scaffold(body: SingleChildScrollView(child: MorningReportCard())),
    );

    expect(tester.takeException(), isNull);
    for (final label in ['Alle rapporten', 'Opnieuw opstellen']) {
      final right = tester.getBottomRight(find.text(label)).dx;
      expect(
        right,
        lessThanOrEqualTo(412),
        reason: '$label valt van het scherm',
      );
    }
  });

  testWidgets('op Gezondheid staan de getallen op één lijn', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await tester.runAsync(() async {
      await db.recoveryDao.setSleep(
        fellAsleepAt: today.subtract(const Duration(minutes: 30)),
        wokeAt: today.add(const Duration(hours: 9, minutes: 40)),
      );
      await db.healthDao.setSteps(today, 3249);
    });
    await pumpPhone(tester, HealthOverviewScreen(now: now));

    expectOnOneLine(tester, [
      find.text('100').first,
      find.text('10 u 10').first,
    ]);
    // Vandaag en het gemiddelde zijn hier allebei 3.249.
    final steps = find.text('3.249');
    expectOnOneLine(tester, [steps.at(0), steps.at(1)]);
  });

  testWidgets('bij de stappen raken de labels elkaar niet', (tester) async {
    await tester.runAsync(() async {
      await db.healthDao.setSteps(DateTime(2026, 10, 1), 6775);
      await db.healthDao.setSteps(DateTime(2026, 10, 3), 9600);
    });
    await pumpPhone(tester, StepsWeekScreen(now: DateTime(2026, 10, 4, 21)));

    final average = tester.getBottomRight(find.text('Gemiddeld per dag')).dx;
    final best = tester.getTopLeft(find.text('Beste dag')).dx;
    expect(best - average, greaterThanOrEqualTo(8));
    expectOnOneLine(tester, [
      for (final value in ['16.375', '8.188', '9.600']) find.text(value).first,
    ]);
    // In de rij: "Deze week" staat ook boven de week zelf.
    final labels = [
      for (final label in ['Deze week', 'Gemiddeld per dag', 'Beste dag'])
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(StatRow),
                matching: find.text(label),
              ),
            )
            .dy,
    ];
    expect(labels.toSet(), hasLength(1), reason: 'labels op één lijn');
  });

  testWidgets('bij de hartslag ook', (tester) async {
    await tester.runAsync(
      () => db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w1',
              name: 'Leg day',
              startedAt: DateTime(2026, 9, 30, 18).millisecondsSinceEpoch,
              endedAt: Value(DateTime(2026, 9, 30, 19).millisecondsSinceEpoch),
              avgHeartRate: const Value(116),
              maxHeartRate: const Value(150),
            ),
          ),
    );
    await pumpPhone(
      tester,
      HeartRateWeekScreen(now: DateTime(2026, 10, 4, 21)),
    );

    expectOnOneLine(tester, [
      for (final value in ['116 bpm', '150 bpm', '1']) find.text(value).first,
    ]);
    expect(tester.takeException(), isNull);
  });

  group('de grafieken van een oefening', () {
    testWidgets('de PR-knop staat over niets als je onderaan bent', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await addExercise('ex-incline', 'Incline Dumbbell Press');
        for (final (w, weight) in [
          (8, 40.0),
          (7, 42.5),
          (6, 45.0),
          (5, 45.0),
          (4, 42.5),
          (3, 45.0),
          (2, 45.0),
          (1, 42.5),
          (0, 45.0),
        ]) {
          await logSession('ex-incline', w, weight);
        }
      });
      await pumpPhone(
        tester,
        const ExerciseDetailScreen(
          exerciseId: 'ex-incline',
          initialTab: ExerciseDetailScreen.chartsTab,
        ),
        size: phone,
        textScale: largeText,
      );
      expect(find.textContaining('Staat stil sinds'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();

      final button = tester.getRect(find.byType(FloatingActionButton));
      expect(
        tester.getRect(find.text('Sessies')).bottom,
        lessThanOrEqualTo(button.top),
        reason: 'het laatste staat onder de PR-knop',
      );
    });

    testWidgets('de getallen onder de grafiek houden afstand', (tester) async {
      await tester.runAsync(() async {
        await addExercise('ex-bench', 'Barbell Bench Press - Medium Grip');
        for (var w = 4; w >= 0; w--) {
          await logSession('ex-bench', w, 100 + (4 - w) * 4.5, reps: 11);
        }
      });
      await pumpPhone(
        tester,
        const ExerciseDetailScreen(
          exerciseId: 'ex-bench',
          initialTab: ExerciseDetailScreen.chartsTab,
        ),
        size: phone,
        textScale: largeText,
      );

      // Laatste en Beste zijn hier hetzelfde getal.
      final values = find.text('161,25 kg');
      expect(values, findsNWidgets(2));
      expect(
        tester.getTopLeft(values.at(1)).dx -
            tester.getBottomRight(values.at(0)).dx,
        greaterThanOrEqualTo(8),
      );
      expect(
        tester.getTopLeft(find.text('5')).dx -
            tester.getBottomRight(values.at(1)).dx,
        greaterThanOrEqualTo(8),
      );
      final labels = tops(tester, ['Laatste', 'Beste', 'Sessies']);
      expect(labels.toSet(), hasLength(1), reason: 'labels op één lijn');
    });
  });

  testWidgets('de kaart van een oefening die stilstaat, met de coach', (
    tester,
  ) async {
    final now = DateTime.now();
    final found = await tester.runAsync(() async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-row',
              name: 'Single Arm Dumbbell Row On Incline Bench',
              primaryMuscle: 'bovenrug',
              category: 'dumbbell',
              createdAt: 0,
            ),
          );
      for (var w = 9; w >= 0; w--) {
        final at = now.subtract(Duration(days: 7 * w, hours: 2));
        final id = 'w$w';
        await db
            .into(db.workoutsTable)
            .insert(
              WorkoutsTableCompanion.insert(
                id: id,
                name: 'Rug',
                startedAt: at.millisecondsSinceEpoch,
                endedAt: Value(at.millisecondsSinceEpoch + 3600000),
              ),
            );
        await db
            .into(db.workoutExercisesTable)
            .insert(
              WorkoutExercisesTableCompanion.insert(
                id: 'we$w',
                workoutId: id,
                exerciseId: 'ex-row',
                sortOrder: 0,
              ),
            );
        await db
            .into(db.workoutSetsTable)
            .insert(
              WorkoutSetsTableCompanion.insert(
                id: 's$w',
                workoutExerciseId: 'we$w',
                sortOrder: 0,
                weightKg: Value(w > 6 ? 30.0 + (9 - w) * 2.5 : 35.0),
                reps: const Value(8),
                isCompleted: const Value(true),
              ),
            );
        await db.recoveryDao.setSleep(
          fellAsleepAt: at.subtract(const Duration(hours: 20)),
          wokeAt: at.subtract(const Duration(hours: 13)),
        );
      }
      return loadPlateaus(db, now: now);
    });
    await pumpPhone(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PlateauCard(found: found!.single, now: now),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Vraag de coach'), findsOneWidget);
    for (final label in ['Sets voor bovenrug per week', 'Slaap per nacht']) {
      expect(
        tester.getBottomRight(find.text(label)).dx,
        lessThanOrEqualTo(412),
        reason: '$label valt van het scherm',
      );
    }
  });
}
