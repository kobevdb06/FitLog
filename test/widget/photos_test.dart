import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/photos/presentation/photo_compare_screen.dart';
import 'package:fitlog/features/photos/presentation/photo_wipe.dart';
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

  /// The tile a tick or a circle sits on.
  ///
  /// The mark itself is drawn on top and handles nothing; the tap belongs to
  /// the tile underneath it, and aiming at the mark makes the test warn that
  /// it hit something else.
  Finder tileOf(Finder mark) =>
      find.ancestor(of: mark, matching: find.byType(GestureDetector)).first;

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

  group('choosing what to compare', () {
    testWidgets('starts from the two newest of your usual pose', (
      tester,
    ) async {
      // The screen used to make exactly this comparison for you. Now it is a
      // starting point you can change rather than the only answer.
      await photo(at: DateTime(2026, 9, 1), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 7), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.back);
      await pump(tester, const PhotosScreen());

      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pumpAndSettle();

      expect(find.text('Kies foto\'s'), findsOneWidget);
      expect(find.text('Vergelijk (2)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });

    testWidgets('a tap adds one and a second tap takes it away', (
      tester,
    ) async {
      await photo(at: DateTime(2026, 9, 1), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 7), pose: PhotoPose.back);
      await pump(tester, const PhotosScreen());

      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pumpAndSettle();

      await tester.tap(tileOf(find.byIcon(Icons.radio_button_unchecked)));
      await tester.pumpAndSettle();
      expect(find.text('Vergelijk (3)'), findsOneWidget);

      await tester.tap(tileOf(find.byIcon(Icons.check_circle).first));
      await tester.pumpAndSettle();
      expect(find.text('Vergelijk (2)'), findsOneWidget);
    });

    testWidgets('and stops at four', (tester) async {
      // Beyond four each picture is a postage stamp and the comparison stops
      // being one.
      // One day, so all six tiles are on screen and every tap can land.
      for (var hour = 8; hour < 14; hour++) {
        await photo(at: DateTime(2026, 9, 7, hour), pose: PhotoPose.front);
      }
      await pump(tester, const PhotosScreen());

      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pumpAndSettle();

      // Two are ticked already, so four more taps try to make it six.
      for (var extra = 0; extra < 4; extra++) {
        await tester.tap(tileOf(find.byIcon(Icons.radio_button_unchecked)));
        await tester.pumpAndSettle();
      }

      expect(find.text('Vergelijk (4)'), findsOneWidget);
      expect(find.text('Hoogstens 4 foto\'s tegelijk.'), findsOneWidget);
    });

    testWidgets('leaving the choosing puts the photo back on a tap', (
      tester,
    ) async {
      await photo(at: DateTime(2026, 9, 1), pose: PhotoPose.front);
      await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.front);
      await pump(tester, const PhotosScreen());

      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Vergelijk (2)'), findsNothing);
      await tester.tap(tileOf(find.text('Voorkant').first));
      await tester.pumpAndSettle();
      expect(find.text('Bewerken'), findsOneWidget);
    });
  });

  group('the comparison itself', () {
    Future<void> compare(WidgetTester tester, List<String> ids) =>
        pump(tester, PhotoCompareScreen(photoIds: ids));

    testWidgets('shows the ones you picked, oldest first', (tester) async {
      // The ids arrive in the order you tapped them; the pictures belong in
      // the order they were taken.
      final newest = await photo(at: DateTime(2026, 9, 13));
      final oldest = await photo(at: DateTime(2026, 9, 1));

      await compare(tester, [newest, oldest]);

      expect(
        tester.getTopLeft(find.text('1 sep 2026')).dx,
        lessThan(tester.getTopLeft(find.text('13 sep 2026')).dx),
      );
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('whole, never cut down to fit', (tester) async {
      // Half a screen is a narrow window on a portrait photo: filling it cuts
      // the sides off, and off-centre subjects disappear with them.
      final a = await photo(at: DateTime(2026, 9, 1));
      final b = await photo(at: DateTime(2026, 9, 13));

      await compare(tester, [a, b]);

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, hasLength(2));
      for (final image in images) {
        expect(image.fit, BoxFit.contain);
      }
    });

    testWidgets('an id of a photo that is gone is simply not there', (
      tester,
    ) async {
      final a = await photo(at: DateTime(2026, 9, 1));
      final b = await photo(at: DateTime(2026, 9, 13));

      await compare(tester, [a, 'weg', b]);

      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('and one photo is not a comparison', (tester) async {
      final a = await photo(at: DateTime(2026, 9, 1));

      await compare(tester, [a]);

      expect(find.text('Te weinig foto\'s'), findsOneWidget);
    });

    testWidgets('mixed poses are said out loud, not refused', (tester) async {
      final front = await photo(at: DateTime(2026, 9, 1));
      final back = await photo(at: DateTime(2026, 9, 13), pose: PhotoPose.back);

      await compare(tester, [front, back]);

      expect(
        find.text('Je vergelijkt Voorkant met Achterkant.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('the same pose twice says nothing', (tester) async {
      final a = await photo(at: DateTime(2026, 9, 1));
      final b = await photo(at: DateTime(2026, 9, 13));

      await compare(tester, [a, b]);

      expect(find.textContaining('Je vergelijkt'), findsNothing);
    });
  });

  group('the wipe', () {
    testWidgets('is offered for a pair and swaps the layout', (tester) async {
      final a = await photo(at: DateTime(2026, 9, 1));
      final b = await photo(at: DateTime(2026, 9, 13));

      await pump(tester, PhotoCompareScreen(photoIds: [a, b]));
      expect(find.byType(PhotoWipe), findsNothing);

      await tester.tap(find.byTooltip('Over elkaar schuiven'));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoWipe), findsOneWidget);
      // Both pictures in one frame, each on the full width.
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('and not for three, where there is no seam to drag', (
      tester,
    ) async {
      final a = await photo(at: DateTime(2026, 9, 1));
      final b = await photo(at: DateTime(2026, 9, 7));
      final c = await photo(at: DateTime(2026, 9, 13));

      await pump(tester, PhotoCompareScreen(photoIds: [a, b, c]));

      expect(find.byTooltip('Over elkaar schuiven'), findsNothing);
      expect(find.byType(Image), findsNWidgets(3));
    });
  });
}
