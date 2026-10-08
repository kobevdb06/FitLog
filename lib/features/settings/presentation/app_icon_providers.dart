import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_icon.dart';

part 'app_icon_providers.g.dart';

/// What switches the home-screen icon, or null where there is nothing to
/// switch.
@Riverpod(keepAlive: true)
AppIconSwitcher? appIconSwitcher(Ref ref) =>
    Platform.isAndroid ? const AndroidAppIconSwitcher() : null;

/// The icon the launcher shows now, read from Android rather than kept in
/// the database: Android is what shows it, and a restored backup on another
/// phone would otherwise claim an icon that phone never got.
@riverpod
Future<AppIcon?> currentAppIcon(Ref ref) async =>
    ref.watch(appIconSwitcherProvider)?.current();
