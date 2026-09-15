// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coachClientFactory)
final coachClientFactoryProvider = CoachClientFactoryProvider._();

final class CoachClientFactoryProvider
    extends
        $FunctionalProvider<
          CoachClientFactory,
          CoachClientFactory,
          CoachClientFactory
        >
    with $Provider<CoachClientFactory> {
  CoachClientFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachClientFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachClientFactoryHash();

  @$internal
  @override
  $ProviderElement<CoachClientFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CoachClientFactory create(Ref ref) {
    return coachClientFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachClientFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachClientFactory>(value),
    );
  }
}

String _$coachClientFactoryHash() =>
    r'e69daeb2b2eab167230a5c4380373cf50606e995';

@ProviderFor(coachApiKey)
final coachApiKeyProvider = CoachApiKeyProvider._();

final class CoachApiKeyProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  CoachApiKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachApiKeyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachApiKeyHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return coachApiKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$coachApiKeyHash() => r'678e97d6f8eb13580f0e9b15172899c326b8dd81';

/// Whether the user has switched the coach on by entering a key.

@ProviderFor(coachEnabled)
final coachEnabledProvider = CoachEnabledProvider._();

/// Whether the user has switched the coach on by entering a key.

final class CoachEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the user has switched the coach on by entering a key.
  CoachEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return coachEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$coachEnabledHash() => r'2f1cf687f29e9e40a02bbbaf0c50fec54559931a';

/// Which service the key belongs to: what the user said, or else what the
/// key looks like.

@ProviderFor(coachProvider)
final coachProviderProvider = CoachProviderProvider._();

/// Which service the key belongs to: what the user said, or else what the
/// key looks like.

final class CoachProviderProvider
    extends $FunctionalProvider<CoachProvider, CoachProvider, CoachProvider>
    with $Provider<CoachProvider> {
  /// Which service the key belongs to: what the user said, or else what the
  /// key looks like.
  CoachProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachProviderHash();

  @$internal
  @override
  $ProviderElement<CoachProvider> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachProvider create(Ref ref) {
    return coachProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachProvider>(value),
    );
  }
}

String _$coachProviderHash() => r'd07c02193dab2ccf552b5d1fbbb18220b0f09d6e';

/// Whether the service was worked out rather than chosen, which is what the
/// settings screen says out loud.

@ProviderFor(coachProviderIsGuessed)
final coachProviderIsGuessedProvider = CoachProviderIsGuessedProvider._();

/// Whether the service was worked out rather than chosen, which is what the
/// settings screen says out loud.

final class CoachProviderIsGuessedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the service was worked out rather than chosen, which is what the
  /// settings screen says out loud.
  CoachProviderIsGuessedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachProviderIsGuessedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachProviderIsGuessedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return coachProviderIsGuessed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$coachProviderIsGuessedHash() =>
    r'f7d5654cb5b2710157ac670992ec46414a0e7dc4';

/// The chosen model, or this service's default - which is also what happens
/// when someone swaps a key for one of the other service.

@ProviderFor(coachModel)
final coachModelProvider = CoachModelProvider._();

/// The chosen model, or this service's default - which is also what happens
/// when someone swaps a key for one of the other service.

final class CoachModelProvider
    extends $FunctionalProvider<CoachModel, CoachModel, CoachModel>
    with $Provider<CoachModel> {
  /// The chosen model, or this service's default - which is also what happens
  /// when someone swaps a key for one of the other service.
  CoachModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachModelHash();

  @$internal
  @override
  $ProviderElement<CoachModel> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoachModel create(Ref ref) {
    return coachModel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachModel>(value),
    );
  }
}

String _$coachModelHash() => r'839ee08ed9f69f051fe489e38eabac1c036e84a9';

@ProviderFor(chatThreads)
final chatThreadsProvider = ChatThreadsProvider._();

final class ChatThreadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatThreadRow>>,
          List<ChatThreadRow>,
          Stream<List<ChatThreadRow>>
        >
    with
        $FutureModifier<List<ChatThreadRow>>,
        $StreamProvider<List<ChatThreadRow>> {
  ChatThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatThreadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatThreadsHash();

  @$internal
  @override
  $StreamProviderElement<List<ChatThreadRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatThreadRow>> create(Ref ref) {
    return chatThreads(ref);
  }
}

String _$chatThreadsHash() => r'28db39add1c56fc10c2ae9097a52d6bcb082e323';

@ProviderFor(chatMessages)
final chatMessagesProvider = ChatMessagesFamily._();

final class ChatMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatMessageRow>>,
          List<ChatMessageRow>,
          Stream<List<ChatMessageRow>>
        >
    with
        $FutureModifier<List<ChatMessageRow>>,
        $StreamProvider<List<ChatMessageRow>> {
  ChatMessagesProvider._({
    required ChatMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatMessagesHash();

  @override
  String toString() {
    return r'chatMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChatMessageRow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChatMessageRow>> create(Ref ref) {
    final argument = this.argument as String;
    return chatMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatMessagesHash() => r'dc32fad1d0579e1aee0e6db5d18e4badfa0ebd35';

final class ChatMessagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChatMessageRow>>, String> {
  ChatMessagesFamily._()
    : super(
        retry: null,
        name: r'chatMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChatMessagesProvider call(String threadId) =>
      ChatMessagesProvider._(argument: threadId, from: this);

  @override
  String toString() => r'chatMessagesProvider';
}

/// What the user allows themselves in a day, in calls to the service.

@ProviderFor(coachDailyLimit)
final coachDailyLimitProvider = CoachDailyLimitProvider._();

/// What the user allows themselves in a day, in calls to the service.

final class CoachDailyLimitProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// What the user allows themselves in a day, in calls to the service.
  CoachDailyLimitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachDailyLimitProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachDailyLimitHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return coachDailyLimit(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$coachDailyLimitHash() => r'a5f0814ebaa83ecd771a2446f34f6dac2475f6ab';

/// What has been spent since this service's day began.
///
/// A count of what this app sent, not a reading of what is left over there:
/// no API tells a client that.

@ProviderFor(coachUsageToday)
final coachUsageTodayProvider = CoachUsageTodayProvider._();

/// What has been spent since this service's day began.
///
/// A count of what this app sent, not a reading of what is left over there:
/// no API tells a client that.

final class CoachUsageTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<CoachDayUsage>,
          CoachDayUsage,
          Stream<CoachDayUsage>
        >
    with $FutureModifier<CoachDayUsage>, $StreamProvider<CoachDayUsage> {
  /// What has been spent since this service's day began.
  ///
  /// A count of what this app sent, not a reading of what is left over there:
  /// no API tells a client that.
  CoachUsageTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachUsageTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachUsageTodayHash();

  @$internal
  @override
  $StreamProviderElement<CoachDayUsage> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CoachDayUsage> create(Ref ref) {
    return coachUsageToday(ref);
  }
}

String _$coachUsageTodayHash() => r'7967412f31ae29c2e37f342300809014191f3131';

/// Asking a question, from the first keystroke to the answer on screen.

@ProviderFor(CoachController)
final coachControllerProvider = CoachControllerProvider._();

/// Asking a question, from the first keystroke to the answer on screen.
final class CoachControllerProvider
    extends $NotifierProvider<CoachController, CoachState> {
  /// Asking a question, from the first keystroke to the answer on screen.
  CoachControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachControllerHash();

  @$internal
  @override
  CoachController create() => CoachController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoachState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoachState>(value),
    );
  }
}

String _$coachControllerHash() => r'1a4af0a17361d02dc6aad66b7f2939570021bb76';

/// Asking a question, from the first keystroke to the answer on screen.

abstract class _$CoachController extends $Notifier<CoachState> {
  CoachState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CoachState, CoachState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoachState, CoachState>,
              CoachState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
