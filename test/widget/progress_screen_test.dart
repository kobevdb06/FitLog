import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/core/widgets/charts.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/features/progress/presentation/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Voortgang.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime.now();
  DateTime daysAgo(int days) => now.subtract(Duration(days: days, hours: 1));

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A finished workout at [at], with what it adds up to.
  Future<void> workout(DateTime at, {int sets = 10, double volume = 2000}) => db
      .into(db.workoutsTable)
      .insert(
        WorkoutsTableCompanion.insert(
          id: 'w-${at.millisecondsSinceEpoch}',
          name: 'Training',
          startedAt: at.millisecondsSinceEpoch,
          endedAt: Value(
            at.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
          totalSets: Value(sets),
          totalVolumeKg: Value(volume),
        ),
      );

  Future<void> exercise(String id, String name, {bool archived = false}) => db
      .into(db.exercisesTable)
      .insert(
        ExercisesTableCompanion.insert(
          id: id,
          name: name,
          primaryMuscle: 'borst',
          category: 'barbell',
          createdAt: 0,
          isArchived: Value(archived),
        ),
      );

  /// One session of [exerciseId] at [at]: three sets of three at [kg], an
  /// estimated 1RM of [kg] times 1.1.
  Future<void> session(String exerciseId, DateTime at, double kg) async {
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
              weightKg: Value(kg),
              reps: const Value(3),
              isCompleted: const Value(true),
            ),
          );
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const ProgressScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String period) async {
    await tester.tap(find.text(period));
    await tester.pumpAndSettle();
  }

  String stat(WidgetTester tester, String label) => tester
      .widget<StatTile>(
        find.ancestor(of: find.text(label), matching: find.byType(StatTile)),
      )
      .value;

  group('een periode voor alle grafieken', () {
    testWidgets('drie maanden tot je iets anders kiest', (tester) async {
      await pump(tester);

      final picker = tester.widget<SegmentedButton<Object?>>(
        find.byWidgetPredicate((w) => w is SegmentedButton),
      );
      expect(picker.segments, hasLength(3));
      for (final label in ['4 weken', '3 maanden', '1 jaar']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Volume per week'), findsOneWidget);
      expect(
        tester.widget<SimpleBarChart>(find.byType(SimpleBarChart).first).values,
        hasLength(13),
        reason: 'thirteen weeks',
      );
    });

    testWidgets('de totalen en de balken volgen de keuze', (tester) async {
      await tester.runAsync(() async {
        await workout(daysAgo(2), sets: 12, volume: 3000);
        await workout(daysAgo(9), sets: 8, volume: 1500);
        await workout(daysAgo(56));
        await workout(daysAgo(200));
      });
      await pump(tester);

      expect(stat(tester, 'Workouts'), '3');
      expect(stat(tester, 'Sets'), '30');

      await choose(tester, '4 weken');
      expect(stat(tester, 'Workouts'), '2');
      expect(stat(tester, 'Sets'), '20');
      expect(stat(tester, 'Volume'), '4,5 t');
      expect(
        tester.widget<SimpleBarChart>(find.byType(SimpleBarChart).first).values,
        hasLength(4),
      );

      await choose(tester, '1 jaar');
      expect(stat(tester, 'Workouts'), '4');
      expect(find.text('Volume per maand'), findsOneWidget);
      expect(find.text('Workouts per maand'), findsOneWidget);
      final bars = tester.widget<SimpleBarChart>(
        find.byType(SimpleBarChart).first,
      );
      expect(bars.values, hasLength(12), reason: 'a bar per month');
      expect(bars.labels.last, Formatters.month(now));
    });

    testWidgets('de keuze blijft staan als je terugkomt', (tester) async {
      await pump(tester);
      await choose(tester, '1 jaar');

      await tester.pumpWidget(const SizedBox());
      await pump(tester);

      expect(find.text('Volume per maand'), findsOneWidget);
    });
  });

  group('hoofdoefeningen', () {
    testWidgets('de vaakst gedane, met hoe ver ze kwamen', (tester) async {
      await tester.runAsync(() async {
        await exercise('bench', 'Bench Press');
        await exercise('squat', 'Back Squat');
        await exercise('row', 'Barbell Row');
        await exercise('curl', 'Barbell Curl', archived: true);
        await exercise('lunge', 'Lunge');
        for (final (days, kg) in [
          (70, 100.0),
          (63, 100.0),
          (56, 102.5),
          (49, 102.5),
          (14, 105.0),
          (7, 107.5),
        ]) {
          await session('bench', daysAgo(days), kg);
        }
        for (final days in [60, 40, 20, 5]) {
          await session('squat', daysAgo(days), 140);
        }
        await session('row', daysAgo(30), 80);
        await session('row', daysAgo(3), 82.5);
        // Put away: however often it was done, it is not followed.
        for (var days = 10; days < 80; days += 10) {
          await session('curl', daysAgo(days), 40);
        }
        // Once is not a direction.
        await session('lunge', daysAgo(4), 60);
      });
      await pump(tester);

      expect(find.text('HOOFDOEFENINGEN'), findsOneWidget);
      // The squat has stood still, so it is under Staat stil as well.
      Finder lift(String name) => find.descendant(
        of: find.ancestor(
          of: find.byType(Sparkline),
          matching: find.byType(InkWell),
        ),
        matching: find.text(name),
      );
      final rows = ['Bench Press', 'Back Squat', 'Barbell Row'];
      for (var i = 1; i < rows.length; i++) {
        expect(
          tester.getTopLeft(lift(rows[i - 1])).dy,
          lessThan(tester.getTopLeft(lift(rows[i])).dy),
          reason: '${rows[i - 1]} above ${rows[i]}',
        );
      }
      expect(find.text('Barbell Curl'), findsNothing);
      expect(find.text('Lunge'), findsNothing);

      // 107.5 for three, against 100 for three at the start.
      expect(find.text('118,25 kg'), findsOneWidget);
      expect(find.text('Geschatte 1RM · 6 sessies'), findsOneWidget);
      expect(
        find.text('+8,25 kg sinds ${Formatters.dayMonth(daysAgo(70))}'),
        findsOneWidget,
      );
      expect(
        find.text('Gelijk sinds ${Formatters.dayMonth(daysAgo(60))}'),
        findsOneWidget,
      );
      // Two sessions: where it stands, nothing to compare yet.
      expect(find.text('Geschatte 1RM · 2 sessies'), findsOneWidget);
      expect(
        find.textContaining('sinds ${Formatters.dayMonth(daysAgo(30))}'),
        findsNothing,
      );
      expect(find.byType(Sparkline), findsNWidgets(3));
    });

    testWidgets('hooguit vier', (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 6; i++) {
          await exercise('ex$i', 'Oefening $i');
          await session('ex$i', daysAgo(20 + i), 50);
          await session('ex$i', daysAgo(10 + i), 50);
        }
      });
      await pump(tester);

      expect(find.byType(Sparkline), findsNWidgets(4));
      // The ones done last.
      expect(find.text('Oefening 0'), findsOneWidget);
      expect(find.text('Oefening 5'), findsNothing);
    });

    testWidgets('volgen de gekozen periode', (tester) async {
      await tester.runAsync(() async {
        await exercise('bench', 'Bench Press');
        await session('bench', daysAgo(200), 100);
        await session('bench', daysAgo(190), 100);
      });
      await pump(tester);

      expect(find.text('Bench Press'), findsNothing);
      expect(
        find.text(
          'Doe een oefening twee keer in deze periode, en hier staat of ze '
          'vooruitgaat.',
        ),
        findsOneWidget,
      );

      await choose(tester, '1 jaar');
      expect(find.text('Bench Press'), findsOneWidget);
    });
  });

  group('lichaamsgewicht', () {
    Future<void> weigh(double kg, DateTime at) => db.recordsDao.addMeasurement(
      type: MeasurementType.weight,
      value: kg,
      measuredAt: at,
    );

    testWidgets('de lijn en het verschil over de gekozen periode', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await weigh(80, daysAgo(200));
        await weigh(78, daysAgo(20));
        await weigh(77.5, daysAgo(2));
      });
      await pump(tester);

      expect(stat(tester, 'Laatste meting'), '77,5 kg');
      expect(
        stat(tester, 'Sinds ${Formatters.dayMonth(daysAgo(20))}'),
        '-0,5 kg',
      );
      expect(
        tester.widget<TrendLineChart>(find.byType(TrendLineChart)).points,
        hasLength(2),
      );

      await choose(tester, '1 jaar');
      expect(
        stat(tester, 'Sinds ${Formatters.dayMonth(daysAgo(200))}'),
        '-2,5 kg',
      );
    });

    testWidgets('zonder meting in de periode: de laatste, en dat zegt het', (
      tester,
    ) async {
      await tester.runAsync(() => weigh(80, daysAgo(200)));
      await pump(tester);

      expect(stat(tester, 'Laatste meting'), '80 kg');
      expect(find.text('Geen metingen in deze periode'), findsOneWidget);
    });
  });

  testWidgets("onder Meer je foto's; records en metingen staan op Profiel", (
    tester,
  ) async {
    await pump(tester);

    final more = find.text('MEER');
    await tester.ensureVisible(more);
    expect(more, findsOneWidget);
    expect(find.widgetWithText(ListTile, "Voortgangsfoto's"), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Persoonlijke records'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Lichaamsmetingen'), findsNothing);
  });
}
