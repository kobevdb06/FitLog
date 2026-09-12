/// Publishing the home-screen shortcuts, and catching the tap that follows.
///
/// The only part of the feature that talks to Android. Everything it decides
/// comes from `domain/quick_start.dart`; this hands the result over and
/// remembers what was handed over last, so an unchanged list is not pushed
/// again on every database write.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';

import '../domain/quick_start.dart';

/// The launcher icon doubles as the shortcut icon: no second drawing to keep
/// in step, and the shortcut is unmistakably this app's.
const String _shortcutIcon = 'ic_launcher';

class QuickStartService {
  QuickStartService({QuickActions? actions})
    : _actions = actions ?? const QuickActions();

  final QuickActions _actions;

  List<String>? _published;
  bool _listening = false;

  /// Starts listening for a tap on one of the shortcuts.
  ///
  /// [onRoutine] is called with the routine's id, which may be while the app
  /// is still locked - the caller decides when to act on it.
  Future<void> listen(void Function(String routineId) onRoutine) async {
    if (_listening) return;
    _listening = true;
    await _guarded(() async {
      await _actions.initialize((type) {
        final routineId = routineIdFromQuickStart(type);
        if (routineId != null) onRoutine(routineId);
      });
    });
  }

  /// Replaces the shortcuts with [items].
  Future<void> publish(List<({String type, String title})> items) async {
    final types = [for (final i in items) '${i.type}|${i.title}'];
    if (listEquals(_published, types)) return;
    _published = types;

    await _guarded(() async {
      await _actions.setShortcutItems([
        for (final item in items)
          ShortcutItem(
            type: item.type,
            localizedTitle: item.title,
            icon: _shortcutIcon,
          ),
      ]);
    });
  }

  /// Only the two failures that mean "this platform has no shortcuts": no
  /// channel at all (a desktop test host) and a launcher that refuses them.
  /// Neither is worth an error the user sees - the app works, it simply has no
  /// shortcuts. Anything else is a bug of mine and is left to surface.
  Future<void> _guarded(Future<void> Function() body) async {
    try {
      await body();
    } on MissingPluginException catch (error) {
      debugPrint('Snelkoppelingen niet beschikbaar: $error');
    } on PlatformException catch (error) {
      debugPrint('Snelkoppelingen geweigerd: $error');
    }
  }
}
