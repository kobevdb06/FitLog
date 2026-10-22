import 'package:flutter/services.dart';

/// Keeps Android's back gesture off parts of the screen.
///
/// A swipe that starts at the left or right edge of the screen means "back"
/// on Android, and the system takes it before the app sees it. The side
/// handles of a block on the Start tab sit right there when the block is as
/// wide as the screen: dragging one closed the app. While they show, Android
/// is asked to leave their places to FitLog, through `FitLogActivity`.
abstract final class BackGesture {
  static const channel = MethodChannel('be.fitlog.app/gestures');

  /// Only [rects], in logical pixels on the screen, are kept from the back
  /// gesture; an empty list gives the edges back.
  static Future<void> keepOff(List<Rect> rects) async {
    try {
      await channel.invokeMethod<void>('exclude', [
        for (final rect in rects)
          [rect.left, rect.top, rect.right, rect.bottom],
      ]);
    } on MissingPluginException {
      // Not on Android: there is no back gesture to keep off.
    }
  }
}
