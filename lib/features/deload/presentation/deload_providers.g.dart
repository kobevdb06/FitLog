// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deload_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The deload going on now, or the next one planned; null without either.

@ProviderFor(currentDeload)
final currentDeloadProvider = CurrentDeloadProvider._();

/// The deload going on now, or the next one planned; null without either.

final class CurrentDeloadProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeloadWeekRow?>,
          DeloadWeekRow?,
          Stream<DeloadWeekRow?>
        >
    with $FutureModifier<DeloadWeekRow?>, $StreamProvider<DeloadWeekRow?> {
  /// The deload going on now, or the next one planned; null without either.
  CurrentDeloadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentDeloadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentDeloadHash();

  @$internal
  @override
  $StreamProviderElement<DeloadWeekRow?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DeloadWeekRow?> create(Ref ref) {
    return currentDeload(ref);
  }
}

String _$currentDeloadHash() => r'797e8fc8b9c8574a910f6c157062b2904c1528e8';

/// Why Start proposes a deload now, or null: switched off, put away with
/// Later, one going or planned, or simply not time.

@ProviderFor(deloadSuggestion)
final deloadSuggestionProvider = DeloadSuggestionProvider._();

/// Why Start proposes a deload now, or null: switched off, put away with
/// Later, one going or planned, or simply not time.

final class DeloadSuggestionProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeloadReason?>,
          DeloadReason?,
          FutureOr<DeloadReason?>
        >
    with $FutureModifier<DeloadReason?>, $FutureProvider<DeloadReason?> {
  /// Why Start proposes a deload now, or null: switched off, put away with
  /// Later, one going or planned, or simply not time.
  DeloadSuggestionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deloadSuggestionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deloadSuggestionHash();

  @$internal
  @override
  $FutureProviderElement<DeloadReason?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeloadReason?> create(Ref ref) {
    return deloadSuggestion(ref);
  }
}

String _$deloadSuggestionHash() => r'a6eb9734824b7fc8cb84fab7d0934fd91aef23d8';

@ProviderFor(deloadExample)
final deloadExampleProvider = DeloadExampleProvider._();

final class DeloadExampleProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeloadExample?>,
          DeloadExample?,
          FutureOr<DeloadExample?>
        >
    with $FutureModifier<DeloadExample?>, $FutureProvider<DeloadExample?> {
  DeloadExampleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deloadExampleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deloadExampleHash();

  @$internal
  @override
  $FutureProviderElement<DeloadExample?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeloadExample?> create(Ref ref) {
    return deloadExample(ref);
  }
}

String _$deloadExampleHash() => r'd05ff7fd3c1b2f8ed950d8cf0a2eb3f54eab84ca';
