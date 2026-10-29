// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What says which phone this is, or null where there is no Android to ask.

@ProviderFor(phoneInfo)
final phoneInfoProvider = PhoneInfoProvider._();

/// What says which phone this is, or null where there is no Android to ask.

final class PhoneInfoProvider
    extends $FunctionalProvider<PhoneInfo?, PhoneInfo?, PhoneInfo?>
    with $Provider<PhoneInfo?> {
  /// What says which phone this is, or null where there is no Android to ask.
  PhoneInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phoneInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneInfoHash();

  @$internal
  @override
  $ProviderElement<PhoneInfo?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PhoneInfo? create(Ref ref) {
    return phoneInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhoneInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhoneInfo?>(value),
    );
  }
}

String _$phoneInfoHash() => r'd113d7549fbb62fd9be6f5d9c29c35c5504d7453';

/// "Google Pixel 7 · Android 15", for the end of an e-mail to the maker.

@ProviderFor(phoneDescription)
final phoneDescriptionProvider = PhoneDescriptionProvider._();

/// "Google Pixel 7 · Android 15", for the end of an e-mail to the maker.

final class PhoneDescriptionProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// "Google Pixel 7 · Android 15", for the end of an e-mail to the maker.
  PhoneDescriptionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'phoneDescriptionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$phoneDescriptionHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return phoneDescription(ref);
  }
}

String _$phoneDescriptionHash() => r'efadf6e786738be208d4ab236d4a27ad74177738';
