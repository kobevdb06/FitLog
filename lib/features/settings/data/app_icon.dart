import 'package:flutter/services.dart';

/// The icon on the home screen.
enum AppIcon {
  dark('Donker'),
  light('Licht');

  const AppIcon(this.label);

  final String label;
}

/// Switches the icon on the home screen.
///
/// Android only: there the launcher entries are two aliases of one activity,
/// each with its own icon, and the app turns one on and the other off.
abstract interface class AppIconSwitcher {
  /// The icon the launcher shows now.
  Future<AppIcon> current();

  /// Shows [icon] from now on.
  Future<void> use(AppIcon icon);
}

/// The two launcher aliases, through `FitLogActivity`.
class AndroidAppIconSwitcher implements AppIconSwitcher {
  const AndroidAppIconSwitcher();

  static const _channel = MethodChannel('be.fitlog.app/icon');

  @override
  Future<AppIcon> current() async =>
      await _channel.invokeMethod<String>('current') == 'light'
      ? AppIcon.light
      : AppIcon.dark;

  @override
  Future<void> use(AppIcon icon) =>
      _channel.invokeMethod<void>('use', {'icon': icon.name});
}
