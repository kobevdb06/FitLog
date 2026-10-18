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
