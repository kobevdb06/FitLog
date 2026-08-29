import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/connection.dart';
import '../db/database.dart';
import '../db/seeder.dart';
import '../security/biometric_service.dart';
import '../security/key_manager.dart';
import '../security/key_material.dart';
import '../security/secret_store.dart';
import '../util/paths.dart';
import 'app_state.dart';

part 'app_controller.g.dart';

@Riverpod(keepAlive: true)
SecretStore secretStore(Ref ref) => SecureStorageSecretStore();

@Riverpod(keepAlive: true)
KeyManager keyManager(Ref ref) => KeyManager(ref.watch(secretStoreProvider));

@Riverpod(keepAlive: true)
BiometricService biometricService(Ref ref) => BiometricService();

@Riverpod(keepAlive: true)
Future<AppPaths> appPaths(Ref ref) => AppPaths.resolve();

/// Owns the database handle and decides what the app is allowed to show.
@Riverpod(keepAlive: true)
class AppController extends _$AppController {
  AppDatabase? _db;
  Uint8List? _dek;

  /// Cached so the lifecycle handler does not need a database read while the
  /// app is going to the background.
  int _autoLockSeconds = 60;
  DateTime? _pausedAt;

  /// Set by the active workout screen. The app never locks mid-session.
  bool workoutInProgress = false;

  @override
  AppState build() {
    ref.onDispose(() {
      _db?.close();
      _db = null;
    });
    // Kick off without blocking the first frame.
    Future.microtask(initialise);
    return const AppLoading();
  }

  /// Decides between onboarding, the lock screen and opening the database.
  Future<void> initialise() async {
    state = const AppLoading();
    try {
      final cipher = detectCipherVersion();
      if (cipher.isEmpty) {
        state = const AppFailed(
          'Deze build gebruikt gewone SQLite in plaats van SQLCipher, dus je '
          'gegevens zouden onversleuteld worden opgeslagen. FitLog start '
          'daarom niet.',
          canRetry: false,
        );
        return;
      }

      final manager = ref.read(keyManagerProvider);
      final security = await manager.status();

      if (!security.initialised) {
        state = const AppNeedsOnboarding();
        return;
      }

      if (security.mode == LockMode.none) {
        final dek = await manager.readDirectKey();
        if (dek == null) {
          state = const AppNeedsOnboarding();
          return;
        }
        await _openWith(dek, security);
        return;
      }

      state = AppLocked(security);
    } on Object catch (error) {
      state = AppFailed('$error');
    }
  }

  // --- Unlocking ------------------------------------------------------------

  /// Returns null on success, or a message to show under the keypad.
  Future<String?> unlockWithPin(String pin) async {
    final manager = ref.read(keyManagerProvider);
    try {
      final dek = await manager.unlockWithPin(pin);
      await _openWith(dek, await manager.status());
      return null;
    } on InvalidSecretException {
      final status = await manager.status();
      state = AppLocked(status);
      return 'Verkeerde pincode.';
    } on Object catch (error) {
      return '$error';
    }
  }

  Future<String?> unlockWithBiometrics() async {
    final manager = ref.read(keyManagerProvider);
    final biometrics = ref.read(biometricServiceProvider);
    final ok = await biometrics.authenticate();
    if (!ok) return 'Biometrie is afgebroken.';

    final dek = await manager.readDirectKey();
    if (dek == null) return 'Er is geen sleutel voor biometrie opgeslagen.';
    await _openWith(dek, await manager.status());
    return null;
  }

  Future<String?> unlockWithRecoveryPhrase(String phrase) async {
    final manager = ref.read(keyManagerProvider);
    try {
      final dek = await manager.unlockWithRecoveryPhrase(phrase);
      await _openWith(dek, await manager.status());
      return null;
    } on InvalidSecretException {
      return 'Deze herstelzin hoort niet bij dit toestel.';
    } on Object catch (error) {
      return '$error';
    }
  }

  /// Called at the end of onboarding, once the keys have been written.
  Future<void> completeSetupWith(Uint8List dek) async {
    final manager = ref.read(keyManagerProvider);
    await _openWith(dek, await manager.status());
  }

  Future<void> _openWith(Uint8List dek, SecurityStatus security) async {
    try {
      final paths = await ref.read(appPathsProvider.future);
      await paths.ensurePhotosDirectory();

      final db =
          _db ??
          AppDatabase(
            openEncryptedExecutor(
              file: paths.databaseFile,
              keyHex: toHex(dek),
            ),
          );

      final settings = await db.settingsDao.ensureInitialized();
      _autoLockSeconds = settings.autoLockSeconds;
      await ExerciseSeeder(db).seedIfNeeded();

      _db = db;
      _dek = dek;
      state = AppReady(db: db, security: security);
    } on EncryptionUnavailableException catch (e) {
      state = AppFailed(e.message, canRetry: false);
    } on WrongDatabaseKeyException {
      state = const AppFailed(
        'De sleutel past niet op de database op dit toestel. Herstel een '
        'back-up of wis de gegevens om opnieuw te beginnen.',
      );
    } on Object catch (error) {
      state = AppFailed('$error');
    }
  }

  // --- Locking --------------------------------------------------------------

  /// The key currently in memory. Only available while unlocked; the settings
  /// screens need it to rewrap under a new PIN.
  Uint8List? get currentDek => _dek;

  Future<void> lock() async {
    final status = await ref.read(keyManagerProvider).status();
    if (status.mode != LockMode.pin) return;
    _dek = null;
    state = AppLocked(status);
  }

  void setAutoLockSeconds(int seconds) => _autoLockSeconds = seconds;

  /// Auto-lock bookkeeping, driven from the lifecycle observer in `app.dart`.
  void onPaused() => _pausedAt = DateTime.now();

  Future<void> onResumed() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;
    if (workoutInProgress) return;
    if (_autoLockSeconds < 0) return;
    if (state is! AppReady) return;

    final away = DateTime.now().difference(pausedAt);
    if (away.inSeconds >= _autoLockSeconds) {
      await lock();
    }
  }

  // --- Destructive ----------------------------------------------------------

  /// Deletes the database file, every photo and every key.
  Future<void> wipeEverything() async {
    final paths = await ref.read(appPathsProvider.future);
    await _db?.close();
    _db = null;
    _dek = null;

    if (await paths.databaseFile.exists()) {
      await paths.databaseFile.delete();
    }
    for (final suffix in ['-wal', '-shm']) {
      final f = File('${paths.databaseFile.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    if (await paths.photosDirectory.exists()) {
      await paths.photosDirectory.delete(recursive: true);
    }
    await ref.read(keyManagerProvider).wipe();

    state = const AppNeedsOnboarding();
  }

  /// Closes and forgets the current database so a restore can replace the
  /// file underneath it.
  Future<void> closeForRestore() async {
    await _db?.close();
    _db = null;
    _dek = null;
    state = const AppLoading();
  }

  /// The open database, or null while locked. Onboarding needs this to write
  /// the profile straight after the database is created.
  AppDatabase? get databaseOrNull => _db;
}

/// The open database. Only valid while [AppController] reports [AppReady],
/// which is exactly when the routed screens are on screen.
@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final state = ref.watch(appControllerProvider);
  if (state is! AppReady) {
    throw StateError('De database is nog niet geopend');
  }
  return state.db;
}
