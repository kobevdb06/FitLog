import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/dashboard/data/back_gesture.dart';
import 'package:fitlog/features/dashboard/domain/home_layout.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/dashboard/presentation/home_grid.dart';
import 'package:fitlog/features/dashboard/presentation/today_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Arranging the Start tab the way a phone's home screen is arranged: hold a
/// block and move it, drag its edges to size it, and nothing ever shifts on
/// its own.
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

  const width = 1100.0;

  /// One cell across and one row down, on the test screen: the grid has the
  /// width minus its two margins, and rows are 56 high at normal text.
  const stepX = (width - 2 * kHomeInset - 3 * kHomeGap) / 4 + kHomeGap;
  const stepY = kHomeRowHeight + kHomeGap;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(width, 2400),
    List<RoutineRow> favourites = const [],
    List<RoutineRow> scheduled = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
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
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// What the database says the layout is, which is what survives a restart.
  Future<HomeLayout> stored() async =>
      parseHomeLayout((await db.settingsDao.getSettings()).homeLayout);

  Future<void> store(HomeLayout layout) => db.settingsDao.updateSettings(
    AppSettingsTableCompanion(homeLayout: Value(encodeHomeLayout(layout))),
  );

  Future<void> arrange(WidgetTester tester) async {
    await tester.longPress(find.text('DEZE WEEK'));
    await settle(tester);
  }

  /// A finger on [finder]: held until the block is picked up, moved [by] in
  /// small steps, and let go.
  Future<void> holdAndMove(
    WidgetTester tester,
    Finder finder,
    Offset by,
  ) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(kHomeHold + const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(by / 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);
  }

  testWidgets('een blok vasthouden begint het indelen, en Klaar stopt het', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Indelen'), findsNothing);

    await arrange(tester);
    expect(find.text('Indelen'), findsOneWidget);
    expect(find.textContaining('Houd een blok vast'), findsOneWidget);

    await tester.tap(find.text('Klaar'));
    await settle(tester);
    expect(find.text('Indelen'), findsNothing);
  });

  testWidgets('en niets wiebelt: het scherm komt tot rust', (tester) async {
    await pump(tester);
    await arrange(tester);

    // A block that kept leaning would keep asking for frames, and this would
    // never return.
    await tester.pumpAndSettle();
    expect(find.text('Indelen'), findsOneWidget);
  });

  testWidgets('verslepen naar een lege plek: de oude plek blijft leeg en '
      'niets anders beweegt', (tester) async {
    await pump(tester);
    final before = await stored();

    // Deze week, at rows 3 and 4, down into the empty rows under Volume.
    await holdAndMove(
      tester,
      find.text('DEZE WEEK'),
      const Offset(0, 11 * stepY),
    );

    final after = await stored();
    expect(after.spotOf(HomeBlock.week), const HomeSpot(0, 14, 4, 2));
    for (final block in [
      HomeBlock.today,
      HomeBlock.recovery,
      HomeBlock.records,
      HomeBlock.volume,
    ]) {
      expect(after.spotOf(block), before.spotOf(block), reason: '$block');
    }
    // The two rows it left are still empty.
    expect(after.fits(HomeBlock.week, const HomeSpot(0, 3, 4, 2)), isTrue);
  });

  testWidgets('op een blok van dezelfde grootte wisselen ze van plaats', (
    tester,
  ) async {
    await pump(tester);

    // Records (rows 8 to 10) onto Herstel (rows 5 to 7): both four by three.
    await holdAndMove(
      tester,
      find.text('LAATSTE RECORDS'),
      const Offset(0, -3 * stepY),
    );

    final after = await stored();
    expect(after.spotOf(HomeBlock.records), const HomeSpot(0, 5, 4, 3));
    expect(after.spotOf(HomeBlock.recovery), const HomeSpot(0, 8, 4, 3));
  });

  testWidgets('en dat zie je voor je loslaat: het andere blok staat al op de '
      'plek die het zou krijgen', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('LAATSTE RECORDS')),
    );
    await tester.pump(kHomeHold + const Duration(milliseconds: 50));
    // Where it was, now that arranging has started and the bar is above.
    final records = tester.getRect(find.byKey(const ValueKey('blok-records')));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -3 * stepY / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Wisselen'), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('blok-herstel'))), records);

    await gesture.up();
    await settle(tester);
  });

  testWidgets('waar een blok van een andere grootte staat: terug naar zijn '
      'plek', (tester) async {
    await pump(tester);
    final before = await stored();

    // Deze week (four by two) over Herstel (four by three).
    await holdAndMove(
      tester,
      find.text('DEZE WEEK'),
      const Offset(0, 2 * stepY),
    );

    expect((await stored()).spots, before.spots);
  });

  testWidgets('tik op een blok en sleep de rechterrand: het wordt smaller', (
    tester,
  ) async {
    await pump(tester);
    await arrange(tester);

    await tester.tap(find.byKey(const ValueKey('blok-deze-week')));
    await settle(tester);
    expect(find.byKey(const ValueKey('rand-deze-week-right')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('rand-deze-week-right')),
      const Offset(-2 * stepX, 0),
    );
    await settle(tester);

    expect((await stored()).spotOf(HomeBlock.week), const HomeSpot(0, 3, 2, 2));
  });

  testWidgets('en de onderrand naar beneden: hoger, tot tegen Herstel', (
    tester,
  ) async {
    await store(
      const HomeLayout({
        HomeBlock.today: HomeSpot(0, 0, 4, 3),
        HomeBlock.week: HomeSpot(0, 3, 2, 2),
        HomeBlock.recovery: HomeSpot(0, 6, 4, 3),
      }),
    );
    await pump(tester);
    await arrange(tester);
    await tester.tap(find.byKey(const ValueKey('blok-deze-week')));
    await settle(tester);

    await tester.drag(
      find.byKey(const ValueKey('rand-deze-week-bottom')),
      const Offset(0, 4 * stepY),
    );
    await settle(tester);

    // Rows 3 to 5: Herstel starts at row 6.
    expect((await stored()).spotOf(HomeBlock.week), const HomeSpot(0, 3, 2, 3));
  });

  testWidgets('waar de zijbolletjes staan, blijft de terug-veeg van Android '
      'weg, tot het indelen stopt', (tester) async {
    final kept = <List<Object?>>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(BackGesture.channel, (call) async {
      kept.add(call.arguments as List<Object?>);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(BackGesture.channel, null),
    );
    List<double> edges(String key) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      return [rect.left, rect.top, rect.right, rect.bottom];
    }

    await pump(tester, size: const Size(width, 900));
    await arrange(tester);
    expect(kept, isEmpty);

    await tester.tap(find.byKey(const ValueKey('blok-deze-week')));
    await settle(tester);
    expect(kept.last, [
      edges('rand-deze-week-left'),
      edges('rand-deze-week-right'),
    ]);

    // The page scrolls, and the handles with it.
    final page = tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('startscherm-raster')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    page.position.jumpTo(100);
    await tester.pump();
    expect(kept.last, [
      edges('rand-deze-week-left'),
      edges('rand-deze-week-right'),
    ]);

    page.position.jumpTo(0);
    await tester.pump();
    await tester.tap(find.text('Klaar'));
    await settle(tester);
    expect(kept.last, isEmpty);
  });

  testWidgets('het kruisje haalt een blok weg, de plek blijft leeg, en de '
      'chip zet het terug', (tester) async {
    await pump(tester);
    await arrange(tester);
    await tester.tap(find.byKey(const ValueKey('blok-deze-week')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('weg-deze-week')));
    await settle(tester);

    var layout = await stored();
    expect(layout.shows(HomeBlock.week), isFalse);
    expect(layout.spotOf(HomeBlock.recovery), const HomeSpot(0, 5, 4, 3));

    await tester.tap(find.widgetWithText(ActionChip, 'Deze week'));
    await settle(tester);

    layout = await stored();
    expect(layout.spotOf(HomeBlock.week), const HomeSpot(0, 3, 4, 2));
  });

  testWidgets('een blok uit de chips dat onder het scherm belandt: het scherm '
      'gaat erheen, en het heeft al zijn randen', (tester) async {
    await store(defaultHomeLayout().without(HomeBlock.volume));
    await pump(tester, size: const Size(width, 900));
    await arrange(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Volume'));
    await settle(tester);

    expect(
      (await stored()).spotOf(HomeBlock.volume),
      const HomeSpot(0, 11, 4, 3),
    );
    // The page on its way down.
    await settle(tester);
    final volume = tester.getRect(find.byKey(const ValueKey('blok-volume')));
    expect(volume.bottom, lessThanOrEqualTo(900));
    expect(volume.top, greaterThanOrEqualTo(0));
    expect(find.byKey(const ValueKey('rand-volume-bottom')), findsOneWidget);
  });

  testWidgets('een chip slepen tot onderaan het scherm: de pagina scrolt mee', (
    tester,
  ) async {
    await store(defaultHomeLayout().without(HomeBlock.volume));
    await pump(tester, size: const Size(width, 900));
    await arrange(tester);
    final page = tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('startscherm-raster')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.widgetWithText(ActionChip, 'Volume')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // Down to just above the bottom of the screen, and held there.
    for (var i = 0; i < 20; i++) {
      await gesture.moveTo(Offset(width / 2, 300 + i * 29.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(page.position.pixels, greaterThan(0));

    await gesture.up();
    await settle(tester);
    // Below Records, which ends at row 11, and no further than the last of
    // the two spare rows: held at the edge, the page stops where the grid
    // does.
    final volume = (await stored()).spotOf(HomeBlock.volume);
    expect(volume, isNotNull);
    expect(volume!.y, inInclusiveRange(11, 12));
  });

  testWidgets('een leeg blok verdwijnt niet, het zegt wat er is', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('HERSTEL'), findsOneWidget);
    expect(find.text('Nog niets om van te herstellen.'), findsOneWidget);
    expect(find.text('Nog geen records.'), findsOneWidget);
  });

  testWidgets('Instellingen kan je hierheen sturen om in te delen', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Indelen'), findsNothing);

    container!.read(homeArrangeRequestProvider.notifier).ask();
    await settle(tester);

    expect(find.text('Indelen'), findsOneWidget);
    expect(container!.read(homeArrangeRequestProvider), isFalse);
  });

  testWidgets('Standaard zet alles terug zoals het kwam', (tester) async {
    await store(
      defaultHomeLayout()
          .moved(HomeBlock.week, 0, 20)
          .without(HomeBlock.volume),
    );
    await pump(tester);
    await arrange(tester);

    await tester.tap(find.text('Standaard'));
    await settle(tester);

    expect((await stored()).spots, defaultHomeLayout().spots);
  });

  testWidgets('buiten het indelen zijn er geen randen en geen kruisjes', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byKey(const ValueKey('rand-deze-week-right')), findsNothing);
  });

  testWidgets('elk blok past op elke maat die het mag hebben, op een smalle '
      'gsm met grote letters', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    await db.settingsDao.updateSettings(
      const AppSettingsTableCompanion(healthConnectEnabled: Value(true)),
    );
    RoutineRow routine(String name, int days) => RoutineRow(
      planState: 'approved',
      id: name,
      name: name,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      isFavourite: true,
      scheduledDays: days,
    );
    final everyDay = WeekdaySet.of([for (var d = 1; d <= 7; d++) d]).mask;

    for (final block in HomeBlock.values) {
      final sizes = block.sizes;
      for (var w = sizes.minW; w <= sizes.maxW; w++) {
        for (var h = sizes.minH; h <= sizes.maxH; h++) {
          await store(HomeLayout({block: HomeSpot(0, 0, w, h)}));
          await pump(
            tester,
            size: const Size(360, 900),
            favourites: [
              routine('Push A met een lange naam', 0),
              routine('Pull B', 0),
              routine('Benen', 0),
            ],
            scheduled: [
              routine('Push A met een lange naam', everyDay),
              routine('Pull B', everyDay),
            ],
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${block.wire} op $w × $h',
          );
          // Put away after the test, as tearDown does with the last one:
          // closing a container mid-test leaves the database's timers behind.
          final done = container!;
          addTearDown(done.dispose);
          container = null;
        }
      }
    }
    // The last screen goes too, and what it left to tidy up runs.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
