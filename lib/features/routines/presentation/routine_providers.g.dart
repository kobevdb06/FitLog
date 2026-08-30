// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(routineFolders)
final routineFoldersProvider = RoutineFoldersProvider._();

final class RoutineFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutineFolderRow>>,
          List<RoutineFolderRow>,
          Stream<List<RoutineFolderRow>>
        >
    with
        $FutureModifier<List<RoutineFolderRow>>,
        $StreamProvider<List<RoutineFolderRow>> {
  RoutineFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routineFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routineFoldersHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutineFolderRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutineFolderRow>> create(Ref ref) {
    return routineFolders(ref);
  }
}

String _$routineFoldersHash() => r'65b8052063d2274a3f1ca94ad9dd5b1b50e9723e';

@ProviderFor(routineSummaries)
final routineSummariesProvider = RoutineSummariesProvider._();

final class RoutineSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutineSummary>>,
          List<RoutineSummary>,
          Stream<List<RoutineSummary>>
        >
    with
        $FutureModifier<List<RoutineSummary>>,
        $StreamProvider<List<RoutineSummary>> {
  RoutineSummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routineSummariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routineSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutineSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutineSummary>> create(Ref ref) {
    return routineSummaries(ref);
  }
}

String _$routineSummariesHash() => r'002f8e348c0e30bae8ca794f315eb6461f254ff4';

@ProviderFor(routineDetail)
final routineDetailProvider = RoutineDetailFamily._();

final class RoutineDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoutineDetail?>,
          RoutineDetail?,
          Stream<RoutineDetail?>
        >
    with $FutureModifier<RoutineDetail?>, $StreamProvider<RoutineDetail?> {
  RoutineDetailProvider._({
    required RoutineDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'routineDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$routineDetailHash();

  @override
  String toString() {
    return r'routineDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<RoutineDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RoutineDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return routineDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoutineDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$routineDetailHash() => r'03632d892b46eb9fdfdbf59727d8aaa962550d80';

final class RoutineDetailFamily extends $Family
    with $FunctionalFamilyOverride<Stream<RoutineDetail?>, String> {
  RoutineDetailFamily._()
    : super(
        retry: null,
        name: r'routineDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RoutineDetailProvider call(String routineId) =>
      RoutineDetailProvider._(argument: routineId, from: this);

  @override
  String toString() => r'routineDetailProvider';
}

/// The routine the dashboard offers to start.

@ProviderFor(suggestedRoutine)
final suggestedRoutineProvider = SuggestedRoutineProvider._();

/// The routine the dashboard offers to start.

final class SuggestedRoutineProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoutineRow?>,
          RoutineRow?,
          FutureOr<RoutineRow?>
        >
    with $FutureModifier<RoutineRow?>, $FutureProvider<RoutineRow?> {
  /// The routine the dashboard offers to start.
  SuggestedRoutineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suggestedRoutineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suggestedRoutineHash();

  @$internal
  @override
  $FutureProviderElement<RoutineRow?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RoutineRow?> create(Ref ref) {
    return suggestedRoutine(ref);
  }
}

String _$suggestedRoutineHash() => r'bdf56a76bf213331cfd6de59a3321de05ef0b93a';

@ProviderFor(routineActions)
final routineActionsProvider = RoutineActionsProvider._();

final class RoutineActionsProvider
    extends $FunctionalProvider<RoutineActions, RoutineActions, RoutineActions>
    with $Provider<RoutineActions> {
  RoutineActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routineActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routineActionsHash();

  @$internal
  @override
  $ProviderElement<RoutineActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoutineActions create(Ref ref) {
    return routineActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutineActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutineActions>(value),
    );
  }
}

String _$routineActionsHash() => r'b7925e1a1782a5bd373ce5e07e8d37e3f409a85f';
