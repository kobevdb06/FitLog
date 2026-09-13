// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The running session, or null. Everything on the active workout screen is
/// derived from this one stream, so a write to the database is the only way
/// the UI ever changes.

@ProviderFor(activeWorkout)
final activeWorkoutProvider = ActiveWorkoutProvider._();

/// The running session, or null. Everything on the active workout screen is
/// derived from this one stream, so a write to the database is the only way
/// the UI ever changes.

final class ActiveWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutDetail?>,
          WorkoutDetail?,
          Stream<WorkoutDetail?>
        >
    with $FutureModifier<WorkoutDetail?>, $StreamProvider<WorkoutDetail?> {
  /// The running session, or null. Everything on the active workout screen is
  /// derived from this one stream, so a write to the database is the only way
  /// the UI ever changes.
  ActiveWorkoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkoutHash();

  @$internal
  @override
  $StreamProviderElement<WorkoutDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WorkoutDetail?> create(Ref ref) {
    return activeWorkout(ref);
  }
}

String _$activeWorkoutHash() => r'5b6903ee8bfb1d6308d47351b30e6023c4423125';

/// What every exercise in the running session looked like last time.
///
/// One provider for the whole session rather than two per exercise per side.
/// The old pair each awaited the running workout itself while needing nothing
/// from it but the id, so every set you ticked off re-ran six queries about a
/// session that cannot have changed - and rebuilt the screen once per answer.
///
/// [lineUp] is what it is really keyed on: adding an exercise mid-session has
/// to bring its history along, and nothing else about the session can change
/// what came before it.

@ProviderFor(previousSession)
final previousSessionProvider = PreviousSessionFamily._();

/// What every exercise in the running session looked like last time.
///
/// One provider for the whole session rather than two per exercise per side.
/// The old pair each awaited the running workout itself while needing nothing
/// from it but the id, so every set you ticked off re-ran six queries about a
/// session that cannot have changed - and rebuilt the screen once per answer.
///
/// [lineUp] is what it is really keyed on: adding an exercise mid-session has
/// to bring its history along, and nothing else about the session can change
/// what came before it.

final class PreviousSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<PreviousSession>,
          PreviousSession,
          FutureOr<PreviousSession>
        >
    with $FutureModifier<PreviousSession>, $FutureProvider<PreviousSession> {
  /// What every exercise in the running session looked like last time.
  ///
  /// One provider for the whole session rather than two per exercise per side.
  /// The old pair each awaited the running workout itself while needing nothing
  /// from it but the id, so every set you ticked off re-ran six queries about a
  /// session that cannot have changed - and rebuilt the screen once per answer.
  ///
  /// [lineUp] is what it is really keyed on: adding an exercise mid-session has
  /// to bring its history along, and nothing else about the session can change
  /// what came before it.
  PreviousSessionProvider._({
    required PreviousSessionFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'previousSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$previousSessionHash();

  @override
  String toString() {
    return r'previousSessionProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PreviousSession> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PreviousSession> create(Ref ref) {
    final argument = this.argument as (String, String);
    return previousSession(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is PreviousSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$previousSessionHash() => r'9d2c29449962a08972ee8114de82c962ae2229fe';

/// What every exercise in the running session looked like last time.
///
/// One provider for the whole session rather than two per exercise per side.
/// The old pair each awaited the running workout itself while needing nothing
/// from it but the id, so every set you ticked off re-ran six queries about a
/// session that cannot have changed - and rebuilt the screen once per answer.
///
/// [lineUp] is what it is really keyed on: adding an exercise mid-session has
/// to bring its history along, and nothing else about the session can change
/// what came before it.

final class PreviousSessionFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<PreviousSession>, (String, String)> {
  PreviousSessionFamily._()
    : super(
        retry: null,
        name: r'previousSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What every exercise in the running session looked like last time.
  ///
  /// One provider for the whole session rather than two per exercise per side.
  /// The old pair each awaited the running workout itself while needing nothing
  /// from it but the id, so every set you ticked off re-ran six queries about a
  /// session that cannot have changed - and rebuilt the screen once per answer.
  ///
  /// [lineUp] is what it is really keyed on: adding an exercise mid-session has
  /// to bring its history along, and nothing else about the session can change
  /// what came before it.

  PreviousSessionProvider call(String workoutId, String lineUp) =>
      PreviousSessionProvider._(argument: (workoutId, lineUp), from: this);

  @override
  String toString() => r'previousSessionProvider';
}

/// The set ids in this workout that produced a personal record.

@ProviderFor(workoutRecordSetIds)
final workoutRecordSetIdsProvider = WorkoutRecordSetIdsFamily._();

/// The set ids in this workout that produced a personal record.

final class WorkoutRecordSetIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// The set ids in this workout that produced a personal record.
  WorkoutRecordSetIdsProvider._({
    required WorkoutRecordSetIdsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutRecordSetIdsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutRecordSetIdsHash();

  @override
  String toString() {
    return r'workoutRecordSetIdsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    final argument = this.argument as String;
    return workoutRecordSetIds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutRecordSetIdsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutRecordSetIdsHash() =>
    r'e17e7f1361ca7c8e46f89dd4e449dac6db1a98b5';

/// The set ids in this workout that produced a personal record.

final class WorkoutRecordSetIdsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Set<String>>, String> {
  WorkoutRecordSetIdsFamily._()
    : super(
        retry: null,
        name: r'workoutRecordSetIdsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The set ids in this workout that produced a personal record.

  WorkoutRecordSetIdsProvider call(String workoutId) =>
      WorkoutRecordSetIdsProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutRecordSetIdsProvider';
}

/// The records achieved during one workout.

@ProviderFor(workoutRecords)
final workoutRecordsProvider = WorkoutRecordsFamily._();

/// The records achieved during one workout.

final class WorkoutRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecordWithExercise>>,
          List<RecordWithExercise>,
          FutureOr<List<RecordWithExercise>>
        >
    with
        $FutureModifier<List<RecordWithExercise>>,
        $FutureProvider<List<RecordWithExercise>> {
  /// The records achieved during one workout.
  WorkoutRecordsProvider._({
    required WorkoutRecordsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutRecordsHash();

  @override
  String toString() {
    return r'workoutRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RecordWithExercise>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecordWithExercise>> create(Ref ref) {
    final argument = this.argument as String;
    return workoutRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutRecordsHash() => r'c3bab233c88ca575631a3cc36fa3c8f9b565ec1b';

/// The records achieved during one workout.

final class WorkoutRecordsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RecordWithExercise>>, String> {
  WorkoutRecordsFamily._()
    : super(
        retry: null,
        name: r'workoutRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The records achieved during one workout.

  WorkoutRecordsProvider call(String workoutId) =>
      WorkoutRecordsProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutRecordsProvider';
}

/// Drives the rest timer. Kept alive so it survives navigation between the
/// workout screen and the full screen countdown.

@ProviderFor(RestTimer)
final restTimerProvider = RestTimerProvider._();

/// Drives the rest timer. Kept alive so it survives navigation between the
/// workout screen and the full screen countdown.
final class RestTimerProvider
    extends $NotifierProvider<RestTimer, RestTimerState> {
  /// Drives the rest timer. Kept alive so it survives navigation between the
  /// workout screen and the full screen countdown.
  RestTimerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restTimerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restTimerHash();

  @$internal
  @override
  RestTimer create() => RestTimer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RestTimerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RestTimerState>(value),
    );
  }
}

String _$restTimerHash() => r'105ce169229ed5008f8ad038c3ef1802796870f4';

/// Drives the rest timer. Kept alive so it survives navigation between the
/// workout screen and the full screen countdown.

abstract class _$RestTimer extends $Notifier<RestTimerState> {
  RestTimerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RestTimerState, RestTimerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RestTimerState, RestTimerState>,
              RestTimerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Every write the active workout screen performs.
///
/// There is no "save" button anywhere: each call lands in the database
/// immediately and the UI re-renders from [activeWorkoutProvider].

@ProviderFor(workoutController)
final workoutControllerProvider = WorkoutControllerProvider._();

/// Every write the active workout screen performs.
///
/// There is no "save" button anywhere: each call lands in the database
/// immediately and the UI re-renders from [activeWorkoutProvider].

final class WorkoutControllerProvider
    extends
        $FunctionalProvider<
          WorkoutController,
          WorkoutController,
          WorkoutController
        >
    with $Provider<WorkoutController> {
  /// Every write the active workout screen performs.
  ///
  /// There is no "save" button anywhere: each call lands in the database
  /// immediately and the UI re-renders from [activeWorkoutProvider].
  WorkoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutControllerHash();

  @$internal
  @override
  $ProviderElement<WorkoutController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutController create(Ref ref) {
    return workoutController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutController>(value),
    );
  }
}

String _$workoutControllerHash() => r'1ee0a5edef1640970914e555a1cce79a4a4ec717';
