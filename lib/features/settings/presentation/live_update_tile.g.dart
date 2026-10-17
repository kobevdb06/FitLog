// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_update_tile.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(liveUpdateSettings)
final liveUpdateSettingsProvider = LiveUpdateSettingsProvider._();

final class LiveUpdateSettingsProvider
    extends
        $FunctionalProvider<
          LiveUpdateSettings,
          LiveUpdateSettings,
          LiveUpdateSettings
        >
    with $Provider<LiveUpdateSettings> {
  LiveUpdateSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveUpdateSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveUpdateSettingsHash();

  @$internal
  @override
  $ProviderElement<LiveUpdateSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LiveUpdateSettings create(Ref ref) {
    return liveUpdateSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveUpdateSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveUpdateSettings>(value),
    );
  }
}

String _$liveUpdateSettingsHash() =>
    r'b2d5205a55dbdbaba917b458023e7b9a4078ec1a';

/// Whether the workout may be a live notification; null where it cannot be.

@ProviderFor(liveUpdatesAllowed)
final liveUpdatesAllowedProvider = LiveUpdatesAllowedProvider._();

/// Whether the workout may be a live notification; null where it cannot be.

final class LiveUpdatesAllowedProvider
    extends $FunctionalProvider<AsyncValue<bool?>, bool?, FutureOr<bool?>>
    with $FutureModifier<bool?>, $FutureProvider<bool?> {
  /// Whether the workout may be a live notification; null where it cannot be.
  LiveUpdatesAllowedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveUpdatesAllowedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveUpdatesAllowedHash();

  @$internal
  @override
  $FutureProviderElement<bool?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool?> create(Ref ref) {
    return liveUpdatesAllowed(ref);
  }
}

String _$liveUpdatesAllowedHash() =>
    r'ea14a7d03dc3bc1b710cb92549084698967b4234';
