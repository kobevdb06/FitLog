import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/features/dashboard/domain/home_layout.dart';
import 'package:fitlog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitlog/features/dashboard/presentation/today_providers.dart';
import 'package:fitlog/features/routines/presentation/routine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Arranging the Start tab with your finger.
///
/// It used to be a list of switches on a settings screen: you dragged the word
/// "Deze week" above the word "Herstel" and found out what that looked like
/// afterwards. Here you move the blocks themselves.
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        scheduledRoutinesProvider.overrideWith((ref) => Stream.value(const [])),
        favouriteRoutinesProvider.overrideWith((ref) => Stream.value(const [])),
        suggestedRoutineProvider.overrideWith((ref) async => null),
      ],
    );

    await tester.pumpWidget(
      wrapWithContainer(container!, const DashboardScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// What the database says the layout is, which is what survives a restart.
  Future<HomeLayout> stored() async =>
      parseHomeLayout((await db.settingsDao.getSettings()).homeLayout);

  /// The card a title sits in, which is what has the block's width.
  Finder cardOf(WidgetTester tester, String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(AppCard)).first;

  Future<void> arrange(WidgetTester tester) async {
    await tester.longPress(find.text('DEZE WEEK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('holding a block starts arranging, and Klaar ends it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Indelen'), findsNothing);

    await arrange(tester);
    expect(find.text('Indelen'), findsOneWidget);
    expect(
      find.text('Sleep om te verplaatsen, tik om groot of klein te maken.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Klaar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Indelen'), findsNothing);
  });

  testWidgets('a tap while arranging halves a block, and again widens it', (
    tester,
  ) async {
    await pump(tester);
    await arrange(tester);

    await tester.tap(find.byKey(const ValueKey('formaat-deze-week')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect((await stored()).sizeOf(HomeBlock.week), HomeBlockSize.small);

    await tester.tap(find.byKey(const ValueKey('formaat-deze-week')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect((await stored()).sizeOf(HomeBlock.week), HomeBlockSize.wide);
  });

  testWidgets('a small block really is narrower on screen', (tester) async {
    await pump(tester);
    final wide = tester.getSize(cardOf(tester, 'DEZE WEEK'));

    await arrange(tester);
    await tester.tap(find.byKey(const ValueKey('formaat-deze-week')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final small = tester.getSize(cardOf(tester, 'DEZE WEEK'));

    expect(small.width, lessThan(wide.width * 0.6));
  });

  testWidgets('the cross takes a block off the screen, and a chip brings it '
      'back', (tester) async {
    await pump(tester);
    await arrange(tester);

    expect(find.text('DEZE WEEK'), findsOneWidget);
    // Every block has a cross of its own, keyed by the block it belongs to.
    await tester.tap(find.byKey(const ValueKey('verberg-deze-week')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DEZE WEEK'), findsNothing);
    expect((await stored()).shows(HomeBlock.week), isFalse);

    // Hidden blocks have no place on the grid to drag them out of, so they
    // wait as chips at the top.
    await tester.tap(find.widgetWithText(ActionChip, 'Deze week'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect((await stored()).shows(HomeBlock.week), isTrue);
  });

  testWidgets('nothing is arrangeable while you are not arranging', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(Draggable<HomeBlock>), findsNothing);
  });
}
