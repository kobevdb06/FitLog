import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The FitLog mark: a bar with plates that climb from small to large towards
/// the collar, and beside the largest an amber spark.
///
/// The bar and plates say what the app is for, the climb is the log - what you
/// lift going up over time - and the spark is the coach. The bar is seen from
/// the side on purpose: a plate seen face-on is a ring, and a ring on its own
/// reads as anything round.
///
/// Drawn rather than bundled as a bitmap so the one geometry serves both the
/// app and the launcher icon: `tool/render_app_icon.dart` paints this same
/// class into the platform icon files, so the two cannot drift apart.
///
/// Everything is laid out in a 100x100 box and scaled, which keeps the
/// proportions identical from a 20pt notification badge to a 1024pt store
/// icon.
class FitLogMarkPainter extends CustomPainter {
  /// The mark in its dark tones: on the launcher icon, and in the app in dark
  /// mode.
  const FitLogMarkPainter({
    this.bar = darkBar,
    this.plates = AppColors.accent,
    this.spark = AppColors.record,
    this.tile,
    this.cornerRadius = 22,
    this.glyphScale = 1,
  });

  /// The mark in its light tones, for a light surface, which the light bar
  /// and the bright amber would fade into.
  const FitLogMarkPainter.light({
    this.tile,
    this.cornerRadius = 22,
    this.glyphScale = 1,
  }) : bar = lightBar,
       plates = AppColors.accent,
       spark = lightSpark;

  /// The bar and the collar.
  final Color bar;

  /// The three plates.
  final Color plates;

  /// The spark beside the largest plate.
  final Color spark;

  /// The rounded square behind the mark, or null for the glyph on its own -
  /// which is what the app and an Android adaptive foreground both want.
  final Color? tile;

  /// Corner rounding of the tile, in the same 0-100 units. 0 gives the square
  /// full-bleed icon iOS expects, since iOS applies its own mask.
  final double cornerRadius;

  /// Scales the glyph around the centre of the box, for the adaptive icon
  /// foreground and for filling a widget that has no tile.
  final double glyphScale;

  /// The bar on a dark surface: a tint above the accent, so it reads as the
  /// same metal as the plates rather than as a second colour.
  static const Color darkBar = Color(0xFF7BA9FF);

  /// The bar on a light surface: a shade below the accent, for the same
  /// reason.
  static const Color lightBar = Color(0xFF2A5BD7);

  /// The spark on a light surface: the record amber, a step deeper.
  static const Color lightSpark = Color(0xFFE8940A);

  /// The tile of the launcher icon. Dark, because the launcher has one icon
  /// for a light and a dark home screen alike, and the dark tones keep their
  /// contrast only on dark. The Android background layer
  /// (`ic_launcher_background`) is this same colour.
  static const Color iconBackground = Color(0xFF10141C);

  /// The tile of the light launcher icon, for whoever chooses it
  /// (`ic_launcher_light_background`).
  static const Color lightIconBackground = Color(0xFFEEF2FA);

  /// The glyph's own box inside the 100-unit canvas, centred on (50, 50), so
  /// callers can scale it to fit a given area instead of guessing.
  static const double glyphWidth = 80;
  static const double glyphHeight = 62;

  /// How far the glyph reaches from the centre of the box: the outer tip of
  /// the spark, which lies further out than the ends of the bar. A round mask
  /// has to leave that much.
  static double get glyphReach =>
      (_sparkCentre + const Offset(_sparkRadius, 0) - const Offset(50, 50))
          .distance;

  static const _bar = (rect: Rect.fromLTWH(10, 47, 80, 6), radius: 3.0);
  static const _plates = [
    (rect: Rect.fromLTWH(30, 36, 7, 28), radius: 2.5),
    (rect: Rect.fromLTWH(39, 28, 9, 44), radius: 3.0),
    (rect: Rect.fromLTWH(50, 20, 12, 60), radius: 3.5),
  ];
  static const _collar = (rect: Rect.fromLTWH(64, 41, 5, 18), radius: 1.5);
  static const _sparkCentre = Offset(79, 25);
  static const double _sparkRadius = 7;

  /// How close to the centre of the spark its sides pinch in.
  static const double _sparkPinch = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 100;
    canvas.save();
    canvas.scale(unit);

    final tileColor = tile;
    if (tileColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 100),
          Radius.circular(cornerRadius),
        ),
        Paint()..color = tileColor,
      );
    }

    if (glyphScale != 1) {
      canvas.translate(50, 50);
      canvas.scale(glyphScale);
      canvas.translate(-50, -50);
    }

    void block(({Rect rect, double radius}) shape, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(shape.rect, Radius.circular(shape.radius)),
        Paint()..color = color,
      );
    }

    // The bar first, so the plates sit on it rather than under it.
    block(_bar, bar);
    for (final plate in _plates) {
      block(plate, plates);
    }
    block(_collar, bar);

    const o = _sparkCentre;
    const r = _sparkRadius;
    const p = _sparkPinch;
    canvas.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..cubicTo(o.dx + p, o.dy - p, o.dx + p, o.dy - p, o.dx + r, o.dy)
        ..cubicTo(o.dx + p, o.dy + p, o.dx + p, o.dy + p, o.dx, o.dy + r)
        ..cubicTo(o.dx - p, o.dy + p, o.dx - p, o.dy + p, o.dx - r, o.dy)
        ..cubicTo(o.dx - p, o.dy - p, o.dx - p, o.dy - p, o.dx, o.dy - r)
        ..close(),
      Paint()..color = spark,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(FitLogMarkPainter old) =>
      old.bar != bar ||
      old.plates != plates ||
      old.spark != spark ||
      old.tile != tile ||
      old.cornerRadius != cornerRadius ||
      old.glyphScale != glyphScale;
}

/// The mark on its own, filling a [size] by [size] box, in the tones of the
/// theme around it.
///
/// No tile: inside the app the mark sits on the surface it is given, the way
/// the launcher composes it over its own background.
class FitLogMark extends StatelessWidget {
  const FitLogMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    const fill = 100 / FitLogMarkPainter.glyphWidth;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: Theme.of(context).brightness == Brightness.dark
            ? const FitLogMarkPainter(glyphScale: fill)
            : const FitLogMarkPainter.light(glyphScale: fill),
        isComplex: false,
      ),
    );
  }
}
