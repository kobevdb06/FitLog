// Renders the launcher icons from `FitLogMarkPainter`, so the icon on the home
// screen and the logo inside the app are the same drawing and cannot drift.
//
//   flutter test tool/render_app_icon.dart
//
// Run it after changing the mark, and commit the PNGs it writes. It needs the
// Flutter engine to rasterise, which is why it is a test file rather than a
// plain Dart script; it touches nothing but the icon files.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fitlog/core/widgets/fitlog_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Density buckets, and the side of a legacy launcher icon in each.
const Map<String, int> _androidBuckets = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// An adaptive icon canvas is 108dp and the launcher masks it down; a round
/// mask keeps a 72dp circle. The glyph is scaled until its corners sit inside
/// that circle, which is what stops the stem clipping on a round launcher.
///
/// The stricter 66dp circle Android calls the safe zone would leave the icon
/// noticeably smaller than everything else on the home screen, and only the
/// corners of the bounding box - empty space - would fall outside the 72.
const double _adaptiveDp = 108;
const double _adaptiveMaskDp = 72;
final double _adaptiveSafeScale =
    (_adaptiveMaskDp / _adaptiveDp * 100 / 2) /
    _halfDiagonal(FitLogMarkPainter.glyphWidth, FitLogMarkPainter.glyphHeight);

double _halfDiagonal(double w, double h) => math.sqrt(w * w + h * h) / 2;

const String _androidRes = 'android/app/src/main/res';
const String _iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

Future<void> _write(String path, int side, FitLogMarkPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size(side.toDouble(), side.toDouble()));
  final image = await recorder.endRecording().toImage(side, side);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render the launcher icons', () async {
    // Android, legacy: the rounded tile, for launchers before adaptive icons.
    const legacy = FitLogMarkPainter(tile: Colors.white);
    // Android, adaptive foreground: the glyph alone, the launcher supplies the
    // shape and the background colour.
    final foreground = FitLogMarkPainter(glyphScale: _adaptiveSafeScale);
    // iOS masks the corners itself and rejects transparency, so it gets the
    // full-bleed square.
    const ios = FitLogMarkPainter(tile: Colors.white, cornerRadius: 0);

    for (final entry in _androidBuckets.entries) {
      final dir = '$_androidRes/mipmap-${entry.key}';
      await _write('$dir/ic_launcher.png', entry.value, legacy);
      await _write(
        '$dir/ic_launcher_foreground.png',
        (entry.value * _adaptiveDp / 48).round(),
        foreground,
      );
    }

    for (final entry in _iosSlots.entries) {
      await _write('$_iosIcons/${entry.key}', entry.value, ios);
    }

    stdout.writeln('Icons written from the mark in fitlog_mark.dart.');
  });
}

/// Every slot in AppIcon.appiconset with the pixel side it holds. Two names
/// can want the same side - 20pt@2x and 40pt@1x are both 40 - so this is keyed
/// by file name, not by size.
const Map<String, int> _iosSlots = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};
