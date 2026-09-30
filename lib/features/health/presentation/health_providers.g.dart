// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where Health Connect is reached. Overridden in tests with one that
/// answers from memory.

@ProviderFor(healthSource)
final healthSourceProvider = HealthSourceProvider._();

/// Where Health Connect is reached. Overridden in tests with one that
/// answers from memory.

final class HealthSourceProvider
    extends $FunctionalProvider<HealthSource, HealthSource, HealthSource>
    with $Provider<HealthSource> {
  /// Where Health Connect is reached. Overridden in tests with one that
  /// answers from memory.
  HealthSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthSourceHash();

  @$internal
  @override
  $ProviderElement<HealthSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HealthSource create(Ref ref) {
    return healthSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthSource>(value),
    );
  }
}

String _$healthSourceHash() => r'50b5abfbad6b36f42aae0b6d610c1b35b97d22fc';

/// Whether Health Connect is on this phone and usable.

@ProviderFor(healthAvailability)
final healthAvailabilityProvider = HealthAvailabilityProvider._();

/// Whether Health Connect is on this phone and usable.

final class HealthAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<HealthAvailability>,
          HealthAvailability,
          FutureOr<HealthAvailability>
        >
    with
        $FutureModifier<HealthAvailability>,
        $FutureProvider<HealthAvailability> {
  /// Whether Health Connect is on this phone and usable.
  HealthAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthAvailabilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthAvailabilityHash();

  @$internal
  @override
  $FutureProviderElement<HealthAvailability> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HealthAvailability> create(Ref ref) {
    return healthAvailability(ref);
  }
}

String _$healthAvailabilityHash() =>
    r'05cf8acd580acd1e2a633041d5499c51f958e625';

/// What FitLog asks for but may not read, while connected. Asked again when
/// the screen comes back, so a change made in Health Connect itself shows.

@ProviderFor(healthMissingAccess)
final healthMissingAccessProvider = HealthMissingAccessProvider._();

/// What FitLog asks for but may not read, while connected. Asked again when
/// the screen comes back, so a change made in Health Connect itself shows.

final class HealthMissingAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// What FitLog asks for but may not read, while connected. Asked again when
  /// the screen comes back, so a change made in Health Connect itself shows.
  HealthMissingAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthMissingAccessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthMissingAccessHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return healthMissingAccess(ref);
  }
}

String _$healthMissingAccessHash() =>
    r'dee521003d5c3d82e8bf1dfeb347711f2a68a58a';

/// The newest sessions with the heart rate a watch measured during them.

@ProviderFor(workoutHeartRates)
final workoutHeartRatesProvider = WorkoutHeartRatesProvider._();

/// The newest sessions with the heart rate a watch measured during them.

final class WorkoutHeartRatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutRow>>,
          List<WorkoutRow>,
          Stream<List<WorkoutRow>>
        >
    with $FutureModifier<List<WorkoutRow>>, $StreamProvider<List<WorkoutRow>> {
  /// The newest sessions with the heart rate a watch measured during them.
  WorkoutHeartRatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutHeartRatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutHeartRatesHash();

  @$internal
  @override
  $StreamProviderElement<List<WorkoutRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorkoutRow>> create(Ref ref) {
    return workoutHeartRates(ref);
  }
}

String _$workoutHeartRatesHash() => r'8aa11500d25ddf49304b6b2dfff5c7af2a785da3';

/// Whether the user connected it.

@ProviderFor(healthConnectEnabled)
final healthConnectEnabledProvider = HealthConnectEnabledProvider._();

/// Whether the user connected it.

final class HealthConnectEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the user connected it.
  HealthConnectEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthConnectEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthConnectEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return healthConnectEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$healthConnectEnabledHash() =>
    r'5b83ed74522b7956ce6f535610e90b7fd54d97f7';

/// Whether finished sessions are written to it as well.

@ProviderFor(healthConnectWritesWorkouts)
final healthConnectWritesWorkoutsProvider =
    HealthConnectWritesWorkoutsProvider._();

/// Whether finished sessions are written to it as well.

final class HealthConnectWritesWorkoutsProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether finished sessions are written to it as well.
  HealthConnectWritesWorkoutsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthConnectWritesWorkoutsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthConnectWritesWorkoutsHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return healthConnectWritesWorkouts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$healthConnectWritesWorkoutsHash() =>
    r'29cb9ff1b6c938caf6f4e37277f8af8ffa1bffe8';

/// Connecting, importing and disconnecting.

@ProviderFor(HealthSync)
final healthSyncProvider = HealthSyncProvider._();

/// Connecting, importing and disconnecting.
final class HealthSyncProvider
    extends $NotifierProvider<HealthSync, HealthSyncState> {
  /// Connecting, importing and disconnecting.
  HealthSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthSyncHash();

  @$internal
  @override
  HealthSync create() => HealthSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthSyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthSyncState>(value),
    );
  }
}

String _$healthSyncHash() => r'0285e24223ec341d9f9d560efdd558127a690696';

/// Connecting, importing and disconnecting.

abstract class _$HealthSync extends $Notifier<HealthSyncState> {
  HealthSyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<HealthSyncState, HealthSyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HealthSyncState, HealthSyncState>,
              HealthSyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
