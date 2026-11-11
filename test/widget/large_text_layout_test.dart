import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:fitlog/features/exercises/presentation/exercise_library_screen.dart';
import 'package:fitlog/features/history/presentation/history_screen.dart';
import 'package:fitlog/features/progress/presentation/progress_screen.dart';
import 'package:fitlog/features/progress/presentation/records_screen.dart';
import 'package:fitlog/features/routines/presentation/routines_screen.dart';
import 'package:fitlog/features/settings/presentation/profile_screen.dart';
import 'package:fitlog/features/settings/presentation/settings_screen.dart';
import 'package:fitlog/features/workout/presentation/active_workout_screen.dart';
import 'package:fitlog/features/workout/presentation/workout_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The main screens with text above 1.4, as *Grotere tekst toestaan* lets
/// Android have it, on a phone 360 dp wide: fuller, but nothing may run
/// over (DECISIONS 307).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late String finished;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(largeText: Value(true)),
    );
    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-bench',
            name: 'Barbell Bench Press',
            primaryMuscle: 'borst',
            category: 'barbell',
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // A session that is over, for the history, the progress and the
    // summary; and one that runs, for the workout screen.
    Future<String> session(String name) async {
      final id = await db.workoutsDao.startWorkout(
        name: name,
        defaultRestSeconds: 90,
      );
      await db.workoutsDao.addExercises(id, [
        'ex-bench',
      ], defaultRestSeconds: 90);
      final set = (await db.workoutsDao.getWorkoutDetail(id))!
          .exercises
          .single
          .sets
          .single;
      await db.workoutsDao.updateSet(
        set.id,
        weightKg: const Value(102.5),
        reps: const Value(8),
      );
      return id;
    }

    finished = await session('Push');
    final set = (await db.workoutsDao.getWorkoutDetail(finished))!
        .exercises
        .single
        .sets
        .single;
    await db.workoutsDao.updateSet(
      set.id,
      isCompleted: const Value(true),
      completedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    await db.workoutsDao.finishWorkout(finished, discardPending: false);
    await session('Pull');
  });

  tearDown(() => db.close());

  final screens = <String, Widget Function()>{
    'Start': () => const DashboardScreen(),
    'Trainen': () => const RoutinesScreen(),
    'Voortgang': () => const ProgressScreen(),
    'Profiel': () => const ProfileScreen(),
    'Geschiedenis': () => const HistoryScreen(),
    'Records': () => const RecordsScreen(),
    'Oefeningen': () => const ExerciseLibraryScreen(),
    'Een oefening': () => const ExerciseDetailScreen(exerciseId: 'ex-bench'),
    'De workout': () => const ActiveWorkoutScreen(),
    'Het overzicht na een workout': () =>
        WorkoutSummaryScreen(workoutId: finished),
    'Instellingen': () => const SettingsScreen(),
  };

  /// [screen] on a phone 360 dp wide, with Android asking for [scale].
  Future<void> pumpAt(WidgetTester tester, Widget screen, double scale) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      wrapWithContainer(container, screen, largeText: true),
    );
    // Fixed frames: the workout's clock ticks, so it never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// What the screen leaves behind runs out before the test ends.
  Future<void> putAway(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final scale in [1.7, 2.0]) {
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets('$name loopt niet over bij tekst $scale', (tester) async {
        await pumpAt(tester, screen(), scale);

        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first))
              .scale(10),
          closeTo(10 * scale, 0.001),
          reason: 'the screen got the scale it was asked for',
        );
        expect(tester.takeException(), isNull);
        await putAway(tester);
      });
    }
  }

  testWidgets('de koppen boven de sets breken niet midden in een woord bij '
      'tekst 2.0', (tester) async {
    // "SET" stood as "SE" over "T" on the emulator.
    await pumpAt(tester, const ActiveWorkoutScreen(), 2.0);

    for (final label in ['SET', 'VORIGE', 'KG', 'REPS']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(label).first,
      );
      final oneLine = paragraph.getMinIntrinsicHeight(double.infinity);
      expect(paragraph.size.height, lessThan(oneLine * 1.5), reason: label);
    }
    await putAway(tester);
  });
}
