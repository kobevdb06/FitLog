import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/photos/presentation/photo_compare_screen.dart';
import 'package:fitlog/features/photos/presentation/photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Looking at a progress photo, which used to be impossible.
///
/// A tap did nothing at all; only a long press did something, and that was
/// deleting it. The grid also stacked a whole month into one heading with the
/// date repeated on every tile.
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
        // No bytes on disk: every Image.file falls back to the placeholder,
        // which is what a missing photo does in the app too.
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> photo({
    required DateTime at,
    PhotoPose pose = PhotoPose.front,
    String? note,
  }) => db.recordsDao.addPhoto(
    fileName: '${at.millisecondsSinceEpoch}-${pose.wire}.jpg',
    pose: pose,
    takenAt: at,
    note: note,
  );

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapWithContainer(container, screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the grid', () {
    testWidgets('splits a month into its days', (tester) async {
      await photo(at: DateTime(2026, 9, 13, 10));
      await photo(at: DateTime(2026, 9, 7, 10));
      await pump(tester, const PhotosScreen());

      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('zondag 13 september'), findsOneWidget);
      expect(find.text('maandag 7 september'), findsOneWidget);
    });

    testWidgets('and stops writing the date on every tile', (tester) async {
      // The heading above the tiles already says it, once per group.
      await photo(at: DateTime(2026, 9, 7, 10));
      await pump(tester, const PhotosScreen());

      expect(find.text('7 sep 2026'), findsNothing);
      expect(find.text('Voorkant'), findsOneWidget);
    });
  });

  group('tapping a photo', () {
    testWidgets('opens it, with what you wrote about it', (tester) async {
      await photo(at: DateTime(2026, 9, 7, 10), note: 'ochtend, nuchter');
      await pump(tester, const PhotosScreen());

      await tester.tap(find.text('Voorkant'));
      await tester.pumpAndSettle();

      expect(find.text('7 september 2026'), findsOneWidget);
      expect(find.text('ochtend, nuchter'), findsOneWidget);
      expect(find.text('Bewerken'), findsOneWidget);
    });

    testWidgets('and the tile says there is a note behind it', (tester) async {
      await photo(at: DateTime(2026, 9, 7, 10), note: 'iets');
      await pump(tester, const PhotosScreen());

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    });

    testWidgets('which it does not when there is none', (tester) async {
      await photo(at: DateTime(2026, 9, 7, 10));
      await pump(tester, const PhotosScreen());

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });
  });

  group('comparing', () {
    testWidgets('is a pose, not two arbitrary pictures', (tester) async {
      // A front against a back has nothing to say, and the screen used to let
      // you build exactly that.
      await photo(at: DateTime(2026, 9, 1), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.front);
      await pump(tester, const PhotoCompareScreen());

      expect(find.text('Voorkant (2)'), findsOneWidget);
      expect(find.text('Achterkant (0)'), findsOneWidget);
      expect(find.text('1 sep 2026'), findsOneWidget);
      expect(find.text('13 sep 2026'), findsOneWidget);
    });

    testWidgets('opens on the pose you have most of', (tester) async {
      await photo(at: DateTime(2026, 9, 1), pose: PhotoPose.back);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.back);
      await photo(at: DateTime(2026, 9, 7), pose: PhotoPose.front);
      await pump(tester, const PhotoCompareScreen());

      expect(find.text('Te weinig van deze pose'), findsNothing);
      expect(find.text('7 sep 2026'), findsNothing);
    });

    testWidgets('and says so when a pose has too few', (tester) async {
      await photo(at: DateTime(2026, 9, 1), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.front);
      await pump(tester, const PhotoCompareScreen());

      await tester.tap(find.text('Zijkant (0)'));
      await tester.pumpAndSettle();

      expect(find.text('Te weinig van deze pose'), findsOneWidget);
    });
  });
}
