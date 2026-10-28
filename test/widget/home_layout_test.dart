import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/dashboard/domain/home_layout.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/dashboard/presentation/today_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The Start tab built from the user's own grid of blocks.
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

  RoutineRow routine(String name, {WeekdaySet days = WeekdaySet.none}) =>
      RoutineRow(
        planState: 'approved',
        id: name,
        name: name,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
        isFavourite: true,
        scheduledDays: days.mask,
      );

  WeekdaySet everyDay() => WeekdaySet.of([
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) day,
  ]);

  Future<void> pump(
    WidgetTester tester, {
    required HomeLayout layout,
    List<RoutineRow> scheduled = const [],
    List<RoutineRow> favourites = const [],
    Size size = const Size(1100, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        homeLayoutProvider.overrideWithValue(layout),
        scheduledRoutinesProvider.overrideWith(
          (ref) => Stream.value(scheduled),
        ),
        favouriteRoutinesProvider.overrideWith(
          (ref) => Stream.value(favourites),
        ),
        suggestedRoutineProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );

    await tester.pumpWidget(
      wrapWithContainer(container!, const DashboardScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // SectionHeader puts its title in capitals.
  const weekHeader = 'DEZE WEEK';
  const volumeHeader = 'VOLUME, LAATSTE 8 WEKEN';

  testWidgets('the default shows the blocks it always showed', (tester) async {
    await pump(tester, layout: defaultHomeLayout());

    expect(find.text(weekHeader), findsOneWidget);
    expect(find.text(volumeHeader), findsOneWidget);
  });

  testWidgets('a block you switched off is not built', (tester) async {
    await pump(tester, layout: defaultHomeLayout().without(HomeBlock.week));

    expect(find.text(weekHeader), findsNothing);
    expect(find.text(volumeHeader), findsOneWidget);
  });

  testWidgets('by default the week comes before the volume', (tester) async {
    await pump(tester, layout: defaultHomeLayout());

    expect(
      tester.getTopLeft(find.text(weekHeader)).dy,
      lessThan(tester.getTopLeft(find.text(volumeHeader)).dy),
    );
  });

  testWidgets('and with the volume placed above, it is above', (tester) async {
    await pump(
      tester,
      layout: const HomeLayout({
        HomeBlock.volume: HomeSpot(0, 0, 4, 3),
        HomeBlock.week: HomeSpot(0, 3, 4, 2),
      }),
    );

    expect(
      tester.getTopLeft(find.text(volumeHeader)).dy,
      lessThan(tester.getTopLeft(find.text(weekHeader)).dy),
    );
  });

  testWidgets('switching every block off says so rather than showing a blank', (
    tester,
  ) async {
    await pump(tester, layout: const HomeLayout({}));

    expect(find.text('Je startscherm is leeg'), findsOneWidget);
    expect(find.text('Startscherm indelen'), findsOneWidget);
  });

  group('the favourites block', () {
    testWidgets('sits next to a schedule when you switch it on', (
      tester,
    ) async {
      await pump(
        tester,
        layout: defaultHomeLayout().withShown(HomeBlock.favourites),
        scheduled: [routine('Chest day 2', days: everyDay())],
        favourites: [routine('Arms')],
      );

      expect(find.text('Vandaag'), findsOneWidget);
      expect(find.text('FAVORIETEN'), findsOneWidget);
      expect(find.text('Arms'), findsOneWidget);
    });

    testWidgets('steps aside when Vandaag is already showing them', (
      tester,
    ) async {
      // No schedule, so the card above has fallen through to the favourites.
      // The same three routines twice is not a layout anybody chose.
      await pump(
        tester,
        layout: defaultHomeLayout().withShown(HomeBlock.favourites),
        favourites: [routine('Arms')],
      );

      expect(find.text('Je favorieten'), findsOneWidget);
      // Its place stays its own, and says why it is quiet.
      expect(find.text('FAVORIETEN'), findsOneWidget);
      expect(find.text('Je favorieten staan nu bij Vandaag.'), findsOneWidget);
    });

    testWidgets('but not when you switched Vandaag off', (tester) async {
      await pump(
        tester,
        layout: defaultHomeLayout()
            .withShown(HomeBlock.favourites)
            .without(HomeBlock.today),
        favourites: [routine('Arms')],
      );

      expect(find.text('Je favorieten'), findsNothing);
      expect(find.text('FAVORIETEN'), findsOneWidget);
    });

    testWidgets('and says so when nothing is starred', (tester) async {
      await pump(
        tester,
        layout: defaultHomeLayout().withShown(HomeBlock.favourites),
        scheduled: [routine('Chest day 2', days: everyDay())],
      );

      expect(
        find.text('Nog geen favorieten. Geef een routine een ster.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('scrolling back up does not jump to the top', (tester) async {
    // One workout and no backup: the banner above the blocks has something
    // to say, and only once its numbers have loaded.
    await tester.runAsync(() async {
      final at = DateTime.now().subtract(const Duration(days: 2));
      await db
          .into(db.workoutsTable)
          .insert(
            WorkoutsTableCompanion.insert(
              id: 'w-1',
              name: 'Training',
              startedAt: at.millisecondsSinceEpoch,
              endedAt: Value(
                at.add(const Duration(hours: 1)).millisecondsSinceEpoch,
              ),
            ),
          );
    });
    await pump(tester, layout: defaultHomeLayout(), size: const Size(360, 400));
    await tester.pumpAndSettle();
    expect(find.text('Nog geen back-up'), findsOneWidget);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final bottom = position.pixels;
    expect(bottom, greaterThan(600), reason: 'a page to scroll back up');

    // Back up a hundred at a time: the banner came back empty while its
    // numbers loaded again, and the page jumped to the top.
    for (var to = bottom - 100; to > 0; to -= 100) {
      position.jumpTo(to);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(position.pixels, closeTo(to, 1), reason: 'back up to $to');
    }
    expect(find.text('Nog geen back-up'), findsOneWidget);
  });
}
