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

/// Someone asked, from somewhere else in the app, to arrange the Start tab.
///
/// Arranging happens on the Start tab itself now, so Instellingen cannot show
/// it - it can only send you there. The tab is already built and sitting in
/// the pager, so it hears this and switches itself on.

@ProviderFor(HomeArrangeRequest)
final homeArrangeRequestProvider = HomeArrangeRequestProvider._();

/// Someone asked, from somewhere else in the app, to arrange the Start tab.
///
/// Arranging happens on the Start tab itself now, so Instellingen cannot show
/// it - it can only send you there. The tab is already built and sitting in
/// the pager, so it hears this and switches itself on.
final class HomeArrangeRequestProvider
    extends $NotifierProvider<HomeArrangeRequest, bool> {
  /// Someone asked, from somewhere else in the app, to arrange the Start tab.
  ///
  /// Arranging happens on the Start tab itself now, so Instellingen cannot show
  /// it - it can only send you there. The tab is already built and sitting in
  /// the pager, so it hears this and switches itself on.
  HomeArrangeRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeArrangeRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeArrangeRequestHash();

  @$internal
  @override
  HomeArrangeRequest create() => HomeArrangeRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$homeArrangeRequestHash() =>
    r'f2e446fd3fde445152ee3ccc42b0dd97ac1f01aa';

/// Someone asked, from somewhere else in the app, to arrange the Start tab.
///
/// Arranging happens on the Start tab itself now, so Instellingen cannot show
/// it - it can only send you there. The tab is already built and sitting in
/// the pager, so it hears this and switches itself on.

abstract class _$HomeArrangeRequest extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether a block has anything to say right now.
///
/// A block with nothing in it draws nothing, and a slot on the grid for
/// nothing is a hole between two cards. The grid asks this before it makes
/// room and the block asks it before it draws, so the rule stays in one place.

@ProviderFor(homeBlockFilled)
final homeBlockFilledProvider = HomeBlockFilledFamily._();

/// Whether a block has anything to say right now.
///
/// A block with nothing in it draws nothing, and a slot on the grid for
/// nothing is a hole between two cards. The grid asks this before it makes
/// room and the block asks it before it draws, so the rule stays in one place.

final class HomeBlockFilledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether a block has anything to say right now.
  ///
  /// A block with nothing in it draws nothing, and a slot on the grid for
  /// nothing is a hole between two cards. The grid asks this before it makes
  /// room and the block asks it before it draws, so the rule stays in one place.
  HomeBlockFilledProvider._({
    required HomeBlockFilledFamily super.from,
    required HomeBlock super.argument,
  }) : super(
         retry: null,
         name: r'homeBlockFilledProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeBlockFilledHash();

  @override
  String toString() {
    return r'homeBlockFilledProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as HomeBlock;
    return homeBlockFilled(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeBlockFilledProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeBlockFilledHash() => r'3640860986267afc539bcd9ef99e1ac1e07951e6';

/// Whether a block has anything to say right now.
///
/// A block with nothing in it draws nothing, and a slot on the grid for
/// nothing is a hole between two cards. The grid asks this before it makes
/// room and the block asks it before it draws, so the rule stays in one place.

final class HomeBlockFilledFamily extends $Family
    with $FunctionalFamilyOverride<bool, HomeBlock> {
  HomeBlockFilledFamily._()
    : super(
        retry: null,
        name: r'homeBlockFilledProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether a block has anything to say right now.
  ///
  /// A block with nothing in it draws nothing, and a slot on the grid for
  /// nothing is a hole between two cards. The grid asks this before it makes
  /// room and the block asks it before it draws, so the rule stays in one place.

  HomeBlockFilledProvider call(HomeBlock block) =>
      HomeBlockFilledProvider._(argument: block, from: this);

  @override
  String toString() => r'homeBlockFilledProvider';
}

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
