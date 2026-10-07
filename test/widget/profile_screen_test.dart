import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/features/settings/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The Profiel tab.
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithContainer(container, const ProfileScreen()),
    );
    await tester.pumpAndSettle();
  }

  /// The value above [label] in the totals.
  String tile(WidgetTester tester, String label) {
    final column = find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    );
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: column.first, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .toList();
    return texts.first!;
  }

  testWidgets('zonder trainingen geen "0 s" in de zaal', (tester) async {
    await pump(tester);

    expect(tile(tester, 'Tijd in de zaal'), '-');
    expect(find.text('0 s'), findsNothing);
  });
}
