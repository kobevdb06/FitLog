// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exact_timer_tile.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether Android lets the rest timer's notification come on the second.
///
/// A provider so a test can say either, and the screen can ask again when
/// the user comes back from the system page where it is switched on.

@ProviderFor(exactRestTimer)
final exactRestTimerProvider = ExactRestTimerProvider._();

/// Whether Android lets the rest timer's notification come on the second.
///
/// A provider so a test can say either, and the screen can ask again when
/// the user comes back from the system page where it is switched on.

final class ExactRestTimerProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether Android lets the rest timer's notification come on the second.
  ///
  /// A provider so a test can say either, and the screen can ask again when
  /// the user comes back from the system page where it is switched on.
  ExactRestTimerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exactRestTimerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exactRestTimerHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return exactRestTimer(ref);
  }
}

String _$exactRestTimerHash() => r'd4607bebc3bf3845c242557f4ccb2f745f7288fd';
