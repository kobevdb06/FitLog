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

/// The sessions of the week from [start], newest first, with the heart rate
/// a watch measured during them where it did.

@ProviderFor(workoutsInWeek)
final workoutsInWeekProvider = WorkoutsInWeekFamily._();

/// The sessions of the week from [start], newest first, with the heart rate
/// a watch measured during them where it did.

final class WorkoutsInWeekProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutRow>>,
          List<WorkoutRow>,
          Stream<List<WorkoutRow>>
        >
    with $FutureModifier<List<WorkoutRow>>, $StreamProvider<List<WorkoutRow>> {
  /// The sessions of the week from [start], newest first, with the heart rate
  /// a watch measured during them where it did.
  WorkoutsInWeekProvider._({
    required WorkoutsInWeekFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'workoutsInWeekProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutsInWeekHash();

  @override
  String toString() {
    return r'workoutsInWeekProvider'
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
    return workoutsInWeek(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutsInWeekProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutsInWeekHash() => r'4261cd7047b7004ef0c9914c9a9a2a3d90c0fca2';

/// The sessions of the week from [start], newest first, with the heart rate
/// a watch measured during them where it did.

final class WorkoutsInWeekFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<WorkoutRow>>, DateTime> {
  WorkoutsInWeekFamily._()
    : super(
        retry: null,
        name: r'workoutsInWeekProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The sessions of the week from [start], newest first, with the heart rate
  /// a watch measured during them where it did.

  WorkoutsInWeekProvider call(DateTime start) =>
      WorkoutsInWeekProvider._(argument: start, from: this);

  @override
  String toString() => r'workoutsInWeekProvider';
}

/// The watch's daily readings of the health screen's month, as stored - with
/// what [VitalsDay] leaves out, such as whether a resting heart rate was
/// worked out by FitLog.

@ProviderFor(healthDays)
final healthDaysProvider = HealthDaysProvider._();

/// The watch's daily readings of the health screen's month, as stored - with
/// what [VitalsDay] leaves out, such as whether a resting heart rate was
/// worked out by FitLog.

final class HealthDaysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyVitalsRow>>,
          List<DailyVitalsRow>,
          Stream<List<DailyVitalsRow>>
        >
    with
        $FutureModifier<List<DailyVitalsRow>>,
        $StreamProvider<List<DailyVitalsRow>> {
  /// The watch's daily readings of the health screen's month, as stored - with
  /// what [VitalsDay] leaves out, such as whether a resting heart rate was
  /// worked out by FitLog.
  HealthDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthDaysHash();

  @$internal
  @override
  $StreamProviderElement<List<DailyVitalsRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DailyVitalsRow>> create(Ref ref) {
    return healthDays(ref);
  }
}

String _$healthDaysHash() => r'6e4db835afaf3b6c3a71b6b23612b84c7f8cb2a2';

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
