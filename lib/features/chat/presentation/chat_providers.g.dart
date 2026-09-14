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
    r'2b064ec2d66a5f9fabe658c16a1cc8aea374cc4c';

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

@ProviderFor(coachModel)
final coachModelProvider = CoachModelProvider._();

final class CoachModelProvider
    extends $FunctionalProvider<CoachModel, CoachModel, CoachModel>
    with $Provider<CoachModel> {
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

String _$coachModelHash() => r'085b86b7cb753f3e5fc133fa414325a34a808a97';

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

String _$coachControllerHash() => r'5d940c0086c606fccb43750630c8706090c3bc70';

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
