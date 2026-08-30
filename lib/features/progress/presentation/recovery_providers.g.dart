// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recovery_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One estimate per muscle group, newest session first.
///
/// A stream rather than a future: finishing a workout, editing a set and
/// rating a session all change the answer, and drift re-runs the query when
/// the tables behind it change.

@ProviderFor(recoveryEstimates)
final recoveryEstimatesProvider = RecoveryEstimatesProvider._();

/// One estimate per muscle group, newest session first.
///
/// A stream rather than a future: finishing a workout, editing a set and
/// rating a session all change the answer, and drift re-runs the query when
/// the tables behind it change.

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
  /// the tables behind it change.
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

String _$recoveryEstimatesHash() => r'857c51675757df89088a50f1280d64882c10b9d1';

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
