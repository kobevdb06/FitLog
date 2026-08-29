// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(progressPhotos)
final progressPhotosProvider = ProgressPhotosProvider._();

final class ProgressPhotosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProgressPhotoRow>>,
          List<ProgressPhotoRow>,
          Stream<List<ProgressPhotoRow>>
        >
    with
        $FutureModifier<List<ProgressPhotoRow>>,
        $StreamProvider<List<ProgressPhotoRow>> {
  ProgressPhotosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressPhotosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressPhotosHash();

  @$internal
  @override
  $StreamProviderElement<List<ProgressPhotoRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProgressPhotoRow>> create(Ref ref) {
    return progressPhotos(ref);
  }
}

String _$progressPhotosHash() => r'ee0f36c89f877a617083fb8b40008775b83c1cf9';

/// Null while the documents directory is still being resolved.

@ProviderFor(photoStore)
final photoStoreProvider = PhotoStoreProvider._();

/// Null while the documents directory is still being resolved.

final class PhotoStoreProvider
    extends $FunctionalProvider<PhotoStore?, PhotoStore?, PhotoStore?>
    with $Provider<PhotoStore?> {
  /// Null while the documents directory is still being resolved.
  PhotoStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoStoreHash();

  @$internal
  @override
  $ProviderElement<PhotoStore?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PhotoStore? create(Ref ref) {
    return photoStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhotoStore? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhotoStore?>(value),
    );
  }
}

String _$photoStoreHash() => r'9ef9cc57671d73c08c5803c33d8fe265ee15b192';

@ProviderFor(photoActions)
final photoActionsProvider = PhotoActionsProvider._();

final class PhotoActionsProvider
    extends $FunctionalProvider<PhotoActions, PhotoActions, PhotoActions>
    with $Provider<PhotoActions> {
  PhotoActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoActionsHash();

  @$internal
  @override
  $ProviderElement<PhotoActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PhotoActions create(Ref ref) {
    return photoActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PhotoActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PhotoActions>(value),
    );
  }
}

String _$photoActionsHash() => r'a9c71ade7c4064c95fc4d1acb2b262b5a6460eeb';
