import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The small slice of key-value storage the key manager needs.
///
/// Having an interface keeps [KeyManager] testable without a platform channel
/// and makes it obvious that nothing else in the app touches these values.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Backed by the Android Keystore and the iOS Keychain.
class SecureStorageSecretStore implements SecretStore {
  SecureStorageSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Since version 10 the Android implementation always uses Keystore-backed
  /// encrypted preferences, so there is no flag left to switch on.
  static const _android = AndroidOptions(
    storageNamespace: 'be.fitlog.app.keys',
  );

  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<String?> read(String key) =>
      _storage.read(key: key, aOptions: _android, iOptions: _ios);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, aOptions: _android, iOptions: _ios);

  @override
  Future<void> delete(String key) =>
      _storage.delete(key: key, aOptions: _android, iOptions: _ios);

  @override
  Future<void> deleteAll() =>
      _storage.deleteAll(aOptions: _android, iOptions: _ios);
}

/// Used by tests.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}
