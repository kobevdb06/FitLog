// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The filter the exercise list is showing. Lives above the list so the search
/// field and the chips stay in sync.

@ProviderFor(ExerciseFilterController)
final exerciseFilterControllerProvider = ExerciseFilterControllerProvider._();

/// The filter the exercise list is showing. Lives above the list so the search
/// field and the chips stay in sync.
final class ExerciseFilterControllerProvider
    extends $NotifierProvider<ExerciseFilterController, ExerciseFilter> {
  /// The filter the exercise list is showing. Lives above the list so the search
  /// field and the chips stay in sync.
  ExerciseFilterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseFilterControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exerciseFilterControllerHash();

  @$internal
  @override
  ExerciseFilterController create() => ExerciseFilterController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExerciseFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExerciseFilter>(value),
    );
  }
}

String _$exerciseFilterControllerHash() =>
    r'2b07e1f761af5c48e2ef9f045f5e3ba34bbf4c6f';

/// The filter the exercise list is showing. Lives above the list so the search
/// field and the chips stay in sync.

abstract class _$ExerciseFilterController extends $Notifier<ExerciseFilter> {
  ExerciseFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ExerciseFilter, ExerciseFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ExerciseFilter, ExerciseFilter>,
              ExerciseFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(filteredExercises)
final filteredExercisesProvider = FilteredExercisesProvider._();

final class FilteredExercisesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExerciseRow>>,
          List<ExerciseRow>,
          Stream<List<ExerciseRow>>
        >
    with
        $FutureModifier<List<ExerciseRow>>,
        $StreamProvider<List<ExerciseRow>> {
  FilteredExercisesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredExercisesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredExercisesHash();

  @$internal
  @override
  $StreamProviderElement<List<ExerciseRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ExerciseRow>> create(Ref ref) {
    return filteredExercises(ref);
  }
}

String _$filteredExercisesHash() => r'a69858191b6d4025d4541b81765dfeb2e16e9620';

@ProviderFor(exerciseById)
final exerciseByIdProvider = ExerciseByIdFamily._();

final class ExerciseByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExerciseRow?>,
          ExerciseRow?,
          Stream<ExerciseRow?>
        >
    with $FutureModifier<ExerciseRow?>, $StreamProvider<ExerciseRow?> {
  ExerciseByIdProvider._({
    required ExerciseByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseByIdHash();

  @override
  String toString() {
    return r'exerciseByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ExerciseRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ExerciseRow?> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseByIdHash() => r'51f1a9d357f633c1a444a65debdac12ca5235123';

final class ExerciseByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ExerciseRow?>, String> {
  ExerciseByIdFamily._()
    : super(
        retry: null,
        name: r'exerciseByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExerciseByIdProvider call(String id) =>
      ExerciseByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'exerciseByIdProvider';
}

/// Whether any exercise carries a star, which is when the filter for them
/// earns its place among the others.

@ProviderFor(hasFavouriteExercises)
final hasFavouriteExercisesProvider = HasFavouriteExercisesProvider._();

/// Whether any exercise carries a star, which is when the filter for them
/// earns its place among the others.

final class HasFavouriteExercisesProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether any exercise carries a star, which is when the filter for them
  /// earns its place among the others.
  HasFavouriteExercisesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasFavouriteExercisesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasFavouriteExercisesHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return hasFavouriteExercises(ref);
  }
}

String _$hasFavouriteExercisesHash() =>
    r'c1222ae8160d92b61be0212dc73f5f3af042eba5';

/// Watched rather than read once: adding a muscle group from the picker has to
/// show up in the list you are looking at.

@ProviderFor(muscleOptions)
final muscleOptionsProvider = MuscleOptionsProvider._();

/// Watched rather than read once: adding a muscle group from the picker has to
/// show up in the list you are looking at.

final class MuscleOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  /// Watched rather than read once: adding a muscle group from the picker has to
  /// show up in the list you are looking at.
  MuscleOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'muscleOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$muscleOptionsHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return muscleOptions(ref);
  }
}

String _$muscleOptionsHash() => r'86995b5746f17e839909c0a2314a1ddc6d131fd8';

@ProviderFor(equipmentOptions)
final equipmentOptionsProvider = EquipmentOptionsProvider._();

final class EquipmentOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  EquipmentOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentOptionsHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return equipmentOptions(ref);
  }
}

String _$equipmentOptionsHash() => r'fcb1a682c38df20c4579f558dd97c224c183257d';

/// Only the ones you added yourself, for the screen that manages them.

@ProviderFor(customMuscles)
final customMusclesProvider = CustomMusclesProvider._();

/// Only the ones you added yourself, for the screen that manages them.

final class CustomMusclesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomMuscleRow>>,
          List<CustomMuscleRow>,
          Stream<List<CustomMuscleRow>>
        >
    with
        $FutureModifier<List<CustomMuscleRow>>,
        $StreamProvider<List<CustomMuscleRow>> {
  /// Only the ones you added yourself, for the screen that manages them.
  CustomMusclesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customMusclesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customMusclesHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomMuscleRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomMuscleRow>> create(Ref ref) {
    return customMuscles(ref);
  }
}

String _$customMusclesHash() => r'ef2871f5a716b6edcb3e0864d90f394eb16104df';

@ProviderFor(customEquipment)
final customEquipmentProvider = CustomEquipmentProvider._();

final class CustomEquipmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomEquipmentRow>>,
          List<CustomEquipmentRow>,
          Stream<List<CustomEquipmentRow>>
        >
    with
        $FutureModifier<List<CustomEquipmentRow>>,
        $StreamProvider<List<CustomEquipmentRow>> {
  CustomEquipmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customEquipmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customEquipmentHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomEquipmentRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomEquipmentRow>> create(Ref ref) {
    return customEquipment(ref);
  }
}

String _$customEquipmentHash() => r'c694ab2b81a376569953dfb47b4e3a47df6cbeec';

@ProviderFor(customCategories)
final customCategoriesProvider = CustomCategoriesProvider._();

final class CustomCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CustomCategoryRow>>,
          List<CustomCategoryRow>,
          Stream<List<CustomCategoryRow>>
        >
    with
        $FutureModifier<List<CustomCategoryRow>>,
        $StreamProvider<List<CustomCategoryRow>> {
  CustomCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customCategoriesHash();

  @$internal
  @override
  $StreamProviderElement<List<CustomCategoryRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CustomCategoryRow>> create(Ref ref) {
    return customCategories(ref);
  }
}

String _$customCategoriesHash() => r'aa8276d91bc5e5c23af424a60b2b07c7c4e001af';

/// The categories you can pick from: the built-in eight plus your own.

@ProviderFor(categoryOptions)
final categoryOptionsProvider = CategoryOptionsProvider._();

/// The categories you can pick from: the built-in eight plus your own.

final class CategoryOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoryChoice>>,
          List<CategoryChoice>,
          Stream<List<CategoryChoice>>
        >
    with
        $FutureModifier<List<CategoryChoice>>,
        $StreamProvider<List<CategoryChoice>> {
  /// The categories you can pick from: the built-in eight plus your own.
  CategoryOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryOptionsHash();

  @$internal
  @override
  $StreamProviderElement<List<CategoryChoice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CategoryChoice>> create(Ref ref) {
    return categoryOptions(ref);
  }
}

String _$categoryOptionsHash() => r'717ca1b8b7e0be7185bbe72582d54bb83ffebb84';

/// The exercises used most recently, shown at the top of the picker.

@ProviderFor(recentExercises)
final recentExercisesProvider = RecentExercisesProvider._();

/// The exercises used most recently, shown at the top of the picker.

final class RecentExercisesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExerciseRow>>,
          List<ExerciseRow>,
          FutureOr<List<ExerciseRow>>
        >
    with
        $FutureModifier<List<ExerciseRow>>,
        $FutureProvider<List<ExerciseRow>> {
  /// The exercises used most recently, shown at the top of the picker.
  RecentExercisesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentExercisesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentExercisesHash();

  @$internal
  @override
  $FutureProviderElement<List<ExerciseRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExerciseRow>> create(Ref ref) {
    return recentExercises(ref);
  }
}

String _$recentExercisesHash() => r'd7ddb79eb4e0081cb8e7a8aebbc4e1bdaf8c781b';

@ProviderFor(exerciseSessions)
final exerciseSessionsProvider = ExerciseSessionsFamily._();

final class ExerciseSessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExerciseSession>>,
          List<ExerciseSession>,
          FutureOr<List<ExerciseSession>>
        >
    with
        $FutureModifier<List<ExerciseSession>>,
        $FutureProvider<List<ExerciseSession>> {
  ExerciseSessionsProvider._({
    required ExerciseSessionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseSessionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseSessionsHash();

  @override
  String toString() {
    return r'exerciseSessionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ExerciseSession>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExerciseSession>> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseSessions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseSessionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseSessionsHash() => r'194ce106477d57fea2e786e5855a6dfc84ef7142';

final class ExerciseSessionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ExerciseSession>>, String> {
  ExerciseSessionsFamily._()
    : super(
        retry: null,
        name: r'exerciseSessionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExerciseSessionsProvider call(String exerciseId) =>
      ExerciseSessionsProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'exerciseSessionsProvider';
}

@ProviderFor(exerciseRecords)
final exerciseRecordsProvider = ExerciseRecordsFamily._();

final class ExerciseRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PersonalRecordRow>>,
          List<PersonalRecordRow>,
          Stream<List<PersonalRecordRow>>
        >
    with
        $FutureModifier<List<PersonalRecordRow>>,
        $StreamProvider<List<PersonalRecordRow>> {
  ExerciseRecordsProvider._({
    required ExerciseRecordsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseRecordsHash();

  @override
  String toString() {
    return r'exerciseRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<PersonalRecordRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PersonalRecordRow>> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseRecordsHash() => r'dd9659dc5b5a732cce43c821a105130089d32c2a';

final class ExerciseRecordsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<PersonalRecordRow>>, String> {
  ExerciseRecordsFamily._()
    : super(
        retry: null,
        name: r'exerciseRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExerciseRecordsProvider call(String exerciseId) =>
      ExerciseRecordsProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'exerciseRecordsProvider';
}

@ProviderFor(exerciseUsageCount)
final exerciseUsageCountProvider = ExerciseUsageCountFamily._();

final class ExerciseUsageCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  ExerciseUsageCountProvider._({
    required ExerciseUsageCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseUsageCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseUsageCountHash();

  @override
  String toString() {
    return r'exerciseUsageCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseUsageCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseUsageCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseUsageCountHash() =>
    r'ba1d8f1f302135b0da74378d8bfe562c9181723c';

final class ExerciseUsageCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  ExerciseUsageCountFamily._()
    : super(
        retry: null,
        name: r'exerciseUsageCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExerciseUsageCountProvider call(String exerciseId) =>
      ExerciseUsageCountProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'exerciseUsageCountProvider';
}

/// Creating and editing exercises the user made themselves.
// Kept alive on purpose. These objects hold a `Ref` and every one of their
// callers uses them across an async gap: a confirmation dialog, the photo
// picker, the PR configuration screen. An auto-disposing provider is torn down
// while that gap is open, and the next call throws on a dead `Ref`.

@ProviderFor(exerciseEditor)
final exerciseEditorProvider = ExerciseEditorProvider._();

/// Creating and editing exercises the user made themselves.
// Kept alive on purpose. These objects hold a `Ref` and every one of their
// callers uses them across an async gap: a confirmation dialog, the photo
// picker, the PR configuration screen. An auto-disposing provider is torn down
// while that gap is open, and the next call throws on a dead `Ref`.

final class ExerciseEditorProvider
    extends $FunctionalProvider<ExerciseEditor, ExerciseEditor, ExerciseEditor>
    with $Provider<ExerciseEditor> {
  /// Creating and editing exercises the user made themselves.
  // Kept alive on purpose. These objects hold a `Ref` and every one of their
  // callers uses them across an async gap: a confirmation dialog, the photo
  // picker, the PR configuration screen. An auto-disposing provider is torn down
  // while that gap is open, and the next call throws on a dead `Ref`.
  ExerciseEditorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseEditorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exerciseEditorHash();

  @$internal
  @override
  $ProviderElement<ExerciseEditor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExerciseEditor create(Ref ref) {
    return exerciseEditor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExerciseEditor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExerciseEditor>(value),
    );
  }
}

String _$exerciseEditorHash() => r'0f53a7fb229a54aaabf2fcf75e9a4855e7da5a6d';
