import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/dashboard/presentation/today_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The card at the top of the Start tab, and the heading it dares to use.
///
/// The weekday itself is pinned in `test/dashboard/today_plan_test.dart`, which
/// takes the moment as an argument. Here the clock is the real one, so a case
/// that has to be today is planned on every day of the week, and a case that
/// has to be any other day is planned on all the days today is not.
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
    // Before the database: the container holds drift streams, and closing the
    // connection out from under them leaves a timer pending in the test zone.
    container?.dispose();
    container = null;
    await db.close();
  });

  RoutineRow routine(
    String name, {
    WeekdaySet days = WeekdaySet.none,
    DateTime? lastPerformed,
  }) => RoutineRow(
    id: name,
    name: name,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    lastPerformedAt: lastPerformed?.millisecondsSinceEpoch,
    isFavourite: false,
    scheduledDays: days.mask,
  );

  WeekdaySet everyDay() => WeekdaySet.of([
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) day,
  ]);

  WeekdaySet everyOtherDay() {
    final today = trainingWeekday(DateTime.now());
    return WeekdaySet.of([
      for (var day = DateTime.monday; day <= DateTime.sunday; day++)
        if (day != today) day,
    ]);
  }

  Future<void> pump(
    WidgetTester tester, {
    List<RoutineRow> scheduled = const [],
    List<RoutineRow> favourites = const [],
    RoutineRow? suggested,
  }) async {
    // The card is a list item, and a list only builds what fits on screen.
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        scheduledRoutinesProvider.overrideWith(
          (ref) => Stream.value(scheduled),
        ),
        favouriteRoutinesProvider.overrideWith(
          (ref) => Stream.value(favourites),
        ),
        suggestedRoutineProvider.overrideWith((ref) async => suggested),
      ],
    );

    await tester.pumpWidget(
      wrapWithContainer(container!, const DashboardScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a planned day says so, and names the routine', (tester) async {
    await pump(tester, scheduled: [routine('Chest day 2', days: everyDay())]);

    expect(find.text('Vandaag'), findsOneWidget);
    expect(find.text('Chest day 2'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
  });

  testWidgets('every routine on that day is on the card', (tester) async {
    await pump(
      tester,
      scheduled: [
        routine('Bench', days: everyDay()),
        routine('Flyes', days: everyDay()),
      ],
    );

    expect(find.text('Ook vandaag'), findsOneWidget);
    expect(find.text('Flyes'), findsOneWidget);
  });

  testWidgets('one you already did today is ticked off', (tester) async {
    await pump(
      tester,
      scheduled: [
        routine('Chest day 2', days: everyDay(), lastPerformed: DateTime.now()),
      ],
    );

    expect(find.text('Vandaag - alles gedaan'), findsOneWidget);
    expect(find.text('Vandaag al gedaan'), findsOneWidget);
    expect(find.text('Nog een keer'), findsOneWidget);
  });

  testWidgets('a day your plan leaves empty is a rest day', (tester) async {
    await pump(tester, scheduled: [routine('Squat', days: everyOtherDay())]);

    expect(find.text('Rustdag'), findsOneWidget);
    expect(find.text('Toch trainen'), findsOneWidget);
    // The plan is still there, so the card says when it picks up again.
    expect(find.textContaining('Squat'), findsOneWidget);
  });

  testWidgets('without a schedule it offers your favourites', (tester) async {
    await pump(
      tester,
      favourites: [routine('Arms'), routine('Legs')],
      suggested: routine('Iets ouds'),
    );

    expect(find.text('Je favorieten'), findsOneWidget);
    expect(find.text('Arms'), findsOneWidget);
    expect(find.text('Of een van deze'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
  });

  testWidgets('with nothing starred it still offers something', (tester) async {
    // The card used to show this for everyone and called it "Workout van
    // vandaag". It is still the last rung, but it no longer claims the day.
    await pump(tester, suggested: routine('Chest day 2'));

    expect(find.text('Hier was je het langst niet mee bezig'), findsOneWidget);
    expect(find.text('Chest day 2'), findsOneWidget);
    expect(find.text('Workout van vandaag'), findsNothing);
  });

  testWidgets('and with no routines at all it says to make one', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Nog geen routine'), findsOneWidget);
    expect(find.text('Routine maken'), findsOneWidget);
  });
}
