import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A front and back silhouette with the trained muscle groups filled in.
///
/// Drawn with a [CustomPainter] rather than SVG assets: the approved package
/// list has no SVG renderer, and a handful of shapes reads better at this size
/// than a detailed anatomical drawing would.
class MuscleMap extends StatelessWidget {
  const MuscleMap({
    super.key,
    required this.intensityByMuscle,
    this.height = 200,
  });

  /// Muscle name (Dutch, as produced by the seed) to 0..1 share of the volume.
  final Map<String, double> intensityByMuscle;

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _MuscleMapPainter(
          intensityByMuscle: intensityByMuscle,
          baseColor: theme.colorScheme.surfaceContainerHighest,
          outlineColor: theme.colorScheme.outline,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({
    required this.intensityByMuscle,
    required this.baseColor,
    required this.outlineColor,
  });

  final Map<String, double> intensityByMuscle;
  final Color baseColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Two bodies side by side, each in its own half.
    final halfWidth = size.width / 2;
    _paintBody(
      canvas,
      Rect.fromLTWH(0, 0, halfWidth, size.height),
      front: true,
    );
    _paintBody(
      canvas,
      Rect.fromLTWH(halfWidth, 0, halfWidth, size.height),
      front: false,
    );
  }

  Color _colorFor(List<String> muscles) {
    var best = 0.0;
    String? bestMuscle;
    for (final m in muscles) {
      final value = intensityByMuscle[m] ?? 0;
      if (value > best) {
        best = value;
        bestMuscle = m;
      }
    }
    if (bestMuscle == null || best <= 0) return baseColor;
    // Scale the alpha so a lightly worked group still reads as touched.
    return AppColors.forMuscle(
      bestMuscle,
    ).withValues(alpha: (0.35 + best * 0.65).clamp(0.35, 1.0));
  }

  void _paintBody(Canvas canvas, Rect area, {required bool front}) {
    // A normalised 100 x 200 coordinate system per body, scaled into `area`.
    const unitW = 100.0;
    const unitH = 200.0;
    final scale = (area.width / unitW).clamp(0.0, area.height / unitH);
    final offsetX = area.left + (area.width - unitW * scale) / 2;
    final offsetY = area.top + (area.height - unitH * scale) / 2;

    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(
      offsetX + x * scale,
      offsetY + y * scale,
      w * scale,
      h * scale,
    );

    void box(Rect rect, Color color, {double radius = 5}) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius * scale)),
        Paint()..color = color,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius * scale)),
        Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Head - never a muscle group, always neutral.
    canvas.drawCircle(
      Offset(offsetX + 50 * scale, offsetY + 16 * scale),
      13 * scale,
      Paint()..color = baseColor,
    );

    // Neck and traps.
    box(r(42, 28, 16, 8), _colorFor(front ? ['nek'] : ['trapezius', 'nek']));

    // Shoulders.
    box(r(20, 36, 18, 14), _colorFor(['schouders']));
    box(r(62, 36, 18, 14), _colorFor(['schouders']));

    if (front) {
      // Chest, abs, quads, calves, biceps, forearms.
      box(r(31, 38, 38, 24), _colorFor(['borst']));
      box(r(36, 64, 28, 34), _colorFor(['buik']));
      box(r(16, 52, 16, 24), _colorFor(['biceps']));
      box(r(68, 52, 16, 24), _colorFor(['biceps']));
      box(r(14, 78, 15, 22), _colorFor(['onderarmen']));
      box(r(71, 78, 15, 22), _colorFor(['onderarmen']));
      box(r(33, 100, 16, 46), _colorFor(['quadriceps', 'adductoren']));
      box(r(51, 100, 16, 46), _colorFor(['quadriceps', 'adductoren']));
      box(r(34, 150, 14, 34), _colorFor(['kuiten']));
      box(r(52, 150, 14, 34), _colorFor(['kuiten']));
    } else {
      // Lats, upper and lower back, triceps, glutes, hamstrings, calves.
      box(r(31, 38, 38, 18), _colorFor(['trapezius', 'bovenrug']));
      box(r(31, 56, 38, 22), _colorFor(['lats', 'bovenrug']));
      box(r(36, 78, 28, 20), _colorFor(['onderrug']));
      box(r(16, 52, 16, 24), _colorFor(['triceps']));
      box(r(68, 52, 16, 24), _colorFor(['triceps']));
      box(r(14, 78, 15, 22), _colorFor(['onderarmen']));
      box(r(71, 78, 15, 22), _colorFor(['onderarmen']));
      box(r(33, 100, 34, 20), _colorFor(['bilspieren', 'abductoren']));
      box(r(33, 122, 16, 26), _colorFor(['hamstrings']));
      box(r(51, 122, 16, 26), _colorFor(['hamstrings']));
      box(r(34, 150, 14, 34), _colorFor(['kuiten']));
      box(r(52, 150, 14, 34), _colorFor(['kuiten']));
    }
  }

  @override
  bool shouldRepaint(_MuscleMapPainter oldDelegate) =>
      oldDelegate.intensityByMuscle != intensityByMuscle ||
      oldDelegate.baseColor != baseColor;
}
