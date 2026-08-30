import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The FitLog mark: a bold rounded F on the accent tile.
///
/// Drawn rather than bundled as a bitmap so the one geometry serves both the
/// app and the launcher icon - `tool/render_app_icon.dart` paints this same
/// class into the platform icon files, so the two can never drift apart.
///
/// Everything is laid out in a 100x100 box and scaled, which keeps the
/// proportions identical from a 20pt notification badge to a 1024pt store
/// icon.
class FitLogMarkPainter extends CustomPainter {
  const FitLogMarkPainter({
    required this.glyph,
    this.tile,
    this.cornerRadius = 28,
    this.glyphScale = 1,
  });

  /// The colour of the F itself.
  final Color glyph;

  /// The rounded square behind it, or null for the glyph on its own - which is
  /// what an Android adaptive foreground needs.
  final Color? tile;

  /// Corner rounding of the tile, in the same 0-100 units. 0 gives the square
  /// full-bleed icon iOS expects, since iOS applies its own mask.
  final double cornerRadius;

  /// Shrinks the glyph around the centre of the box, for the adaptive icon
  /// foreground: only the middle of that canvas is guaranteed to survive the
  /// launcher's mask.
  final double glyphScale;

  /// The glyph's own box inside the 100-unit canvas, so callers can scale it
  /// to fit a given safe area instead of guessing.
  static const double glyphWidth = 40;
  static const double glyphHeight = 64;

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

    final paint = Paint()..color = glyph;
    void bar(double l, double t, double r, double b, double radius) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(l, t, r, b),
          Radius.circular(radius),
        ),
        paint,
      );
    }

    // A stem and two arms, 13 units thick with a 6.5 radius so every terminal
    // is an exact half-circle. Nothing else: the mark has to stay readable at
    // the 16 units a notification badge gets.
    bar(30, 18, 43, 82, 6.5);
    bar(30, 18, 70, 31, 6.5);
    bar(30, 44, 62, 57, 6.5);

    canvas.restore();
  }

  @override
  bool shouldRepaint(FitLogMarkPainter old) =>
      old.glyph != glyph ||
      old.tile != tile ||
      old.cornerRadius != cornerRadius ||
      old.glyphScale != glyphScale;
}

/// The mark on its accent tile, at [size] logical pixels.
class FitLogMark extends StatelessWidget {
  const FitLogMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: const FitLogMarkPainter(
          glyph: Colors.white,
          tile: AppColors.accent,
        ),
        isComplex: false,
      ),
    );
  }
}
