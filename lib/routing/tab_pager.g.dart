// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab_pager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the pager is between the tabs, as a fraction: 1.5 is halfway from the
/// second to the third.
///
/// The navigation bar reads it so it can move with your finger instead of
/// waiting for the page to land. Kept out of the router's own state on
/// purpose: it changes on every frame of a drag, and nothing else should
/// rebuild for that.

@ProviderFor(tabPosition)
final tabPositionProvider = TabPositionProvider._();

/// Where the pager is between the tabs, as a fraction: 1.5 is halfway from the
/// second to the third.
///
/// The navigation bar reads it so it can move with your finger instead of
/// waiting for the page to land. Kept out of the router's own state on
/// purpose: it changes on every frame of a drag, and nothing else should
/// rebuild for that.

final class TabPositionProvider
    extends
        $FunctionalProvider<
          ValueNotifier<double>,
          ValueNotifier<double>,
          ValueNotifier<double>
        >
    with $Provider<ValueNotifier<double>> {
  /// Where the pager is between the tabs, as a fraction: 1.5 is halfway from the
  /// second to the third.
  ///
  /// The navigation bar reads it so it can move with your finger instead of
  /// waiting for the page to land. Kept out of the router's own state on
  /// purpose: it changes on every frame of a drag, and nothing else should
  /// rebuild for that.
  TabPositionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabPositionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabPositionHash();

  @$internal
  @override
  $ProviderElement<ValueNotifier<double>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ValueNotifier<double> create(Ref ref) {
    return tabPosition(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ValueNotifier<double> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ValueNotifier<double>>(value),
    );
  }
}

String _$tabPositionHash() => r'9f0817ba3653e99a5517e0dfd8d4108eb915fd72';
