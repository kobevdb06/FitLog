// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recovery_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What you said about your muscles over the stretch the estimate looks at.

@ProviderFor(sorenessChecks)
final sorenessChecksProvider = SorenessChecksProvider._();

/// What you said about your muscles over the stretch the estimate looks at.

final class SorenessChecksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SorenessCheck>>,
          List<SorenessCheck>,
          Stream<List<SorenessCheck>>
        >
    with
        $FutureModifier<List<SorenessCheck>>,
        $StreamProvider<List<SorenessCheck>> {
  /// What you said about your muscles over the stretch the estimate looks at.
  SorenessChecksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sorenessChecksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sorenessChecksHash();

  @$internal
  @override
  $StreamProviderElement<List<SorenessCheck>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SorenessCheck>> create(Ref ref) {
    return sorenessChecks(ref);
  }
}

String _$sorenessChecksHash() => r'7a639aa2091ad7b6d4d114fc2161305ab543996b';

/// The nights you filled in over the stretch the estimate looks at, oldest
/// first - as stored, stages and all, for the screen that shows them.

@ProviderFor(sleepEntries)
final sleepEntriesProvider = SleepEntriesProvider._();

/// The nights you filled in over the stretch the estimate looks at, oldest
/// first - as stored, stages and all, for the screen that shows them.

final class SleepEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SleepEntryRow>>,
          List<SleepEntryRow>,
          Stream<List<SleepEntryRow>>
        >
    with
        $FutureModifier<List<SleepEntryRow>>,
        $StreamProvider<List<SleepEntryRow>> {
  /// The nights you filled in over the stretch the estimate looks at, oldest
  /// first - as stored, stages and all, for the screen that shows them.
  SleepEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<SleepEntryRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SleepEntryRow>> create(Ref ref) {
    return sleepEntries(ref);
  }
}

String _$sleepEntriesHash() => r'8af3b153027e6cce1fda3d4ce1022b3b40744ccb';

/// One estimate per muscle group, newest session first.
///
/// A stream rather than a future: finishing a workout, editing a set and
/// rating a session all change the answer, and drift re-runs the query when
/// the tables behind it change. So does saying how a muscle feels: the
/// answers are watched here, and a new one rebuilds the estimate.

@ProviderFor(recoveryEstimates)
final recoveryEstimatesProvider = RecoveryEstimatesProvider._();

/// One estimate per muscle group, newest session first.
///
/// A stream rather than a future: finishing a workout, editing a set and
/// rating a session all change the answer, and drift re-runs the query when
/// the tables behind it change. So does saying how a muscle feels: the
/// answers are watched here, and a new one rebuilds the estimate.

final class RecoveryEstimatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecoveryEstimate>>,
          List<RecoveryEstimate>,
          Stream<List<RecoveryEstimate>>
        >
    with
        $FutureModifier<List<RecoveryEstimate>>,
        $StreamProvider<List<RecoveryEstimate>> {
  /// One estimate per muscle group, newest session first.
  ///
  /// A stream rather than a future: finishing a workout, editing a set and
  /// rating a session all change the answer, and drift re-runs the query when
  /// the tables behind it change. So does saying how a muscle feels: the
  /// answers are watched here, and a new one rebuilds the estimate.
  RecoveryEstimatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recoveryEstimatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recoveryEstimatesHash();

  @$internal
  @override
  $StreamProviderElement<List<RecoveryEstimate>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RecoveryEstimate>> create(Ref ref) {
    return recoveryEstimates(ref);
  }
}

String _$recoveryEstimatesHash() => r'9f70bd42c9f624c67fe2740919fd9f76b8998f69';

/// The muscles one particular session left behind.
///
/// Filtered out of the whole picture rather than computed separately: a muscle
/// belongs to this workout's card exactly when this workout is the last thing
/// that trained it.
///
/// Null while the estimate is still being read, which is what tells the card
/// to wait rather than to say there is nothing.

@ProviderFor(workoutRecovery)
final workoutRecoveryProvider = WorkoutRecoveryFamily._();

/// The muscles one particular session left behind.
///
/// Filtered out of the whole picture rather than computed separately: a muscle
/// belongs to this workout's card exactly when this workout is the last thing
/// that trained it.
///
/// Null while the estimate is still being read, which is what tells the card
/// to wait rather than to say there is nothing.

final class WorkoutRecoveryProvider
    extends
        $FunctionalProvider<
          List<RecoveryEstimate>?,
          List<RecoveryEstimate>?,
          List<RecoveryEstimate>?
        >
    with $Provider<List<RecoveryEstimate>?> {
  /// The muscles one particular session left behind.
  ///
  /// Filtered out of the whole picture rather than computed separately: a muscle
  /// belongs to this workout's card exactly when this workout is the last thing
  /// that trained it.
  ///
  /// Null while the estimate is still being read, which is what tells the card
  /// to wait rather than to say there is nothing.
  WorkoutRecoveryProvider._({
    required WorkoutRecoveryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutRecoveryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutRecoveryHash();

  @override
  String toString() {
    return r'workoutRecoveryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<RecoveryEstimate>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<RecoveryEstimate>? create(Ref ref) {
    final argument = this.argument as String;
    return workoutRecovery(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<RecoveryEstimate>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<RecoveryEstimate>?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutRecoveryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutRecoveryHash() => r'8c06741c588875ea28018ae276d4c6cc3b9b07b4';

/// The muscles one particular session left behind.
///
/// Filtered out of the whole picture rather than computed separately: a muscle
/// belongs to this workout's card exactly when this workout is the last thing
/// that trained it.
///
/// Null while the estimate is still being read, which is what tells the card
/// to wait rather than to say there is nothing.

final class WorkoutRecoveryFamily extends $Family
    with $FunctionalFamilyOverride<List<RecoveryEstimate>?, String> {
  WorkoutRecoveryFamily._()
    : super(
        retry: null,
        name: r'workoutRecoveryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The muscles one particular session left behind.
  ///
  /// Filtered out of the whole picture rather than computed separately: a muscle
  /// belongs to this workout's card exactly when this workout is the last thing
  /// that trained it.
  ///
  /// Null while the estimate is still being read, which is what tells the card
  /// to wait rather than to say there is nothing.

  WorkoutRecoveryProvider call(String workoutId) =>
      WorkoutRecoveryProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutRecoveryProvider';
}

/// Writes how heavy the session felt.

@ProviderFor(recoveryActions)
final recoveryActionsProvider = RecoveryActionsProvider._();

/// Writes how heavy the session felt.

final class RecoveryActionsProvider
    extends
        $FunctionalProvider<RecoveryActions, RecoveryActions, RecoveryActions>
    with $Provider<RecoveryActions> {
  /// Writes how heavy the session felt.
  RecoveryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recoveryActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recoveryActionsHash();

  @$internal
  @override
  $ProviderElement<RecoveryActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecoveryActions create(Ref ref) {
    return recoveryActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecoveryActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecoveryActions>(value),
    );
  }
}

String _$recoveryActionsHash() => r'e64f652ccb11661ff2b284b612902ed702acf53c';
