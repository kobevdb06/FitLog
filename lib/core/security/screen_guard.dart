import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What keeps the PIN and the twelve words off other people's screens:
/// screenshots and screen recordings, the picture in the recent apps, and
/// the clipboard (DECISIONS 265).
///
/// On Android only; elsewhere every call does nothing.
class ScreenGuard {
  const ScreenGuard._();

  static const channel = MethodChannel('be.fitlog.app/guard');

  /// How long the twelve words stay on the clipboard.
  static const Duration clipboardKept = Duration(minutes: 1);

  /// How many screens ask for the window to be kept secure right now: a
  /// dialog over a screen that asks too must not let go of it when it
  /// closes.
  static int _secure = 0;

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _call(String method, [Object? arguments]) async {
    if (!_android) return;
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // A test, or a build without the channel: nothing to guard with.
    } on PlatformException catch (error) {
      debugPrint('FitLog: $method lukte niet (${error.message})');
    }
  }

  /// No screenshots or recordings of this window while [on].
  static Future<void> _setSecure(bool on) => _call('secure', on);

  static Future<void> hold() async {
    _secure++;
    if (_secure == 1) await _setSecure(true);
  }

  static Future<void> release() async {
    if (_secure == 0) return;
    _secure--;
    if (_secure == 0) await _setSecure(false);
  }

  /// With a PIN, the recent apps show no picture of FitLog: what was on the
  /// screen when it went to the background - a workout, a weight - stayed
  /// there for anyone to see. Android 13 and later.
  static Future<void> followPin({required bool pin}) => _call('recents', !pin);

  /// [text] on the clipboard, marked as sensitive - Android 13 and later do
  /// not show it in the preview that comes up - and gone again after
  /// [clipboardKept]. Off Android, it goes on the clipboard as it is.
  static Future<void> copySecret(String text) async {
    if (!_android) {
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }
    await _call('copySecret', {
      'text': text,
      'clearAfterMs': clipboardKept.inMilliseconds,
    });
  }

  @visibleForTesting
  static void reset() => _secure = 0;
}

/// Keeps the window secure while [child] is on screen: no screenshots, no
/// screen recording, and a blank picture in the recent apps.
class SecureScreen extends StatefulWidget {
  const SecureScreen({required this.child, super.key});

  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ScreenGuard.hold());
  }

  @override
  void dispose() {
    unawaited(ScreenGuard.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
