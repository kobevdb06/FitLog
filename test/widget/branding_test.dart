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

    test('the light icon, for whoever chooses it', () {
      final icon = read('$res/mipmap-xxxhdpi/ic_launcher_light.png');
      expect(icon.width, 192);
      double at(double unit) => unit / 100 * 192;
      img.Pixel px(double x, double y) =>
          icon.getPixel(at(x).round(), at(y).round());
      bool is_(img.Pixel p, Color c) =>
          p.r.round() == (c.r * 255).round() &&
          p.g.round() == (c.g * 255).round() &&
          p.b.round() == (c.b * 255).round();

      expect(is_(px(56, 30), AppColors.accent), isTrue, reason: 'a plate');
      expect(
        is_(px(20, 50), FitLogMarkPainter.lightBar),
        isTrue,
        reason: 'the bar, in its light tone',
      );
      expect(
        is_(px(79, 25), FitLogMarkPainter.lightSpark),
        isTrue,
        reason: 'the spark, in its light tone',
      );
      expect(
        is_(px(5, 50), FitLogMarkPainter.lightIconBackground),
        isTrue,
        reason: 'the light tile',
      );

      final fg = read('$res/mipmap-xxxhdpi/ic_launcher_light_foreground.png');
      expect(fg.width, 432);
      expect(fg.getPixel(2, 2).a, 0);

      final adaptive = File('$res/mipmap-anydpi-v26/ic_launcher_light.xml')
          .readAsStringSync();
      expect(adaptive, contains('@mipmap/ic_launcher_light_foreground'));
      expect(adaptive, contains('@color/ic_launcher_light_background'));
      expect(
        File('$res/values/ic_launcher_background.xml').readAsStringSync(),
        contains('#FFEEF2FA'),
      );
    });

    test('two ways in from the launcher, the dark one under the old name', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      String alias(String name) => RegExp(
        r'<activity-alias[^>]*android:name="\.'
        '$name'
        r'"[^>]*>',
      ).firstMatch(manifest)!.group(0)!;

      // An icon already on a home screen points at ".MainActivity": with
      // that name gone, the update would take it off.
      final dark = alias('MainActivity');
      expect(dark, contains('android:enabled="true"'));
      expect(dark, contains('android:icon="@mipmap/ic_launcher"'));
      expect(dark, contains('android:targetActivity=".FitLogActivity"'));

      final light = alias('MainActivityLight');
      expect(light, contains('android:enabled="false"'));
      expect(light, contains('android:icon="@mipmap/ic_launcher_light"'));
      expect(light, contains('android:targetActivity=".FitLogActivity"'));

      // The activity itself is no way in: that would be a third icon.
      final activity = RegExp(
        r'<activity\s+android:name="\.FitLogActivity".*?</activity>',
        dotAll: true,
      ).firstMatch(manifest)!.group(0)!;
      expect(activity, isNot(contains('category.LAUNCHER')));

      // And the switch names the same two.
      final kotlin = File(
        'android/app/src/main/kotlin/be/fitlog/app/FitLogActivity.kt',
      ).readAsStringSync();
      expect(kotlin, contains('"be.fitlog.app.MainActivity"'));
      expect(kotlin, contains('"be.fitlog.app.MainActivityLight"'));
    });

    test('the adaptive foreground is transparent outside the glyph', () {
      final fg = read('$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
      expect(fg.width, 432, reason: '108dp at xxxhdpi');
      expect(fg.getPixel(2, 2).a, 0);
      expect(fg.getPixel(216, 216).a, 255, reason: 'the bar, in the middle');
    });

    test('every density has both layers', () {
      for (final bucket in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        for (final name in [
          'ic_launcher',
          'ic_launcher_foreground',
          'ic_launcher_light',
          'ic_launcher_light_foreground',
        ]) {
          expect(
            File('$res/mipmap-$bucket/$name.png').existsSync(),
            isTrue,
            reason: '$bucket/$name',
          );
        }
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
