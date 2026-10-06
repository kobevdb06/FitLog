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

/// What the coach wrote about the week from [start], if it did.

@ProviderFor(weekReview)
final weekReviewProvider = WeekReviewFamily._();

/// What the coach wrote about the week from [start], if it did.

final class WeekReviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<WeekReview?>,
          WeekReview?,
          Stream<WeekReview?>
        >
    with $FutureModifier<WeekReview?>, $StreamProvider<WeekReview?> {
  /// What the coach wrote about the week from [start], if it did.
  WeekReviewProvider._({
    required WeekReviewFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'weekReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$weekReviewHash();

  @override
  String toString() {
    return r'weekReviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WeekReview?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<WeekReview?> create(Ref ref) {
    final argument = this.argument as DateTime;
    return weekReview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WeekReviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$weekReviewHash() => r'1b6988d1c671cc0597322671ba319ace207b1a4f';

/// What the coach wrote about the week from [start], if it did.

final class WeekReviewFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WeekReview?>, DateTime> {
  WeekReviewFamily._()
    : super(
        retry: null,
        name: r'weekReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the coach wrote about the week from [start], if it did.

  WeekReviewProvider call(DateTime start) =>
      WeekReviewProvider._(argument: start, from: this);

  @override
  String toString() => r'weekReviewProvider';
}

/// Having the coach write about a week.

@ProviderFor(WeekReviewController)
final weekReviewControllerProvider = WeekReviewControllerProvider._();

/// Having the coach write about a week.
final class WeekReviewControllerProvider
    extends $NotifierProvider<WeekReviewController, WeekReviewState> {
  /// Having the coach write about a week.
  WeekReviewControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekReviewControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekReviewControllerHash();

  @$internal
  @override
  WeekReviewController create() => WeekReviewController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeekReviewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeekReviewState>(value),
    );
  }
}

String _$weekReviewControllerHash() =>
    r'8e1b8176c9d9ce2a4e7d8446c5401f928a7c46fe';

/// Having the coach write about a week.

abstract class _$WeekReviewController extends $Notifier<WeekReviewState> {
  WeekReviewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WeekReviewState, WeekReviewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WeekReviewState, WeekReviewState>,
              WeekReviewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The Sunday alarm. Overridden in tests with one that only remembers.

@ProviderFor(weekSchedule)
final weekScheduleProvider = WeekScheduleProvider._();

/// The Sunday alarm. Overridden in tests with one that only remembers.

final class WeekScheduleProvider
    extends $FunctionalProvider<WeekSchedule, WeekSchedule, WeekSchedule>
    with $Provider<WeekSchedule> {
  /// The Sunday alarm. Overridden in tests with one that only remembers.
  WeekScheduleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekScheduleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekScheduleHash();

  @$internal
  @override
  $ProviderElement<WeekSchedule> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WeekSchedule create(Ref ref) {
    return weekSchedule(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeekSchedule value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeekSchedule>(value),
    );
  }
}

String _$weekScheduleHash() => r'2cc2e24a6fecb4a117186b1241b39aa91a6bd5f7';

/// Where the review is shown outside the app. Overridden in tests.

@ProviderFor(weekNotices)
final weekNoticesProvider = WeekNoticesProvider._();

/// Where the review is shown outside the app. Overridden in tests.

final class WeekNoticesProvider
    extends $FunctionalProvider<WeekNotices, WeekNotices, WeekNotices>
    with $Provider<WeekNotices> {
  /// Where the review is shown outside the app. Overridden in tests.
  WeekNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekNoticesHash();

  @$internal
  @override
  $ProviderElement<WeekNotices> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WeekNotices create(Ref ref) {
    return weekNotices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeekNotices value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeekNotices>(value),
    );
  }
}

String _$weekNoticesHash() => r'dc3cdb416dbf8436140a6c63156950fd692bb01d';

/// The Sunday evening notification: the switch, the alarm, and making the
/// review when the alarm finds the app open or locked.

@ProviderFor(weekNotify)
final weekNotifyProvider = WeekNotifyProvider._();

/// The Sunday evening notification: the switch, the alarm, and making the
/// review when the alarm finds the app open or locked.

final class WeekNotifyProvider
    extends $FunctionalProvider<WeekNotify, WeekNotify, WeekNotify>
    with $Provider<WeekNotify> {
  /// The Sunday evening notification: the switch, the alarm, and making the
  /// review when the alarm finds the app open or locked.
  WeekNotifyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weekNotifyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weekNotifyHash();

  @$internal
  @override
  $ProviderElement<WeekNotify> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WeekNotify create(Ref ref) {
    return weekNotify(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeekNotify value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeekNotify>(value),
    );
  }
}

String _$weekNotifyHash() => r'dc74e9acc411525fb20c88fee98f57441c0dc034';
