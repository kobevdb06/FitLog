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

/// The Start tab built from the user's own list of blocks.
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
  }) async {
    tester.view.physicalSize = const Size(1100, 2400);
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
        suggestedRoutineProvider.overrideWith((ref) async => null),
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
    await pump(tester, layout: defaultHomeLayout);

    expect(find.text(weekHeader), findsOneWidget);
    expect(find.text(volumeHeader), findsOneWidget);
  });

  testWidgets('a block you switched off is not built', (tester) async {
    await pump(
      tester,
      layout: defaultHomeLayout.withVisible(HomeBlock.week, visible: false),
    );

    expect(find.text(weekHeader), findsNothing);
    expect(find.text(volumeHeader), findsOneWidget);
  });

  testWidgets('by default the week comes before the volume', (tester) async {
    await pump(tester, layout: defaultHomeLayout);

    expect(
      tester.getTopLeft(find.text(weekHeader)).dy,
      lessThan(tester.getTopLeft(find.text(volumeHeader)).dy),
    );
  });

  testWidgets('and dragging the volume up puts it above', (tester) async {
    final moved = defaultHomeLayout.reordered(
      defaultHomeLayout.blocks.indexOf(HomeBlock.volume),
      0,
    );

    await pump(tester, layout: moved);

    expect(
      tester.getTopLeft(find.text(volumeHeader)).dy,
      lessThan(tester.getTopLeft(find.text(weekHeader)).dy),
    );
  });

  testWidgets('switching every block off says so rather than showing a blank', (
    tester,
  ) async {
    var layout = defaultHomeLayout;
    for (final block in HomeBlock.values) {
      layout = layout.withVisible(block, visible: false);
    }

    await pump(tester, layout: layout);

    expect(find.text('Je startscherm is leeg'), findsOneWidget);
    expect(find.text('Startscherm indelen'), findsOneWidget);
  });

  group('the favourites block', () {
    testWidgets('sits next to a schedule when you switch it on', (
      tester,
    ) async {
      await pump(
        tester,
        layout: defaultHomeLayout.withVisible(
          HomeBlock.favourites,
          visible: true,
        ),
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
        layout: defaultHomeLayout.withVisible(
          HomeBlock.favourites,
          visible: true,
        ),
        favourites: [routine('Arms')],
      );

      expect(find.text('Je favorieten'), findsOneWidget);
      expect(find.text('FAVORIETEN'), findsNothing);
    });

    testWidgets('but not when you switched Vandaag off', (tester) async {
      await pump(
        tester,
        layout: defaultHomeLayout
            .withVisible(HomeBlock.favourites, visible: true)
            .withVisible(HomeBlock.today, visible: false),
        favourites: [routine('Arms')],
      );

      expect(find.text('Je favorieten'), findsNothing);
      expect(find.text('FAVORIETEN'), findsOneWidget);
    });

    testWidgets('and stays away when nothing is starred', (tester) async {
      await pump(
        tester,
        layout: defaultHomeLayout.withVisible(
          HomeBlock.favourites,
          visible: true,
        ),
        scheduled: [routine('Chest day 2', days: everyDay())],
      );

      expect(find.text('FAVORIETEN'), findsNothing);
    });
  });
}
