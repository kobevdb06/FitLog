// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pr_attempt_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(prBaseline)
final prBaselineProvider = PrBaselineFamily._();

final class PrBaselineProvider
    extends
        $FunctionalProvider<
          AsyncValue<PrBaseline>,
          PrBaseline,
          FutureOr<PrBaseline>
        >
    with $FutureModifier<PrBaseline>, $FutureProvider<PrBaseline> {
  PrBaselineProvider._({
    required PrBaselineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prBaselineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prBaselineHash();

  @override
  String toString() {
    return r'prBaselineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PrBaseline> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PrBaseline> create(Ref ref) {
    final argument = this.argument as String;
    return prBaseline(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PrBaselineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prBaselineHash() => r'39214f05a048e97197603323192a5cf37d909882';

final class PrBaselineFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PrBaseline>, String> {
  PrBaselineFamily._()
    : super(
        retry: null,
        name: r'prBaselineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PrBaselineProvider call(String exerciseId) =>
      PrBaselineProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'prBaselineProvider';
}

@ProviderFor(prAttemptActions)
final prAttemptActionsProvider = PrAttemptActionsProvider._();

final class PrAttemptActionsProvider
    extends
        $FunctionalProvider<
          PrAttemptActions,
          PrAttemptActions,
          PrAttemptActions
        >
    with $Provider<PrAttemptActions> {
  PrAttemptActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'prAttemptActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$prAttemptActionsHash();

  @$internal
  @override
  $ProviderElement<PrAttemptActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrAttemptActions create(Ref ref) {
    return prAttemptActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrAttemptActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrAttemptActions>(value),
    );
  }
}

String _$prAttemptActionsHash() => r'941a7e862c9db7e24a004552db14fdd19ef82456';
