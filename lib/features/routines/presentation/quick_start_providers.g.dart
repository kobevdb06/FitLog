// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_start_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(quickStartService)
final quickStartServiceProvider = QuickStartServiceProvider._();

final class QuickStartServiceProvider
    extends
        $FunctionalProvider<
          QuickStartService,
          QuickStartService,
          QuickStartService
        >
    with $Provider<QuickStartService> {
  QuickStartServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickStartServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickStartServiceHash();

  @$internal
  @override
  $ProviderElement<QuickStartService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  QuickStartService create(Ref ref) {
    return quickStartService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QuickStartService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QuickStartService>(value),
    );
  }
}

String _$quickStartServiceHash() => r'75dbe420c3421359ee4a76e08bdc310584077622';

/// The starred routines that have a place on the home screen, most used first.

@ProviderFor(quickStartRoutines)
final quickStartRoutinesProvider = QuickStartRoutinesProvider._();

/// The starred routines that have a place on the home screen, most used first.

final class QuickStartRoutinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutineRow>>,
          List<RoutineRow>,
          Stream<List<RoutineRow>>
        >
    with $FutureModifier<List<RoutineRow>>, $StreamProvider<List<RoutineRow>> {
  /// The starred routines that have a place on the home screen, most used first.
  QuickStartRoutinesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickStartRoutinesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickStartRoutinesHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutineRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutineRow>> create(Ref ref) {
    return quickStartRoutines(ref);
  }
}

String _$quickStartRoutinesHash() =>
    r'6a2c1fc8d96c0451087bd9d6c1c4e0d749893966';

/// The routine a home-screen shortcut asked for, waiting to be started.
///
/// Set the moment Android hands the tap over, which can be while the app is
/// still on the lock screen. It stays here until something is in a position to
/// act on it, and is cleared as soon as it has been.

@ProviderFor(PendingQuickStart)
final pendingQuickStartProvider = PendingQuickStartProvider._();

/// The routine a home-screen shortcut asked for, waiting to be started.
///
/// Set the moment Android hands the tap over, which can be while the app is
/// still on the lock screen. It stays here until something is in a position to
/// act on it, and is cleared as soon as it has been.
final class PendingQuickStartProvider
    extends $NotifierProvider<PendingQuickStart, String?> {
  /// The routine a home-screen shortcut asked for, waiting to be started.
  ///
  /// Set the moment Android hands the tap over, which can be while the app is
  /// still on the lock screen. It stays here until something is in a position to
  /// act on it, and is cleared as soon as it has been.
  PendingQuickStartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingQuickStartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingQuickStartHash();

  @$internal
  @override
  PendingQuickStart create() => PendingQuickStart();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingQuickStartHash() => r'03f52f874299ef2b0ebc84aa6c634beadc270a4f';

/// The routine a home-screen shortcut asked for, waiting to be started.
///
/// Set the moment Android hands the tap over, which can be while the app is
/// still on the lock screen. It stays here until something is in a position to
/// act on it, and is cleared as soon as it has been.

abstract class _$PendingQuickStart extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
