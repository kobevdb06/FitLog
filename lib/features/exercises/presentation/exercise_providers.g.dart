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
    r'7edf3700836a1807b8a52244f756be8bbc779ae8';

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

@ProviderFor(muscleOptions)
final muscleOptionsProvider = MuscleOptionsProvider._();

final class MuscleOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
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
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return muscleOptions(ref);
  }
}

String _$muscleOptionsHash() => r'd076395016fabe3ebfe786f57a19c1c1fd3ecd80';

@ProviderFor(equipmentOptions)
final equipmentOptionsProvider = EquipmentOptionsProvider._();

final class EquipmentOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
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
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return equipmentOptions(ref);
  }
}

String _$equipmentOptionsHash() => r'd706572e45ad9105b103751a7fd33cb5f4c7f396';

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

@ProviderFor(exerciseEditor)
final exerciseEditorProvider = ExerciseEditorProvider._();

/// Creating and editing exercises the user made themselves.

final class ExerciseEditorProvider
    extends $FunctionalProvider<ExerciseEditor, ExerciseEditor, ExerciseEditor>
    with $Provider<ExerciseEditor> {
  /// Creating and editing exercises the user made themselves.
  ExerciseEditorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseEditorProvider',
        isAutoDispose: true,
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

String _$exerciseEditorHash() => r'39ec59f10950e23e7805194435660737840bd943';
