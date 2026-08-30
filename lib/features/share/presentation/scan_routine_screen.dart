import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/routine_code.dart';

/// The camera, pointed at a friend's screen.
///
/// The scanner runs entirely on the device: the barcode model is bundled in
/// the app rather than fetched by Play Services, and the release manifest
/// strips the INTERNET permission whatever a dependency asks for.
class ScanRoutineScreen extends StatefulWidget {
  const ScanRoutineScreen({super.key});

  /// Returns the routine that was scanned, or null if the user backed out.
  static Future<SharedRoutine?> open(BuildContext context) {
    return Navigator.of(context).push<SharedRoutine>(
      MaterialPageRoute<SharedRoutine>(
        builder: (context) => const ScanRoutineScreen(),
      ),
    );
  }

  @override
  State<ScanRoutineScreen> createState() => _ScanRoutineScreenState();
}

class _ScanRoutineScreenState extends State<ScanRoutineScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Set the moment a code is accepted, so the frames that keep arriving while
  /// the screen closes are ignored.
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;

      try {
        final routine = decodeRoutine(base64Url.decode(value));
        _handled = true;
        Navigator.of(context).pop(routine);
        return;
      } on InvalidRoutineCodeException catch (error) {
        _show(error.message);
        return;
      } on FormatException {
        _show('Dit is geen FitLog-code.');
        return;
      }
    }
  }

  /// Says what is wrong and keeps scanning: the next frame may be the right
  /// code, and closing the camera on a misread would be maddening.
  void _show(String message) {
    if (!mounted || _error == message) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine scannen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: 'Zaklamp',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'De camera is niet beschikbaar: ${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _error ??
                      'Richt op de code op het scherm van je vriend. '
                          'Hij vindt hem onder de ⋮ van zijn routine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _error == null ? Colors.white : Colors.amber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
