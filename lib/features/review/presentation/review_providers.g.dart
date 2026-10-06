// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The week from [start], worked out from the logbook as it is now.

@ProviderFor(weekFacts)
final weekFactsProvider = WeekFactsFamily._();

/// The week from [start], worked out from the logbook as it is now.

final class WeekFactsProvider
    extends
        $FunctionalProvider<
          AsyncValue<WeekFacts>,
          WeekFacts,
          FutureOr<WeekFacts>
        >
    with $FutureModifier<WeekFacts>, $FutureProvider<WeekFacts> {
  /// The week from [start], worked out from the logbook as it is now.
  WeekFactsProvider._({
    required WeekFactsFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'weekFactsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$weekFactsHash();

  @override
  String toString() {
    return r'weekFactsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WeekFacts> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<WeekFacts> create(Ref ref) {
    final argument = this.argument as DateTime;
    return weekFacts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WeekFactsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$weekFactsHash() => r'46f15f5abe3d9ba632c1e4d6ca0bd7c966fb55a1';

/// The week from [start], worked out from the logbook as it is now.

final class WeekFactsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WeekFacts>, DateTime> {
  WeekFactsFamily._()
    : super(
        retry: null,
        name: r'weekFactsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The week from [start], worked out from the logbook as it is now.

  WeekFactsProvider call(DateTime start) =>
      WeekFactsProvider._(argument: start, from: this);

  @override
  String toString() => r'weekFactsProvider';
}
