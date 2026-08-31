import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/history/presentation/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The month grid was a picture. Tapping a day now filters the list under it,
/// which is the only way a history of a few hundred sessions stays usable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A finished session on [at]. Written straight to the table: the controller
  /// always starts one at the current moment, and these need to sit on
  /// different days of this month.
  Future<void> session(String name, DateTime at) async {
    await db
        .into(db.workoutsTable)
        .insert(
          WorkoutsTableCompanion.insert(
            id: 'w-${at.day}-$name',
            name: name,
            startedAt: at.millisecondsSinceEpoch,
            endedAt: Value(
              at.add(const Duration(hours: 1)).millisecondsSinceEpoch,
            ),
            totalVolumeKg: const Value(1000),
            totalSets: const Value(10),
          ),
        );
  }

  /// Two days in the current month that are not today, so the calendar shows
  /// them both without scrolling to another month.
  final now = DateTime.now();
  final first = DateTime(now.year, now.month, 4, 18);
  final second = DateTime(now.year, now.month, 12, 18);

  Future<void> pump(WidgetTester tester) async {
    // A tall window, because the month grid fills the default one on its own
    // and a ListView does not build what is below the fold.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithContainer(container, const HistoryScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('everything shows until a day is picked', (tester) async {
    await session('Push A', first);
    await session('Benen', second);
    await pump(tester);

    expect(find.text('SESSIES'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Benen'), findsOneWidget);
  });

  testWidgets('tapping a day leaves only that day', (tester) async {
    await session('Push A', first);
    await session('Benen', second);
    await pump(tester);

    await tester.tap(find.text('${first.day}'));
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Benen'), findsNothing);
    expect(find.text('SESSIES'), findsNothing);
  });

  testWidgets('tapping it again brings the rest back', (tester) async {
    await session('Push A', first);
    await session('Benen', second);
    await pump(tester);

    await tester.tap(find.text('${first.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${first.day}'));
    await tester.pumpAndSettle();

    expect(find.text('Benen'), findsOneWidget);
    expect(find.text('SESSIES'), findsOneWidget);
  });

  testWidgets('so does the button next to the date', (tester) async {
    await session('Push A', first);
    await session('Benen', second);
    await pump(tester);

    await tester.tap(find.text('${first.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alles'));
    await tester.pumpAndSettle();

    expect(find.text('Benen'), findsOneWidget);
  });

  testWidgets('two sessions on one day both stay', (tester) async {
    await session('Ochtend', first);
    await session('Avond', first.add(const Duration(hours: 4)));
    await session('Benen', second);
    await pump(tester);

    await tester.tap(find.text('${first.day}'));
    await tester.pumpAndSettle();

    expect(find.text('Ochtend'), findsOneWidget);
    expect(find.text('Avond'), findsOneWidget);
    expect(find.text('Benen'), findsNothing);
  });

  testWidgets('a day without a session does not respond', (tester) async {
    await session('Push A', first);
    await pump(tester);

    // A day that has nothing on it: tapping it must not empty the list.
    final empty = first.day == 6 ? 7 : 6;
    await tester.tap(find.text('$empty'));
    await tester.pumpAndSettle();

    expect(find.text('SESSIES'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
  });

  testWidgets('changing month lets go of the day', (tester) async {
    await session('Push A', first);
    await session('Benen', second);
    await pump(tester);

    await tester.tap(find.text('${first.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(
      find.text('SESSIES'),
      findsOneWidget,
      reason: 'a day in a month you are not looking at is not a filter',
    );
  });
}
