import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The FitLog mark: an F folded out of one ribbon.
///
/// Every edge that is not vertical or horizontal runs down-left at 45 degrees -
/// the cut ends of the arms and the creases where they leave the stem alike.
/// That is what makes the short arm line up with its crease; when the creases
/// ran the other way they overhung the arm and sat crooked against it.
///
/// Drawn rather than bundled as a bitmap so the one geometry serves both the
/// app and the launcher icon: `tool/render_app_icon.dart` paints this same
/// class into the platform icon files, so the two cannot drift apart.
///
/// Everything is laid out in a 100x100 box and scaled, which keeps the
/// proportions identical from a 20pt notification badge to a 1024pt store
/// icon.
class FitLogMarkPainter extends CustomPainter {
  const FitLogMarkPainter({
    this.stem = AppColors.accent,
    this.arms = armTone,
    this.crease = AppColors.accentDim,
    this.tile,
    this.cornerRadius = 22,
    this.glyphScale = 1,
  });

  /// The upright of the F.
  final Color stem;

  /// The two arms, a tint above the accent so the fold reads as depth rather
  /// than as a second colour.
  final Color arms;

  /// The inside of each fold.
  final Color crease;

  /// The rounded square behind the mark, or null for the glyph on its own -
  /// which is what the app and an Android adaptive foreground both want.
  final Color? tile;

  /// Corner rounding of the tile, in the same 0-100 units. 0 gives the square
  /// full-bleed icon iOS expects, since iOS applies its own mask.
  final double cornerRadius;

  /// Scales the glyph around the centre of the box, for the adaptive icon
  /// foreground and for filling a widget that has no tile.
  final double glyphScale;

  /// The tint used for the arms. It is a lighter accent, not a second colour.
  static const Color armTone = Color(0xFF7BA9FF);

  /// The glyph's own box inside the 100-unit canvas, centred on (50, 50), so
  /// callers can scale it to fit a given area instead of guessing.
  static const double glyphWidth = 58;
  static const double glyphHeight = 78;

  static const List<Offset> _stem = [
    Offset(21, 11),
    Offset(39, 11),
    Offset(39, 89),
    Offset(21, 89),
  ];
  static const List<Offset> _topArm = [
    Offset(39, 11),
    Offset(79, 11),
    Offset(61, 29),
    Offset(39, 29),
  ];
  static const List<Offset> _midArm = [
    Offset(39, 45),
    Offset(69, 45),
    Offset(51, 63),
    Offset(39, 63),
  ];
  static const List<Offset> _topCrease = [
    Offset(39, 11),
    Offset(57, 11),
    Offset(39, 29),
  ];
  static const List<Offset> _midCrease = [
    Offset(39, 45),
    Offset(57, 45),
    Offset(39, 63),
  ];

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

    void shape(List<Offset> points, Color color) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // The arms first, then the stem over them: the stem is the near edge of
    // the ribbon, so it is what the folds turn away from.
    shape(_topArm, arms);
    shape(_midArm, arms);
    shape(_stem, stem);
    shape(_topCrease, crease);
    shape(_midCrease, crease);

    canvas.restore();
  }

  @override
  bool shouldRepaint(FitLogMarkPainter old) =>
      old.stem != stem ||
      old.arms != arms ||
      old.crease != crease ||
      old.tile != tile ||
      old.cornerRadius != cornerRadius ||
      old.glyphScale != glyphScale;
}

/// The mark on its own, filling a [size] by [size] box.
///
/// No tile: inside the app the mark sits on the surface it is given, the way
/// the launcher composes it over its own background.
class FitLogMark extends StatelessWidget {
  const FitLogMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(
        painter: FitLogMarkPainter(
          glyphScale: 100 / FitLogMarkPainter.glyphHeight,
        ),
        isComplex: false,
      ),
    );
  }
}
