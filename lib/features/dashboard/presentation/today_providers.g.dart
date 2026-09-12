// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which blocks the Start tab shows, and in what order.

@ProviderFor(homeLayout)
final homeLayoutProvider = HomeLayoutProvider._();

/// Which blocks the Start tab shows, and in what order.

final class HomeLayoutProvider
    extends $FunctionalProvider<HomeLayout, HomeLayout, HomeLayout>
    with $Provider<HomeLayout> {
  /// Which blocks the Start tab shows, and in what order.
  HomeLayoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeLayoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeLayoutHash();

  @$internal
  @override
  $ProviderElement<HomeLayout> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HomeLayout create(Ref ref) {
    return homeLayout(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeLayout value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeLayout>(value),
    );
  }
}

String _$homeLayoutHash() => r'd25b40b4d214a16118242af2e1a90f52b788e1e0';

/// Every routine that is planned on at least one weekday.

@ProviderFor(scheduledRoutines)
final scheduledRoutinesProvider = ScheduledRoutinesProvider._();

/// Every routine that is planned on at least one weekday.

final class ScheduledRoutinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutineRow>>,
          List<RoutineRow>,
          Stream<List<RoutineRow>>
        >
    with $FutureModifier<List<RoutineRow>>, $StreamProvider<List<RoutineRow>> {
  /// Every routine that is planned on at least one weekday.
  ScheduledRoutinesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledRoutinesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledRoutinesHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutineRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutineRow>> create(Ref ref) {
    return scheduledRoutines(ref);
  }
}

String _$scheduledRoutinesHash() => r'ffb5a99317786b1064bedbdeda04389e66c20908';

/// The starred routines, the ones you actually do most often first.

@ProviderFor(favouriteRoutines)
final favouriteRoutinesProvider = FavouriteRoutinesProvider._();

/// The starred routines, the ones you actually do most often first.

final class FavouriteRoutinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoutineRow>>,
          List<RoutineRow>,
          Stream<List<RoutineRow>>
        >
    with $FutureModifier<List<RoutineRow>>, $StreamProvider<List<RoutineRow>> {
  /// The starred routines, the ones you actually do most often first.
  FavouriteRoutinesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favouriteRoutinesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favouriteRoutinesHash();

  @$internal
  @override
  $StreamProviderElement<List<RoutineRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RoutineRow>> create(Ref ref) {
    return favouriteRoutines(ref);
  }
}

String _$favouriteRoutinesHash() => r'645708f42c2a2844758b10fc41fd029f81ea3bd5';

/// The three of them read as one answer.
///
/// Each part arrives on its own and the card should not blink through three
/// states while they do, so a part that is still loading counts as empty and
/// the ladder simply falls through to the rung below until it lands.

@ProviderFor(todayPlan)
final todayPlanProvider = TodayPlanProvider._();

/// The three of them read as one answer.
///
/// Each part arrives on its own and the card should not blink through three
/// states while they do, so a part that is still loading counts as empty and
/// the ladder simply falls through to the rung below until it lands.

final class TodayPlanProvider
    extends $FunctionalProvider<TodayPlan, TodayPlan, TodayPlan>
    with $Provider<TodayPlan> {
  /// The three of them read as one answer.
  ///
  /// Each part arrives on its own and the card should not blink through three
  /// states while they do, so a part that is still loading counts as empty and
  /// the ladder simply falls through to the rung below until it lands.
  TodayPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayPlanHash();

  @$internal
  @override
  $ProviderElement<TodayPlan> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TodayPlan create(Ref ref) {
    return todayPlan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TodayPlan value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TodayPlan>(value),
    );
  }
}

String _$todayPlanHash() => r'8ebc2bb284f5c25bb23651181b9231e975bb8da3';
