import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/core/widgets/dialogs.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/features/routines/presentation/routine_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The last three Material dropdowns in the app, and what replaced them.
///
/// Every one of them was a grey slab over the page in a style nothing else here
/// uses. Two are ordinary choices in a form; the third sits under a photograph,
/// where a date and a pose never told you which picture you were about to get.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Nothing is read from disk here; every Image.file falls back to the
        // placeholder, which is what a missing photo does in the app too.
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(PickerField));

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapWithContainer(container, screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('no dropdown is left anywhere in the routine editor', (
    tester,
  ) async {
    await db.routinesDao.createFolder('Push Pull Legs');
    await pump(tester, const RoutineEditorScreen());

    expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    expect(field('Map'), findsOneWidget);
  });

  group('the folder', () {
    setUp(() async {
      await db.routinesDao.createFolder('Push Pull Legs');
    });

    testWidgets('starts at the top level and says so', (tester) async {
      await pump(tester, const RoutineEditorScreen());

      expect(
        find.descendant(of: field('Map'), matching: find.text('Geen map')),
        findsOneWidget,
      );
    });

    testWidgets('and moves into the one you pick', (tester) async {
      await pump(tester, const RoutineEditorScreen());

      await tester.tap(field('Map'));
      await tester.pumpAndSettle();
      expect(find.text('In welke map?'), findsOneWidget);

      await tester.tap(find.text('Push Pull Legs').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: field('Map'),
          matching: find.text('Push Pull Legs'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and back out again, which is a choice, not a cancel', (
      tester,
    ) async {
      // "Geen map" has to be reachable: closing the sheet means "never mind",
      // and those two cannot be the same answer.
      await pump(tester, const RoutineEditorScreen());

      await tester.tap(field('Map'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push Pull Legs').last);
      await tester.pumpAndSettle();

      await tester.tap(field('Map'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geen map').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: field('Map'), matching: find.text('Geen map')),
        findsOneWidget,
      );
    });
  });

  group('the sex on the profile step', () {
    // The step itself sits behind the whole onboarding flow, so the sheet is
    // driven directly. That no dropdown is left on that screen is covered by
    // the sweep at the bottom of this file.
    testWidgets('offers the four answers and hands one back', (tester) async {
      Sex? chosen;

      await tester.pumpWidget(
        wrapForTest(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await pickSex(context, current: null);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Geslacht'), findsOneWidget);
      for (final sex in Sex.values) {
        expect(find.text(sex.label), findsOneWidget);
      }

      await tester.tap(find.text('Liever niet zeggen'));
      await tester.pumpAndSettle();

      expect(chosen, Sex.undisclosed);
    });
  });

  // The comparison screen used to carry a dropdown under each photo. It has
  // no picker at all now - you choose the pictures in the grid - so what was
  // tested here lives in photos_test.dart, and no_dropdowns_test.dart still
  // guards the shape of the whole of lib/.
}
