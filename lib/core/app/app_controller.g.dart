// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secretStore)
final secretStoreProvider = SecretStoreProvider._();

final class SecretStoreProvider
    extends $FunctionalProvider<SecretStore, SecretStore, SecretStore>
    with $Provider<SecretStore> {
  SecretStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretStoreHash();

  @$internal
  @override
  $ProviderElement<SecretStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecretStore create(Ref ref) {
    return secretStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecretStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecretStore>(value),
    );
  }
}

String _$secretStoreHash() => r'22e5e6738525c9da914aec8831a503a8c095721e';

@ProviderFor(keyManager)
final keyManagerProvider = KeyManagerProvider._();

final class KeyManagerProvider
    extends $FunctionalProvider<KeyManager, KeyManager, KeyManager>
    with $Provider<KeyManager> {
  KeyManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'keyManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$keyManagerHash();

  @$internal
  @override
  $ProviderElement<KeyManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KeyManager create(Ref ref) {
    return keyManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeyManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeyManager>(value),
    );
  }
}

String _$keyManagerHash() => r'b0843abbbd3fd451c324446cd86dfa81ff8db41d';

@ProviderFor(biometricService)
final biometricServiceProvider = BiometricServiceProvider._();

final class BiometricServiceProvider
    extends
        $FunctionalProvider<
          BiometricService,
          BiometricService,
          BiometricService
        >
    with $Provider<BiometricService> {
  BiometricServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricServiceHash();

  @$internal
  @override
  $ProviderElement<BiometricService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BiometricService create(Ref ref) {
    return biometricService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricService>(value),
    );
  }
}

String _$biometricServiceHash() => r'c28c66fc179eade56af90e4df7c5cd6fc01e79b2';

@ProviderFor(appPaths)
final appPathsProvider = AppPathsProvider._();

final class AppPathsProvider
    extends
        $FunctionalProvider<AsyncValue<AppPaths>, AppPaths, FutureOr<AppPaths>>
    with $FutureModifier<AppPaths>, $FutureProvider<AppPaths> {
  AppPathsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPathsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPathsHash();

  @$internal
  @override
  $FutureProviderElement<AppPaths> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppPaths> create(Ref ref) {
    return appPaths(ref);
  }
}

String _$appPathsHash() => r'6dd8a87e28c9861a2371e4f0e36c3b67fed3f064';

/// Owns the database handle and decides what the app is allowed to show.

@ProviderFor(AppController)
final appControllerProvider = AppControllerProvider._();

/// Owns the database handle and decides what the app is allowed to show.
final class AppControllerProvider
    extends $NotifierProvider<AppController, AppState> {
  /// Owns the database handle and decides what the app is allowed to show.
  AppControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appControllerHash();

  @$internal
  @override
  AppController create() => AppController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppState>(value),
    );
  }
}

String _$appControllerHash() => r'eb9fc72f62f743530b20c6ad9fa0d71a0f1f80b0';

/// Owns the database handle and decides what the app is allowed to show.

abstract class _$AppController extends $Notifier<AppState> {
  AppState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppState, AppState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppState, AppState>,
              AppState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The open database. Only valid while [AppController] reports [AppReady],
/// which is exactly when the routed screens are on screen.

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

/// The open database. Only valid while [AppController] reports [AppReady],
/// which is exactly when the routed screens are on screen.

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The open database. Only valid while [AppController] reports [AppReady],
  /// which is exactly when the routed screens are on screen.
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'f8181b13ee2bfbf36110009dc3807a5611093ea0';
