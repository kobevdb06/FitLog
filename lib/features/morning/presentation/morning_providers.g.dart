// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'morning_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The last week or so of reports, newest first.

@ProviderFor(morningReports)
final morningReportsProvider = MorningReportsProvider._();

/// The last week or so of reports, newest first.

final class MorningReportsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MorningReport>>,
          List<MorningReport>,
          Stream<List<MorningReport>>
        >
    with
        $FutureModifier<List<MorningReport>>,
        $StreamProvider<List<MorningReport>> {
  /// The last week or so of reports, newest first.
  MorningReportsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningReportsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningReportsHash();

  @$internal
  @override
  $StreamProviderElement<List<MorningReport>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MorningReport>> create(Ref ref) {
    return morningReports(ref);
  }
}

String _$morningReportsHash() => r'17f428179e6134c59f890f410064843854f77393';

/// Whether the report is made on its own every morning.

@ProviderFor(morningReportEnabled)
final morningReportEnabledProvider = MorningReportEnabledProvider._();

/// Whether the report is made on its own every morning.

final class MorningReportEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the report is made on its own every morning.
  MorningReportEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningReportEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningReportEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return morningReportEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$morningReportEnabledHash() =>
    r'9367bbd7c3ce9b688ba0cdc5368da69d7a726419';

/// At what time, in minutes after midnight.

@ProviderFor(morningReportMinutes)
final morningReportMinutesProvider = MorningReportMinutesProvider._();

/// At what time, in minutes after midnight.

final class MorningReportMinutesProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// At what time, in minutes after midnight.
  MorningReportMinutesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningReportMinutesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningReportMinutesHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return morningReportMinutes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$morningReportMinutesHash() =>
    r'5c65d98d20e13b7f6abe0c2c201e1ca9b7b5610c';

/// The alarm. Overridden in tests with one that only remembers.

@ProviderFor(morningSchedule)
final morningScheduleProvider = MorningScheduleProvider._();

/// The alarm. Overridden in tests with one that only remembers.

final class MorningScheduleProvider
    extends
        $FunctionalProvider<MorningSchedule, MorningSchedule, MorningSchedule>
    with $Provider<MorningSchedule> {
  /// The alarm. Overridden in tests with one that only remembers.
  MorningScheduleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningScheduleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningScheduleHash();

  @$internal
  @override
  $ProviderElement<MorningSchedule> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MorningSchedule create(Ref ref) {
    return morningSchedule(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MorningSchedule value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MorningSchedule>(value),
    );
  }
}

String _$morningScheduleHash() => r'5e23418a20290eb2b8ae66deb6fa9d34a54f79ce';

/// Where the report is shown outside the app. Overridden in tests.

@ProviderFor(morningNotices)
final morningNoticesProvider = MorningNoticesProvider._();

/// Where the report is shown outside the app. Overridden in tests.

final class MorningNoticesProvider
    extends $FunctionalProvider<MorningNotices, MorningNotices, MorningNotices>
    with $Provider<MorningNotices> {
  /// Where the report is shown outside the app. Overridden in tests.
  MorningNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningNoticesHash();

  @$internal
  @override
  $ProviderElement<MorningNotices> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MorningNotices create(Ref ref) {
    return morningNotices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MorningNotices value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MorningNotices>(value),
    );
  }
}

String _$morningNoticesHash() => r'ac3e3b646f960505a29a8f9473287274c73253c8';

/// Making a report, now or at the hour, and keeping that hour.

@ProviderFor(MorningController)
final morningControllerProvider = MorningControllerProvider._();

/// Making a report, now or at the hour, and keeping that hour.
final class MorningControllerProvider
    extends $NotifierProvider<MorningController, MorningState> {
  /// Making a report, now or at the hour, and keeping that hour.
  MorningControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'morningControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$morningControllerHash();

  @$internal
  @override
  MorningController create() => MorningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MorningState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MorningState>(value),
    );
  }
}

String _$morningControllerHash() => r'c23d6a1069541b08e7265abf7dd2b75ff0c0dc82';

/// Making a report, now or at the hour, and keeping that hour.

abstract class _$MorningController extends $Notifier<MorningState> {
  MorningState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MorningState, MorningState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MorningState, MorningState>,
              MorningState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
