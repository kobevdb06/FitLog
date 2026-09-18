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
    r'74c5013af5fa09c6ac9640f9340622d92f966942';

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

/// Which service the coach talks to.
///
/// Only one is offered at the moment, so there is nothing to guess and nothing
/// to choose. A stored choice from when there were two is honoured as long as
/// that service is still on offer, and otherwise ignored rather than used.

@ProviderFor(coachProvider)
final coachProviderProvider = CoachProviderProvider._();

/// Which service the coach talks to.
///
/// Only one is offered at the moment, so there is nothing to guess and nothing
/// to choose. A stored choice from when there were two is honoured as long as
/// that service is still on offer, and otherwise ignored rather than used.

final class CoachProviderProvider
    extends $FunctionalProvider<CoachProvider, CoachProvider, CoachProvider>
    with $Provider<CoachProvider> {
  /// Which service the coach talks to.
  ///
  /// Only one is offered at the moment, so there is nothing to guess and nothing
  /// to choose. A stored choice from when there were two is honoured as long as
  /// that service is still on offer, and otherwise ignored rather than used.
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

String _$coachProviderHash() => r'bd991600820ae03f00efb7c6c252e1f00668c64d';

/// Which model to ask, as the service names it.
///
/// A plain string, not one of the names this app was built with: the picker
/// lists what the key can really use, and that list outlives this version.

@ProviderFor(coachModel)
final coachModelProvider = CoachModelProvider._();

/// Which model to ask, as the service names it.
///
/// A plain string, not one of the names this app was built with: the picker
/// lists what the key can really use, and that list outlives this version.

final class CoachModelProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Which model to ask, as the service names it.
  ///
  /// A plain string, not one of the names this app was built with: the picker
  /// lists what the key can really use, and that list outlives this version.
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
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return coachModel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$coachModelHash() => r'29355558660e52783365b5577e60ec7b7aad20a9';

/// What that model is called on screen.

@ProviderFor(coachModelLabel)
final coachModelLabelProvider = CoachModelLabelProvider._();

/// What that model is called on screen.

final class CoachModelLabelProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// What that model is called on screen.
  CoachModelLabelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachModelLabelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachModelLabelHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return coachModelLabel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$coachModelLabelHash() => r'1ea260486c92a73cb18edd4506b829b0b406c3ea';

/// Every model this key may use, asked of the service itself.
///
/// Kept out of the settings screen's build: it is a network call, and the
/// screen has to work without one.

@ProviderFor(coachModels)
final coachModelsProvider = CoachModelsProvider._();

/// Every model this key may use, asked of the service itself.
///
/// Kept out of the settings screen's build: it is a network call, and the
/// screen has to work without one.

final class CoachModelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CoachModelInfo>>,
          List<CoachModelInfo>,
          FutureOr<List<CoachModelInfo>>
        >
    with
        $FutureModifier<List<CoachModelInfo>>,
        $FutureProvider<List<CoachModelInfo>> {
  /// Every model this key may use, asked of the service itself.
  ///
  /// Kept out of the settings screen's build: it is a network call, and the
  /// screen has to work without one.
  CoachModelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachModelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachModelsHash();

  @$internal
  @override
  $FutureProviderElement<List<CoachModelInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CoachModelInfo>> create(Ref ref) {
    return coachModels(ref);
  }
}

String _$coachModelsHash() => r'37dcac415f13133b4252325446a787700c8f5e93';

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

/// The Hugging Face token, or null when there is none.

@ProviderFor(coachImageKey)
final coachImageKeyProvider = CoachImageKeyProvider._();

/// The Hugging Face token, or null when there is none.

final class CoachImageKeyProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The Hugging Face token, or null when there is none.
  CoachImageKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachImageKeyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachImageKeyHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return coachImageKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$coachImageKeyHash() => r'1581d66c74ca2d17552632e9ab4ee9135801ecb1';

/// Which service draws, of the two on offer.

@ProviderFor(coachDrawingService)
final coachDrawingServiceProvider = CoachDrawingServiceProvider._();

/// Which service draws, of the two on offer.

final class CoachDrawingServiceProvider
    extends $FunctionalProvider<DrawingService, DrawingService, DrawingService>
    with $Provider<DrawingService> {
  /// Which service draws, of the two on offer.
  CoachDrawingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachDrawingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachDrawingServiceHash();

  @$internal
  @override
  $ProviderElement<DrawingService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DrawingService create(Ref ref) {
    return coachDrawingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DrawingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DrawingService>(value),
    );
  }
}

String _$coachDrawingServiceHash() =>
    r'86d1580f0e8ef9e5d35d315f2c3cdb19c5c0de9f';

/// The account a Cloudflare token belongs to.

@ProviderFor(coachImageAccount)
final coachImageAccountProvider = CoachImageAccountProvider._();

/// The account a Cloudflare token belongs to.

final class CoachImageAccountProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The account a Cloudflare token belongs to.
  CoachImageAccountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachImageAccountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachImageAccountHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return coachImageAccount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$coachImageAccountHash() => r'933eafced9c3d52a6924e3de0045550c0241e780';

/// Whether a drawing may try to show the kit as well as the movement.
///
/// Null - every database that predates the switch - is yes, which is what
/// every drawing until now attempted.

@ProviderFor(coachImageEquipment)
final coachImageEquipmentProvider = CoachImageEquipmentProvider._();

/// Whether a drawing may try to show the kit as well as the movement.
///
/// Null - every database that predates the switch - is yes, which is what
/// every drawing until now attempted.

final class CoachImageEquipmentProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether a drawing may try to show the kit as well as the movement.
  ///
  /// Null - every database that predates the switch - is yes, which is what
  /// every drawing until now attempted.
  CoachImageEquipmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coachImageEquipmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coachImageEquipmentHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return coachImageEquipment(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$coachImageEquipmentHash() =>
    r'c9d05f1a16b1beb55cf430c40793b5b01f80dd7d';

/// Whether an illustration can be drawn at all.
///
/// Without a token nothing is ever generated, whatever else is switched on -
/// it is a separate service and separate money. And a service that wants an
/// account as well is not set up until both are there: half of it drawn is
/// nothing drawn.

@ProviderFor(canDrawImages)
final canDrawImagesProvider = CanDrawImagesProvider._();

/// Whether an illustration can be drawn at all.
///
/// Without a token nothing is ever generated, whatever else is switched on -
/// it is a separate service and separate money. And a service that wants an
/// account as well is not set up until both are there: half of it drawn is
/// nothing drawn.

final class CanDrawImagesProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether an illustration can be drawn at all.
  ///
  /// Without a token nothing is ever generated, whatever else is switched on -
  /// it is a separate service and separate money. And a service that wants an
  /// account as well is not set up until both are there: half of it drawn is
  /// nothing drawn.
  CanDrawImagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canDrawImagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canDrawImagesHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return canDrawImages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$canDrawImagesHash() => r'3c5842afd4d1e2fdf09b5e87d1ee95928747b0a1';

@ProviderFor(imageGeneratorFactory)
final imageGeneratorFactoryProvider = ImageGeneratorFactoryProvider._();

final class ImageGeneratorFactoryProvider
    extends
        $FunctionalProvider<
          ImageGeneratorFactory,
          ImageGeneratorFactory,
          ImageGeneratorFactory
        >
    with $Provider<ImageGeneratorFactory> {
  ImageGeneratorFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageGeneratorFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageGeneratorFactoryHash();

  @$internal
  @override
  $ProviderElement<ImageGeneratorFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImageGeneratorFactory create(Ref ref) {
    return imageGeneratorFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageGeneratorFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageGeneratorFactory>(value),
    );
  }
}

String _$imageGeneratorFactoryHash() =>
    r'6a9a7dc82246d730e6553f582b4353e790a711cf';

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

String _$coachControllerHash() => r'749095d4a700c590e8f5f3f0f649bd532a9df972';

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
