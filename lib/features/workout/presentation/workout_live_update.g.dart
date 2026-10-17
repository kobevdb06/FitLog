// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_live_update.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the taps in the notification come in: the phone's channel, or none.

@ProviderFor(workoutNoticeChannel)
final workoutNoticeChannelProvider = WorkoutNoticeChannelProvider._();

/// Where the taps in the notification come in: the phone's channel, or none.

final class WorkoutNoticeChannelProvider
    extends
        $FunctionalProvider<
          WorkoutNoticeChannel?,
          WorkoutNoticeChannel?,
          WorkoutNoticeChannel?
        >
    with $Provider<WorkoutNoticeChannel?> {
  /// Where the taps in the notification come in: the phone's channel, or none.
  WorkoutNoticeChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutNoticeChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutNoticeChannelHash();

  @$internal
  @override
  $ProviderElement<WorkoutNoticeChannel?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutNoticeChannel? create(Ref ref) {
    return workoutNoticeChannel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutNoticeChannel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutNoticeChannel?>(value),
    );
  }
}

String _$workoutNoticeChannelHash() =>
    r'2bc5c135ad319be2c5872121e431bb2cb451047e';

@ProviderFor(workoutNoticePoster)
final workoutNoticePosterProvider = WorkoutNoticePosterProvider._();

final class WorkoutNoticePosterProvider
    extends
        $FunctionalProvider<
          WorkoutNoticePoster,
          WorkoutNoticePoster,
          WorkoutNoticePoster
        >
    with $Provider<WorkoutNoticePoster> {
  WorkoutNoticePosterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutNoticePosterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutNoticePosterHash();

  @$internal
  @override
  $ProviderElement<WorkoutNoticePoster> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutNoticePoster create(Ref ref) {
    return workoutNoticePoster(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutNoticePoster value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutNoticePoster>(value),
    );
  }
}

String _$workoutNoticePosterHash() =>
    r'd95688f77b04eb748462c8709fb8fda9e6834880';

/// Keeps the standing notification - the island, on a phone that has one -
/// in step with the running workout, also while FitLog is out of sight.
///
/// It used to be redrawn from the root widget's build, and a build only runs
/// with a frame. In the background there are none, so a set ticked off from
/// the notification would not have moved it on until the app was opened
/// again. Listeners run without frames.

@ProviderFor(WorkoutLiveUpdate)
final workoutLiveUpdateProvider = WorkoutLiveUpdateProvider._();

/// Keeps the standing notification - the island, on a phone that has one -
/// in step with the running workout, also while FitLog is out of sight.
///
/// It used to be redrawn from the root widget's build, and a build only runs
/// with a frame. In the background there are none, so a set ticked off from
/// the notification would not have moved it on until the app was opened
/// again. Listeners run without frames.
final class WorkoutLiveUpdateProvider
    extends $NotifierProvider<WorkoutLiveUpdate, WorkoutNotice?> {
  /// Keeps the standing notification - the island, on a phone that has one -
  /// in step with the running workout, also while FitLog is out of sight.
  ///
  /// It used to be redrawn from the root widget's build, and a build only runs
  /// with a frame. In the background there are none, so a set ticked off from
  /// the notification would not have moved it on until the app was opened
  /// again. Listeners run without frames.
  WorkoutLiveUpdateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutLiveUpdateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutLiveUpdateHash();

  @$internal
  @override
  WorkoutLiveUpdate create() => WorkoutLiveUpdate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutNotice? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutNotice?>(value),
    );
  }
}

String _$workoutLiveUpdateHash() => r'27800297eae3498d5ab0193b8fc632ff7aa5f2fa';

/// Keeps the standing notification - the island, on a phone that has one -
/// in step with the running workout, also while FitLog is out of sight.
///
/// It used to be redrawn from the root widget's build, and a build only runs
/// with a frame. In the background there are none, so a set ticked off from
/// the notification would not have moved it on until the app was opened
/// again. Listeners run without frames.

abstract class _$WorkoutLiveUpdate extends $Notifier<WorkoutNotice?> {
  WorkoutNotice? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorkoutNotice?, WorkoutNotice?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorkoutNotice?, WorkoutNotice?>,
              WorkoutNotice?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
