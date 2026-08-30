import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Draws a QR code.
///
/// The obvious choice was `qr_flutter`, and it rendered nothing but a grey
/// square on this Flutter version. The encoding underneath it - the `qr`
/// package - is fine, so only the drawing is done here, which is a painter
/// over a grid of booleans and no dependency that can rot.
class QrView extends StatelessWidget {
  const QrView({
    super.key,
    required this.data,
    this.size = 280,
    // A screen is a forgiving surface but a moving hand is not.
    this.errorCorrectLevel = QrErrorCorrectLevel.medium,
  });

  final String data;
  final double size;
  final QrErrorCorrectLevel errorCorrectLevel;

  @override
  Widget build(BuildContext context) {
    final QrImage image;
    try {
      image = QrImage(
        QrCode(
          payload: QrPayload.fromString(data),
          errorCorrectLevel: errorCorrectLevel,
        ),
      );
    } on InputTooLongException {
      return _TooBig(size: size);
    }

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _QrPainter(image),
        // The code is the whole point of the screen; a reader that cannot see
        // it is not helped by a label, but a screen reader user is.
        isComplex: true,
        willChange: false,
        child: Semantics(
          label: 'QR-code met de routine',
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount;
    if (modules <= 0) return;

    // Whole pixels per module, so no module lands half on a pixel and blurs
    // into its neighbour - which is exactly what a scanner cannot read.
    final scale = (size.width / modules).floorToDouble();
    final drawn = scale * modules;
    final offset = ((size.width - drawn) / 2).floorToDouble();

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            offset + col * scale,
            offset + row * scale,
            scale,
            scale,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}

/// Shown when the content does not fit in any QR code at all.
class _TooBig extends StatelessWidget {
  const _TooBig({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Deze routine is te groot voor één code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
