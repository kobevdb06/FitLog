// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CoachSessionController)
final coachSessionControllerProvider = CoachSessionControllerProvider._();

final class CoachSessionControllerProvider
    extends $NotifierProvider<CoachSessionController, CoachSession> {
  CoachSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachSessionControllerHash();

  @$internal
  @override
  CoachSessionController create() => CoachSessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachSession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachSession>(value),
    );
  }
}

String _$coachSessionControllerHash() =>
    r'0003135acd687110f187cf36b0d858ea16d832f0';

abstract class _$CoachSessionController extends $Notifier<CoachSession> {
  CoachSession build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CoachSession, CoachSession>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoachSession, CoachSession>,
              CoachSession,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
