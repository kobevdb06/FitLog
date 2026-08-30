import 'dart:io';

import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/core/widgets/exercise_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

/// An exercise the user made has no bundled asset, so its two photos are the
/// animation: the loop is driven in Dart instead of by the image decoder, on
/// the same beat as the catalogue's animated WebPs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late Directory root;
  late AppPaths paths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fitlog_frames_widget');
    paths = AppPaths(root);
    await paths.ensurePhotosDirectory();
    for (final entry in {'start.jpg': 40, 'end.jpg': 200}.entries) {
      final image = img.Image(width: 60, height: 80);
      img.fill(image, color: img.ColorRgb8(entry.value, 30, 30));
      paths.photoFile(entry.key).writeAsBytesSync(img.encodeJpg(image));
    }
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  ExerciseRow exercise({String? start, String? end}) => ExerciseRow(
    id: 'own-1',
    name: 'Kabel curl schuin',
    primaryMuscle: 'biceps',
    secondaryMuscles: '[]',
    equipment: null,
    category: 'cable',
    instructions: null,
    imageAsset: null,
    startImageFile: start,
    endImageFile: end,
    isCustom: true,
    isArchived: false,
    createdAt: 0,
  );

  int frameOf(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

  group('the animation', () {
    Future<void> pumpAnimation(
      WidgetTester tester, {
      String? start = 'start.jpg',
      String? end = 'end.jpg',
    }) {
      // In a list, the way the detail screen shows it. Handed the whole
      // screen instead, the Stack inside would fill it and the tap would land
      // in the empty half below the picture.
      return tester.pumpWidget(
        wrapForTest(
          ListView(
            children: [
              ExerciseAnimation(
                exercise: exercise(start: start, end: end),
                manifest: const ExerciseImageManifest.empty(),
                paths: paths,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('alternates between the two frames', (tester) async {
      await pumpAnimation(tester);
      expect(frameOf(tester), 0);

      await tester.pump(ExerciseAnimation.frameDuration);
      expect(frameOf(tester), 1);

      await tester.pump(ExerciseAnimation.frameDuration);
      expect(frameOf(tester), 0, reason: 'it loops rather than stopping');
    });

    testWidgets('a tap holds it on the frame that is showing', (tester) async {
      await pumpAnimation(tester);
      await tester.pump(ExerciseAnimation.frameDuration);
      expect(frameOf(tester), 1);

      await tester.tap(find.byType(ExerciseAnimation));
      await tester.pump();
      expect(find.text('Gepauzeerd'), findsOneWidget);

      await tester.pump(ExerciseAnimation.frameDuration * 3);
      expect(frameOf(tester), 1);

      await tester.tap(find.byType(ExerciseAnimation));
      await tester.pump(ExerciseAnimation.frameDuration);
      expect(frameOf(tester), 0, reason: 'tapping again lets it run on');
    });

    testWidgets('one photo is a still picture, not a loop', (tester) async {
      await pumpAnimation(tester, end: null);

      expect(find.text('Tik om te pauzeren'), findsNothing);
      await tester.pump(ExerciseAnimation.frameDuration * 2);
      expect(frameOf(tester), 0);
    });

    testWidgets('without photos it falls back to the badge', (tester) async {
      await pumpAnimation(tester, start: null, end: null);

      expect(find.byType(IndexedStack), findsNothing);
      expect(find.byType(MuscleAvatar), findsOneWidget);
    });
  });

  group('the thumbnail', () {
    testWidgets('shows the start position', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          Center(
            child: ExerciseThumb(
              exercise: exercise(start: 'start.jpg', end: 'end.jpg'),
              manifest: const ExerciseImageManifest.empty(),
              paths: paths,
            ),
          ),
        ),
      );

      final provider = tester.widget<Image>(find.byType(Image)).image;
      final file = (provider as ResizeImage).imageProvider as FileImage;
      expect(file.file.path, paths.photoFile('start.jpg').path);
    });

    testWidgets('falls back to the badge without photos', (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          Center(
            child: ExerciseThumb(
              exercise: exercise(),
              manifest: const ExerciseImageManifest.empty(),
              paths: paths,
            ),
          ),
        ),
      );

      expect(find.byType(MuscleAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
