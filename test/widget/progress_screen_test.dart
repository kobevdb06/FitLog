import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/streak.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/core/widgets/charts.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/core/widgets/muscle_bars.dart';
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

  /// A date as it stands in a line: day and month never on two lines.
  String on(DateTime at) => Formatters.dayMonth(at).replaceAll(' ', ' ');

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

  Future<void> exercise(
    String id,
    String name, {
    String muscle = 'borst',
    bool archived = false,
  }) => db
      .into(db.exercisesTable)
      .insert(
        ExercisesTableCompanion.insert(
          id: id,
          name: name,
          primaryMuscle: muscle,
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

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 3000),
  }) async {
    tester.view.physicalSize = size;
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
      await tester.runAsync(() => workout(daysAgo(3)));
      await pump(tester);

      final picker = tester.widget<SegmentedButton<Object?>>(
        find.byWidgetPredicate((w) => w is SegmentedButton),
      );
      expect(picker.segments, hasLength(3));
      for (final label in ['4 weken', '3 maanden', '1 jaar']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        tester.widget<SimpleBarChart>(find.byType(SimpleBarChart)).values,
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
      final bars = tester.widget<SimpleBarChart>(
        find.byType(SimpleBarChart).first,
      );
      expect(bars.values, hasLength(12), reason: 'a bar per month');
      expect(bars.labels.last, Formatters.month(now));
    });

    testWidgets('een periode zonder workouts zegt dat, zonder lege grafieken', (
      tester,
    ) async {
      await tester.runAsync(() => workout(daysAgo(60)));
      await pump(tester);
      expect(find.byType(SimpleBarChart), findsOneWidget);

      await choose(tester, '4 weken');
      expect(find.text('Nog geen workouts in deze periode.'), findsOneWidget);
      expect(find.byType(SimpleBarChart), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('de keuze blijft staan als je terugkomt', (tester) async {
      await tester.runAsync(() => workout(daysAgo(3)));
      await pump(tester);
      await choose(tester, '1 jaar');

      await tester.pumpWidget(const SizedBox());
      await pump(tester);

      expect(
        tester.widget<SimpleBarChart>(find.byType(SimpleBarChart)).values,
        hasLength(12),
        reason: 'a bar per month',
      );
    });
  });

  group('training', () {
    Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
    List<double> bars(WidgetTester tester) =>
        tester.widget<SimpleBarChart>(find.byType(SimpleBarChart)).values;

    testWidgets('één grafiek, met wat je kiest', (tester) async {
      // Two on the Wednesday of last week: one bar.
      final week = startOfWeek(now);
      final wednesday = DateTime(week.year, week.month, week.day - 5, 10);
      await tester.runAsync(() async {
        await workout(wednesday, sets: 8, volume: 1500);
        await workout(
          wednesday.add(const Duration(hours: 3)),
          sets: 6,
          volume: 1000,
        );
      });
      await pump(tester);
      await choose(tester, '4 weken');

      // Volume first, its number in colour with it.
      expect(find.byType(SimpleBarChart), findsOneWidget);
      expect(bars(tester).reduce((a, b) => a + b), 2500);
      expect(
        tester
            .widget<StatTile>(
              find.ancestor(
                of: find.text('Volume'),
                matching: find.byType(StatTile),
              ),
            )
            .emphasis,
        isTrue,
      );

      await tester.tap(chip('Sets'));
      await tester.pumpAndSettle();
      expect(bars(tester).reduce((a, b) => a + b), 14);
      expect(bars(tester).where((v) => v > 0), [14]);

      await tester.tap(chip('Workouts'));
      await tester.pumpAndSettle();
      expect(bars(tester).where((v) => v > 0), [2]);
      expect(
        tester
            .widget<StatTile>(
              find.ancestor(
                of: find.text('Workouts'),
                matching: find.byType(StatTile),
              ),
            )
            .emphasis,
        isTrue,
      );

      // Still what you chose when you come back.
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(tester.widget<ChoiceChip>(chip('Workouts')).selected, isTrue);
    });

    testWidgets('de lopende week is nog niet af', (tester) async {
      await tester.runAsync(() => workout(daysAgo(3)));
      await pump(tester);

      expect(
        tester
            .widget<SimpleBarChart>(find.byType(SimpleBarChart))
            .lastUnfinished,
        isTrue,
      );
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

      // 107.5 for three, against 100 for three at the start: 118.25 and
      // 110, to the whole kilo - an estimate is not that precise.
      expect(find.text('118 kg'), findsOneWidget);
      // What the number is, once above them all rather than under each.
      expect(find.text('geschatte 1RM'), findsOneWidget);
      expect(find.textContaining('Geschatte 1RM ·'), findsNothing);
      expect(find.text('+8 kg sinds ${on(daysAgo(70))}'), findsOneWidget);
      expect(find.text('Gelijk sinds ${on(daysAgo(60))}'), findsOneWidget);
      // Two sessions: where it stands, nothing to compare yet.
      expect(find.text('2 sessies'), findsOneWidget);
      expect(find.textContaining('sinds ${on(daysAgo(30))}'), findsNothing);
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

  group('sets per spiergroep', () {
    testWidgets('per week, tegen de periode ervoor', (tester) async {
      await tester.runAsync(() async {
        await exercise('bench', 'Bench Press');
        await exercise('row', 'Barbell Row', muscle: 'lats');
        await exercise('squat', 'Back Squat', muscle: 'quadriceps');
        for (final days in [2, 5, 9, 12]) {
          await session('bench', daysAgo(days), 60);
        }
        // Eight times in the four weeks before, once in these four.
        for (var days = 29; days <= 36; days++) {
          await session('row', daysAgo(days), 60);
        }
        await session('row', daysAgo(6), 60);
        // Not at all any more.
        await session('squat', daysAgo(37), 100);
        await session('squat', daysAgo(39), 100);
      });
      await pump(tester);
      await choose(tester, '4 weken');

      expect(find.text('SETS PER SPIERGROEP'), findsOneWidget);
      final bars = tester.widget<MuscleBars>(find.byType(MuscleBars)).bars;
      expect([for (final b in bars) b.muscle], ['borst', 'lats', 'quadriceps']);
      expect(bars[0].usual, 0);
      expect(bars[1].lagging, isTrue, reason: 'far below the weeks before');
      expect(bars[2].value, 0, reason: 'stopped, and still listed');
      expect(bars[2].lagging, isFalse, reason: 'two sessions is no habit');
      expect(find.text('Lats'), findsOneWidget);
      expect(find.text('Quadriceps'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(MuscleBars), matching: find.text('0')),
        findsOneWidget,
      );

      // What the bars are, in a word; how to read them, on request.
      expect(find.text('Werksets per week'), findsOneWidget);
      expect(find.textContaining('Het streepje'), findsNothing);
      await tester.tap(find.byTooltip('Over sets per spiergroep'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('Het streepje'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('zonder sets zegt het dat', (tester) async {
      await pump(tester);

      expect(find.text('Nog geen sets in deze periode.'), findsOneWidget);
      expect(find.byType(MuscleBars), findsNothing);
    });
  });

  group('gewicht en maten', () {
    Future<void> weigh(double kg, DateTime at) => db.recordsDao.addMeasurement(
      type: MeasurementType.weight,
      value: kg,
      measuredAt: at,
    );

    testWidgets('een regel onder Meer, met het verschil over de periode', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await weigh(80, daysAgo(200));
        await weigh(78, daysAgo(20));
        await weigh(77.5, daysAgo(2));
      });
      await pump(tester);

      // A line that leads to Lichaamsmetingen, not a chart of its own.
      expect(find.text('LICHAAMSGEWICHT'), findsNothing);
      expect(find.byType(TrendLineChart), findsNothing);
      expect(
        find.text('77,5 kg · -0,5 kg sinds ${on(daysAgo(20))}'),
        findsOneWidget,
      );

      await choose(tester, '1 jaar');
      expect(
        find.text('77,5 kg · -2,5 kg sinds ${on(daysAgo(200))}'),
        findsOneWidget,
      );
    });

    testWidgets('zonder twee metingen in de periode: de laatste, en wanneer', (
      tester,
    ) async {
      await tester.runAsync(() => weigh(80, daysAgo(200)));
      await pump(tester);

      expect(
        find.text(
          '80 kg · ${Formatters.relativeDay(daysAgo(200)).toLowerCase()}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('zonder meting zegt het dat', (tester) async {
      await pump(tester);

      expect(
        find.widgetWithText(ListTile, 'Nog niets gemeten'),
        findsOneWidget,
      );
    });
  });

  testWidgets("onder Meer je foto's en je gewicht; records staan op Profiel", (
    tester,
  ) async {
    await pump(tester);

    final more = find.text('MEER');
    await tester.ensureVisible(more);
    expect(more, findsOneWidget);
    expect(find.widgetWithText(ListTile, "Voortgangsfoto's"), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Gewicht en maten'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Persoonlijke records'), findsNothing);
    // Ways in, not something to look at: no card around them.
    expect(
      find.ancestor(
        of: find.widgetWithText(ListTile, 'Geschiedenis'),
        matching: find.byType(AppCard),
      ),
      findsNothing,
    );
  });

  testWidgets('past op een smalle telefoon met grote letters', (tester) async {
    await tester.runAsync(() async {
      await exercise(
        'bench',
        'Incline Dumbbell Bench Press (neutral grip, paused)',
      );
      await exercise('curl', 'Hammer Curl', muscle: 'onderarmen');
      await exercise('squat', 'Back Squat', muscle: 'quadriceps');
      for (var days = 3; days < 300; days += 6) {
        await session('bench', daysAgo(days), 102.5 + days / 10);
        await session('curl', daysAgo(days + 1), 22.5);
        await session('squat', daysAgo(days + 2), 187.5 - days / 20);
        await workout(daysAgo(days), sets: 24, volume: 23456.5);
      }
      await db.recordsDao.addMeasurement(
        type: MeasurementType.weight,
        value: 104.75,
        measuredAt: daysAgo(40),
      );
      await db.recordsDao.addMeasurement(
        type: MeasurementType.weight,
        value: 101.25,
        measuredAt: daysAgo(1),
      );
    });
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, size: const Size(360, 4000));

    // Each choice on one line: "3 maanden" broke in two on the phone.
    final line = tester.getSize(find.text('4 weken')).height;
    for (final period in ['3 maanden', '1 jaar']) {
      expect(tester.getSize(find.text(period)).height, line, reason: period);
    }

    // What the chart shows, on one line: "Sets" fell to a second.
    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(3));
    for (var i = 1; i < 3; i++) {
      expect(
        tester.getTopLeft(chips.at(i)).dy,
        tester.getTopLeft(chips.at(0)).dy,
      );
    }

    // An overflow anywhere fails the test on its own.
    for (final period in ['4 weken', '1 jaar', '3 maanden']) {
      await choose(tester, period);
      expect(tester.takeException(), isNull, reason: period);
    }
    expect(find.byType(Sparkline), findsNWidgets(3));
  });

  testWidgets('Meer: eerst wat je deed, en bij elk hoe het ervoor staat', (
    tester,
  ) async {
    final done = [daysAgo(2), daysAgo(10), daysAgo(30)];
    await tester.runAsync(() async {
      for (final at in done) {
        await workout(at);
      }
    });
    await pump(tester);

    final order = [
      'Geschiedenis',
      'Weekoverzicht',
      'Herstel',
      'Gezondheid',
      'Gewicht en maten',
      "Voortgangsfoto's",
    ];
    for (var i = 1; i < order.length; i++) {
      expect(
        tester.getTopLeft(find.widgetWithText(ListTile, order[i - 1])).dy,
        lessThan(tester.getTopLeft(find.widgetWithText(ListTile, order[i])).dy),
        reason: '${order[i - 1]} above ${order[i]}',
      );
    }

    final relative = Formatters.relativeDay(daysAgo(2)).toLowerCase();
    expect(find.text('3 workouts · laatste $relative'), findsOneWidget);
    final thisWeek = done.where((at) => !at.isBefore(startOfWeek(now))).length;
    expect(
      find.text(
        thisWeek == 0
            ? 'Deze week nog geen workout'
            : 'Deze week ${Formatters.amount(thisWeek, 'workout', 'workouts')}',
      ),
      findsOneWidget,
    );
    expect(find.text("Nog geen foto's"), findsOneWidget);
    expect(find.text('Alles hersteld'), findsOneWidget);
  });
}
