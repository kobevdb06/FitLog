import 'dart:io';

import 'package:fitlog/core/theme/app_colors.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:fitlog/core/widgets/fitlog_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'helpers.dart';

/// The app shipped with the stock Flutter logo on the home screen and a
/// material dumbbell inside, which are two different marks and neither of them
/// FitLog's. Both now come from `FitLogMarkPainter`; the launcher files are
/// written by `flutter test tool/render_app_icon.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  testWidgets('the logo in the app is the mark', (tester) async {
    await tester.pumpWidget(wrapForTest(const Center(child: FitLogLogo())));

    expect(find.byType(FitLogMark), findsOneWidget);
    expect(find.text('FitLog'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsNothing);
  });

  group('the rendered launcher icons', () {
    const res = 'android/app/src/main/res';

    img.Image read(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');
      return img.decodePng(file.readAsBytesSync())!;
    }

    test('the legacy icon is the mark on its tile', () {
      final icon = read('$res/mipmap-xxxhdpi/ic_launcher.png');
      expect(icon.width, 192);
      expect(icon.height, 192);

      // Coordinates come straight from the geometry in FitLogMarkPainter,
      // scaled from its 100-unit box to 192 px.
      double at(double unit) => unit / 100 * 192;
      img.Pixel px(double x, double y) =>
          icon.getPixel(at(x).round(), at(y).round());

      bool is_(img.Pixel p, Color c) =>
          p.r.round() == (c.r * 255).round() &&
          p.g.round() == (c.g * 255).round() &&
          p.b.round() == (c.b * 255).round();

      expect(
        is_(px(30, 50), AppColors.accent),
        isTrue,
        reason: 'the stem of the F',
      );
      expect(
        is_(px(70, 18), FitLogMarkPainter.armTone),
        isTrue,
        reason: 'the top arm, past its crease',
      );
      expect(
        is_(px(44, 15), AppColors.accentDim),
        isTrue,
        reason: 'the crease where the top arm leaves the stem',
      );
      expect(
        is_(px(50, 37), Colors.white),
        isTrue,
        reason: 'the tile between the two arms',
      );
      expect(
        is_(px(8, 50), Colors.white),
        isTrue,
        reason: 'the tile beside the F',
      );
    });

    test('the adaptive foreground is transparent outside the glyph', () {
      final fg = read('$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
      expect(fg.width, 432, reason: '108dp at xxxhdpi');
      expect(fg.getPixel(2, 2).a, 0);
      expect(fg.getPixel(216, 216).a, 255, reason: 'the middle of the glyph');
    });

    test('every density has both layers', () {
      for (final bucket in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(File('$res/mipmap-$bucket/ic_launcher.png').existsSync(), isTrue);
        expect(
          File('$res/mipmap-$bucket/ic_launcher_foreground.png').existsSync(),
          isTrue,
        );
      }
      expect(
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(),
        isTrue,
      );
      expect(
        File('$res/values/ic_launcher_background.xml')
            .readAsStringSync()
            .contains('#FFFFFFFF'),
        isTrue,
        reason: 'the mark carries the colour, the layer behind it is white',
      );
    });
  });
}
