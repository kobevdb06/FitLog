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

/// One photo, watched: the sheet that shows it stays open while you edit it.

@ProviderFor(progressPhoto)
final progressPhotoProvider = ProgressPhotoFamily._();

/// One photo, watched: the sheet that shows it stays open while you edit it.

final class ProgressPhotoProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProgressPhotoRow?>,
          ProgressPhotoRow?,
          Stream<ProgressPhotoRow?>
        >
    with
        $FutureModifier<ProgressPhotoRow?>,
        $StreamProvider<ProgressPhotoRow?> {
  /// One photo, watched: the sheet that shows it stays open while you edit it.
  ProgressPhotoProvider._({
    required ProgressPhotoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'progressPhotoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$progressPhotoHash();

  @override
  String toString() {
    return r'progressPhotoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ProgressPhotoRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ProgressPhotoRow?> create(Ref ref) {
    final argument = this.argument as String;
    return progressPhoto(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProgressPhotoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$progressPhotoHash() => r'ac4a7e7b04f6c8697ee4984a2646e8612bd3f4e9';

/// One photo, watched: the sheet that shows it stays open while you edit it.

final class ProgressPhotoFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ProgressPhotoRow?>, String> {
  ProgressPhotoFamily._()
    : super(
        retry: null,
        name: r'progressPhotoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One photo, watched: the sheet that shows it stays open while you edit it.

  ProgressPhotoProvider call(String id) =>
      ProgressPhotoProvider._(argument: id, from: this);

  @override
  String toString() => r'progressPhotoProvider';
}

/// The finished sessions around a photo's day, oldest first.

@ProviderFor(workoutsAroundPhoto)
final workoutsAroundPhotoProvider = WorkoutsAroundPhotoFamily._();

/// The finished sessions around a photo's day, oldest first.

final class WorkoutsAroundPhotoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutRow>>,
          List<WorkoutRow>,
          Stream<List<WorkoutRow>>
        >
    with $FutureModifier<List<WorkoutRow>>, $StreamProvider<List<WorkoutRow>> {
  /// The finished sessions around a photo's day, oldest first.
  WorkoutsAroundPhotoProvider._({
    required WorkoutsAroundPhotoFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'workoutsAroundPhotoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutsAroundPhotoHash();

  @override
  String toString() {
    return r'workoutsAroundPhotoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<WorkoutRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorkoutRow>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return workoutsAroundPhoto(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutsAroundPhotoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutsAroundPhotoHash() =>
    r'433cbdb74d64dab4cf2e5fad6d2311f82f524d17';

/// The finished sessions around a photo's day, oldest first.

final class WorkoutsAroundPhotoFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<WorkoutRow>>, DateTime> {
  WorkoutsAroundPhotoFamily._()
    : super(
        retry: null,
        name: r'workoutsAroundPhotoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The finished sessions around a photo's day, oldest first.

  WorkoutsAroundPhotoProvider call(DateTime takenAt) =>
      WorkoutsAroundPhotoProvider._(argument: takenAt, from: this);

  @override
  String toString() => r'workoutsAroundPhotoProvider';
}

/// The session a photo points at, or null when it points at none.

@ProviderFor(photoWorkout)
final photoWorkoutProvider = PhotoWorkoutFamily._();

/// The session a photo points at, or null when it points at none.

final class PhotoWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutRow?>,
          WorkoutRow?,
          Stream<WorkoutRow?>
        >
    with $FutureModifier<WorkoutRow?>, $StreamProvider<WorkoutRow?> {
  /// The session a photo points at, or null when it points at none.
  PhotoWorkoutProvider._({
    required PhotoWorkoutFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'photoWorkoutProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$photoWorkoutHash();

  @override
  String toString() {
    return r'photoWorkoutProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WorkoutRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutRow?> create(Ref ref) {
    final argument = this.argument as String?;
    return photoWorkout(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PhotoWorkoutProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$photoWorkoutHash() => r'b4a904f177a02da9e5cbb0d7fb81825628704360';

/// The session a photo points at, or null when it points at none.

final class PhotoWorkoutFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WorkoutRow?>, String?> {
  PhotoWorkoutFamily._()
    : super(
        retry: null,
        name: r'photoWorkoutProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The session a photo points at, or null when it points at none.

  PhotoWorkoutProvider call(String? workoutId) =>
      PhotoWorkoutProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'photoWorkoutProvider';
}

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
        isAutoDispose: false,
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

String _$photoActionsHash() => r'981cfd214799e697b125fb7c7e965fc1636d352a';
