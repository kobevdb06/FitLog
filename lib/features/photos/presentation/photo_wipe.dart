/// Two photographs in the same frame, with a handle that pulls one over the
/// other.
///
/// Side by side, each picture gets half a phone and a portrait photo ends up
/// tiny. Here both use the whole width and you drag the seam instead. It only
/// works when the two were taken from roughly the same spot - which is what
/// people do with progress photos, and why the choice between the two layouts
/// is left to you rather than made for you.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';

class PhotoWipe extends StatefulWidget {
  const PhotoWipe({
    super.key,
    required this.left,
    required this.right,
    this.onTapLeft,
    this.onTapRight,
  });

  final File left;
  final File right;

  /// Opening one on its own. Which one depends on the side you tapped, so the
  /// seam decides rather than the widget.
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;

  @override
  State<PhotoWipe> createState() => _PhotoWipeState();
}

class _PhotoWipeState extends State<PhotoWipe> {
  /// Where the seam sits, 0 at the left edge and 1 at the right.
  double _seam = 0.5;

  /// Below this the picture underneath is a sliver and dragging has nothing to
  /// grab; the handle stays reachable at either end.
  static const double _margin = 0.02;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final seamX = width * _seam;

        void moveTo(double x) {
          setState(() => _seam = (x / width).clamp(_margin, 1 - _margin));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final onLeft = details.localPosition.dx < seamX;
            (onLeft ? widget.onTapLeft : widget.onTapRight)?.call();
          },
          onHorizontalDragUpdate: (details) => moveTo(details.localPosition.dx),
          onHorizontalDragStart: (details) => moveTo(details.localPosition.dx),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Picture(file: widget.right),
              ClipRect(
                clipper: _LeftOf(_seam),
                child: _Picture(file: widget.left),
              ),
              Positioned(
                left: seamX - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              Positioned(
                left: seamX - 18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => const MissingPhotoPlaceholder(),
    );
  }
}

class _LeftOf extends CustomClipper<Rect> {
  const _LeftOf(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftOf old) => old.fraction != fraction;
}
