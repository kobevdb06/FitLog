import 'dart:io';

import 'package:fitlog/core/theme/app_colors.dart';
import 'package:fitlog/core/theme/app_theme.dart';
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

  testWidgets('the mark in the app takes the tones of the theme', (
    tester,
  ) async {
    FitLogMarkPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(FitLogMark),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as FitLogMarkPainter;

    await tester.pumpWidget(wrapForTest(const Center(child: FitLogMark())));
    expect(painter().bar, FitLogMarkPainter.darkBar);
    expect(painter().spark, AppColors.record);
    expect(painter().tile, isNull, reason: 'the surface is the background');

    await tester.pumpWidget(
      wrapForTest(
        Theme(
          data: AppTheme.light,
          child: const Center(child: FitLogMark()),
        ),
      ),
    );
    expect(painter().bar, FitLogMarkPainter.lightBar);
    expect(painter().spark, FitLogMarkPainter.lightSpark);
    expect(painter().plates, AppColors.accent);
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
        is_(px(56, 30), AppColors.accent),
        isTrue,
        reason: 'the largest plate',
      );
      expect(
        is_(px(20, 50), FitLogMarkPainter.darkBar),
        isTrue,
        reason: 'the bar, before the plates',
      );
      expect(
        is_(px(79, 25), AppColors.record),
        isTrue,
        reason: 'the middle of the spark',
      );
      expect(
        is_(px(38, 30), FitLogMarkPainter.iconBackground),
        isTrue,
        reason: 'the tile above the smallest plate',
      );
      expect(
        is_(px(5, 50), FitLogMarkPainter.iconBackground),
        isTrue,
        reason: 'the tile beside the bar',
      );
    });

    test('the adaptive foreground is transparent outside the glyph', () {
      final fg = read('$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
      expect(fg.width, 432, reason: '108dp at xxxhdpi');
      expect(fg.getPixel(2, 2).a, 0);
      expect(fg.getPixel(216, 216).a, 255, reason: 'the bar, in the middle');
    });

    test('every density has both layers', () {
      for (final bucket in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          File('$res/mipmap-$bucket/ic_launcher.png').existsSync(),
          isTrue,
        );
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
            .contains('#FF10141C'),
        isTrue,
        reason: 'the layer behind the mark is the tile of the other icons',
      );
    });
  });
}
