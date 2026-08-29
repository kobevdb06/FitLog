// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one settings row, as a stream so every screen reacts to a unit change.

@ProviderFor(settings)
final settingsProvider = SettingsProvider._();

/// The one settings row, as a stream so every screen reacts to a unit change.

final class SettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppSettingsRow>,
          AppSettingsRow,
          Stream<AppSettingsRow>
        >
    with $FutureModifier<AppSettingsRow>, $StreamProvider<AppSettingsRow> {
  /// The one settings row, as a stream so every screen reacts to a unit change.
  SettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  $StreamProviderElement<AppSettingsRow> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AppSettingsRow> create(Ref ref) {
    return settings(ref);
  }
}

String _$settingsHash() => r'ef8d0612adc1d11bfb32c53c58baa033ceefd6a9';

@ProviderFor(userProfile)
final userProfileProvider = UserProfileProvider._();

final class UserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfileRow?>,
          UserProfileRow?,
          Stream<UserProfileRow?>
        >
    with $FutureModifier<UserProfileRow?>, $StreamProvider<UserProfileRow?> {
  UserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userProfileHash();

  @$internal
  @override
  $StreamProviderElement<UserProfileRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserProfileRow?> create(Ref ref) {
    return userProfile(ref);
  }
}

String _$userProfileHash() => r'ec769572e3c2f261b9b1e595429aa476d856e0e6';

/// Display helpers bound to the user's chosen units.

@ProviderFor(formatters)
final formattersProvider = FormattersProvider._();

/// Display helpers bound to the user's chosen units.

final class FormattersProvider
    extends $FunctionalProvider<Formatters, Formatters, Formatters>
    with $Provider<Formatters> {
  /// Display helpers bound to the user's chosen units.
  FormattersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formattersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formattersHash();

  @$internal
  @override
  $ProviderElement<Formatters> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Formatters create(Ref ref) {
    return formatters(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Formatters value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Formatters>(value),
    );
  }
}

String _$formattersHash() => r'57477bbf850229dd8223d4d8e1e1fac3308c5b00';

/// The bar and plates the calculators work with.

@ProviderFor(barbellSetup)
final barbellSetupProvider = BarbellSetupProvider._();

/// The bar and plates the calculators work with.

final class BarbellSetupProvider
    extends $FunctionalProvider<BarbellSetup, BarbellSetup, BarbellSetup>
    with $Provider<BarbellSetup> {
  /// The bar and plates the calculators work with.
  BarbellSetupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'barbellSetupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$barbellSetupHash();

  @$internal
  @override
  $ProviderElement<BarbellSetup> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BarbellSetup create(Ref ref) {
    return barbellSetup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BarbellSetup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BarbellSetup>(value),
    );
  }
}

String _$barbellSetupHash() => r'ce449fbca26d0c0170f79c5b0c7defefd5beabc8';
