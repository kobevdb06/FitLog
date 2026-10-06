import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/review/presentation/week_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The weekly review on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  final monday = DateTime(2026, 9, 28);
  DateTime day(int offset, [int hour = 18]) =>
      DateTime(monday.year, monday.month, monday.day + offset, hour);

  var counter = 0;
  Future<void> session(
    DateTime at, {
    String exercise = 'ex-bench',
    String? routine,
    int sets = 3,
  }) async {
    final id = 'w${counter++}';
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: id,
            routineId: Value(routine),
            name: 'Training',
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(at.millisecondsSinceEpoch + 3600000),
            totalVolumeKg: Value(sets * 640.0),
          ),
        );
    await db
        .into(db.workoutExercisesTable)
        .insert(
          WorkoutExercisesTableCompanion.insert(
            id: 'we-$id',
            workoutId: id,
            exerciseId: exercise,
            sortOrder: 0,
          ),
        );
    for (var i = 0; i < sets; i++) {
      await db
          .into(db.workoutSetsTable)
          .insert(
            WorkoutSetsTableCompanion.insert(
              id: 'ws-$id-$i',
              workoutExerciseId: 'we-$id',
              sortOrder: i,
              weightKg: const Value(80),
              reps: const Value(8),
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
      ('ex-row', 'Barbell Row', 'rug'),
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
    await db
        .into(db.routinesTable)
        .insert(
          RoutinesTableCompanion.insert(
            id: 'r-pull',
            name: 'Pull',
            sortOrder: 0,
            createdAt: 0,
            updatedAt: 0,
            scheduledDays: const Value(16),
          ),
        );
    for (var w = 1; w <= 4; w++) {
      await session(day(-7 * w), exercise: 'ex-row', sets: 10);
    }
    await session(day(0), sets: 14);
    await session(day(2), exercise: 'ex-row', sets: 4);
    await db
        .into(db.personalRecordsTable)
        .insert(
          PersonalRecordsTableCompanion.insert(
            id: 'pr-1',
            exerciseId: 'ex-bench',
            recordType: 'est_1rm',
            value: 101.3,
            achievedAt: day(0).millisecondsSinceEpoch,
          ),
        );
    for (var d = -28; d < 7; d++) {
      final woke = day(d, 7);
      await db.recoveryDao.setSleep(
        fellAsleepAt: woke.subtract(Duration(minutes: d < 0 ? 450 : 425)),
        wokeAt: woke,
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

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1100, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(
        container,
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: WeekReviewScreen(
            initial: monday,
            now: DateTime(2026, 10, 6, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('de week, van trainingen tot slaap', (tester) async {
    await pump(tester);

    expect(find.text('28/9 – 4/10'), findsOneWidget);
    // Pull stond op vrijdag en kwam er niet.
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('Pull van vrijdag niet gedaan'), findsOneWidget);
    expect(find.text('Plus 2 trainingen buiten je planning'), findsOneWidget);
    expect(find.text('Borst'), findsOneWidget);
    expect(find.text('Rug'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('1RM 101,25 kg'), findsOneWidget);
    expect(find.text('7 u 5'), findsOneWidget);
    expect(find.text('Slaap per nacht, gewoon 7 u 30'), findsOneWidget);
  });

  testWidgets('past op een gsm met grote tekst', (tester) async {
    await pump(tester, size: const Size(412, 915), textScale: 1.3);

    expect(tester.takeException(), isNull);
  });
}
