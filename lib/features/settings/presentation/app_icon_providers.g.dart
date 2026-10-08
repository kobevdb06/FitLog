// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_icon_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What switches the home-screen icon, or null where there is nothing to
/// switch.

@ProviderFor(appIconSwitcher)
final appIconSwitcherProvider = AppIconSwitcherProvider._();

/// What switches the home-screen icon, or null where there is nothing to
/// switch.

final class AppIconSwitcherProvider
    extends
        $FunctionalProvider<
          AppIconSwitcher?,
          AppIconSwitcher?,
          AppIconSwitcher?
        >
    with $Provider<AppIconSwitcher?> {
  /// What switches the home-screen icon, or null where there is nothing to
  /// switch.
  AppIconSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appIconSwitcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appIconSwitcherHash();

  @$internal
  @override
  $ProviderElement<AppIconSwitcher?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppIconSwitcher? create(Ref ref) {
    return appIconSwitcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppIconSwitcher? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppIconSwitcher?>(value),
    );
  }
}

String _$appIconSwitcherHash() => r'a53086e904f2e1023b584545e243009cca67f778';

/// The icon the launcher shows now, read from Android rather than kept in
/// the database: Android is what shows it, and a restored backup on another
/// phone would otherwise claim an icon that phone never got.

@ProviderFor(currentAppIcon)
final currentAppIconProvider = CurrentAppIconProvider._();

/// The icon the launcher shows now, read from Android rather than kept in
/// the database: Android is what shows it, and a restored backup on another
/// phone would otherwise claim an icon that phone never got.

final class CurrentAppIconProvider
    extends
        $FunctionalProvider<AsyncValue<AppIcon?>, AppIcon?, FutureOr<AppIcon?>>
    with $FutureModifier<AppIcon?>, $FutureProvider<AppIcon?> {
  /// The icon the launcher shows now, read from Android rather than kept in
  /// the database: Android is what shows it, and a restored backup on another
  /// phone would otherwise claim an icon that phone never got.
  CurrentAppIconProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAppIconProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAppIconHash();

  @$internal
  @override
  $FutureProviderElement<AppIcon?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppIcon?> create(Ref ref) {
    return currentAppIcon(ref);
  }
}

String _$currentAppIconHash() => r'ea1a59f81269033370e4b5f4f9bed1712cbe0e4f';
