// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_notify.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The alarm of the geplande prompts. Overridden in tests with one that only
/// remembers.

@ProviderFor(promptSchedule)
final promptScheduleProvider = PromptScheduleProvider._();

/// The alarm of the geplande prompts. Overridden in tests with one that only
/// remembers.

final class PromptScheduleProvider
    extends $FunctionalProvider<PromptSchedule, PromptSchedule, PromptSchedule>
    with $Provider<PromptSchedule> {
  /// The alarm of the geplande prompts. Overridden in tests with one that only
  /// remembers.
  PromptScheduleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promptScheduleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promptScheduleHash();

  @$internal
  @override
  $ProviderElement<PromptSchedule> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PromptSchedule create(Ref ref) {
    return promptSchedule(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PromptSchedule value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PromptSchedule>(value),
    );
  }
}

String _$promptScheduleHash() => r'352b00b5ed2d9614e4cfc05da477566569cb5e90';

/// Where what the coach said is shown outside the app. Overridden in tests.

@ProviderFor(promptNotices)
final promptNoticesProvider = PromptNoticesProvider._();

/// Where what the coach said is shown outside the app. Overridden in tests.

final class PromptNoticesProvider
    extends $FunctionalProvider<PromptNotices, PromptNotices, PromptNotices>
    with $Provider<PromptNotices> {
  /// Where what the coach said is shown outside the app. Overridden in tests.
  PromptNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promptNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promptNoticesHash();

  @$internal
  @override
  $ProviderElement<PromptNotices> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PromptNotices create(Ref ref) {
    return promptNotices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PromptNotices value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PromptNotices>(value),
    );
  }
}

String _$promptNoticesHash() => r'f6a1fe60ec698947b06b8c2cd455f66f49fd2493';

@ProviderFor(promptNotify)
final promptNotifyProvider = PromptNotifyProvider._();

final class PromptNotifyProvider
    extends $FunctionalProvider<PromptNotify, PromptNotify, PromptNotify>
    with $Provider<PromptNotify> {
  PromptNotifyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'promptNotifyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$promptNotifyHash();

  @$internal
  @override
  $ProviderElement<PromptNotify> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PromptNotify create(Ref ref) {
    return promptNotify(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PromptNotify value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PromptNotify>(value),
    );
  }
}

String _$promptNotifyHash() => r'd29bf3ce4ec1d2e77fbf8ba3a4fecfb73e4f7651';
