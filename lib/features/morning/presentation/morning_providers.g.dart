// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'morning_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The last week or so of reports, newest first.

@ProviderFor(morningReports)
final morningReportsProvider = MorningReportsProvider._();

/// The last week or so of reports, newest first.

final class MorningReportsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MorningReport>>,
          List<MorningReport>,
          Stream<List<MorningReport>>
        >
    with
        $FutureModifier<List<MorningReport>>,
        $StreamProvider<List<MorningReport>> {
  /// The last week or so of reports, newest first.
  MorningReportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningReportsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningReportsHash();

  @$internal
  @override
  $StreamProviderElement<List<MorningReport>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MorningReport>> create(Ref ref) {
    return morningReports(ref);
  }
}

String _$morningReportsHash() => r'17f428179e6134c59f890f410064843854f77393';

/// Making a report now, from the button on the recovery screen.

@ProviderFor(MorningController)
final morningControllerProvider = MorningControllerProvider._();

/// Making a report now, from the button on the recovery screen.
final class MorningControllerProvider
    extends $NotifierProvider<MorningController, MorningState> {
  /// Making a report now, from the button on the recovery screen.
  MorningControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningControllerHash();

  @$internal
  @override
  MorningController create() => MorningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MorningState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MorningState>(value),
    );
  }
}

String _$morningControllerHash() => r'f80a043daf194f29d16036313c31351282155e82';

/// Making a report now, from the button on the recovery screen.

abstract class _$MorningController extends $Notifier<MorningState> {
  MorningState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MorningState, MorningState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MorningState, MorningState>,
              MorningState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
