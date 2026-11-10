import 'dart:typed_data';

import 'key_file.dart';
import 'key_material.dart';
import 'lockout.dart';
import 'secret_store.dart';

/// How the database is protected on this device.
enum LockMode {
  /// No PIN. The key sits in the Keystore/Keychain and the app opens straight
  /// into the dashboard.
  none,

  /// A PIN is required at every cold start and after the auto-lock timer.
  pin,
}

/// What the key manager found on disk.
class SecurityStatus {
  const SecurityStatus({
    required this.initialised,
    required this.mode,
    required this.biometricEnabled,
    required this.hasRecoveryPhrase,
    required this.consecutiveFailures,
    required this.lastFailureAt,
  });

  /// False on a device that has never run onboarding.
  final bool initialised;

  final LockMode mode;
  final bool biometricEnabled;
  final bool hasRecoveryPhrase;
  final int consecutiveFailures;
  final DateTime? lastFailureAt;

  /// How long the lock screen still has to refuse input.
  Duration remainingLockoutAt([DateTime? now]) => remainingLockout(
    consecutiveFailures: consecutiveFailures,
    lastFailureAt: lastFailureAt,
    now: now,
  );
}

/// Creates, wraps and recovers the database key.
///
/// Every method here works on the wrapped copies in [SecretStore]; the plain
/// DEK only ever exists in memory, and only while the app is unlocked.
class KeyManager {
  KeyManager(this._store, {this._recoveryFile});

  final SecretStore _store;

  /// A second copy of the key wrapped under the twelve words, in a file of
  /// its own: what the phrase still opens when the key store lost or cannot
  /// read every value in it (DECISIONS 241). Null where nothing needs it -
  /// the alarms only ever read the direct key.
  final KeyFile? _recoveryFile;

  static const _kPinWrap = 'fitlog.dek.pin';
  static const _kRecoveryWrap = 'fitlog.dek.recovery';

  /// The phrase itself, encrypted under the DEK.
  static const _kRecoveryCopy = 'fitlog.recovery.copy';

  /// The DEK in hex, stored directly. Present when there is no PIN, or when
  /// biometric unlock is switched on.
  static const _kDirectKey = 'fitlog.dek.direct';
  static const _kBiometric = 'fitlog.biometric';
  static const _kFailures = 'fitlog.pin.failures';
  static const _kLastFailure = 'fitlog.pin.last_failure';

  Future<SecurityStatus> status() async {
    final pinWrap = await _store.read(_kPinWrap);
    final direct = await _store.read(_kDirectKey);
    final recovery = await _store.read(_kRecoveryWrap);
    final biometric = await _store.read(_kBiometric);
    final failures = int.tryParse(await _store.read(_kFailures) ?? '') ?? 0;
    final lastFailureMs = int.tryParse(await _store.read(_kLastFailure) ?? '');

    return SecurityStatus(
      initialised: pinWrap != null || direct != null,
      mode: pinWrap != null ? LockMode.pin : LockMode.none,
      biometricEnabled: biometric == '1' && direct != null,
      hasRecoveryPhrase: recovery != null,
      consecutiveFailures: failures,
      lastFailureAt: lastFailureMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastFailureMs),
    );
  }

  /// A brand new data encryption key. Nothing is persisted yet: the caller
  /// decides how it gets protected.
  Uint8List createDek() => generateDek();

  // --- Setting protections --------------------------------------------------

  /// Stores the DEK wrapped under [pin] and removes the unprotected copy
  /// unless biometrics keep it alive.
  Future<void> setPin({
    required Uint8List dek,
    required String pin,
    bool keepDirectKey = false,
  }) async {
    final wrapped = await wrapDek(dek: dek, secret: pin);
    await _store.write(_kPinWrap, wrapped.encode());
    if (!keepDirectKey) {
      await _store.delete(_kDirectKey);
      await _store.delete(_kBiometric);
    }
    await _clearFailures();
  }

  /// Stores the DEK wrapped under the recovery phrase.
  ///
  /// A copy of the phrase itself is kept encrypted under the DEK so Settings
  /// can show the twelve words again, and so the backup flow can use them as
  /// the archive key without asking the user to type them.
  Future<void> setRecoveryPhrase({
    required Uint8List dek,
    required String phrase,
  }) async {
    final wrapped = (await wrapDek(dek: dek, secret: phrase)).encode();
    await _store.write(_kRecoveryWrap, wrapped);
    await _store.write(
      _kRecoveryCopy,
      await encryptUnderDek(dek: dek, plaintext: phrase),
    );
    await _writeRecoveryFile(wrapped);
  }

  /// The copy on disk of what the phrase opens. A failure here does not
  /// stop anything: the key store holds the same, and [keepRecoveryFile]
  /// tries again at the next start.
  Future<void> _writeRecoveryFile(String wrapped) async {
    try {
      await _recoveryFile?.write(wrapped);
    } on Object {
      // Written again at the next start.
    }
  }

  /// Makes the copy on disk the same as the one in the key store: for a
  /// device set up before there was a copy on disk, and after a write of it
  /// failed. Called at every start, once the key store answered.
  Future<void> keepRecoveryFile() async {
    final file = _recoveryFile;
    if (file == null) return;
    final wrapped = await _store.read(_kRecoveryWrap);
    if (wrapped == null) return;
    try {
      if (await file.read() != wrapped) await file.write(wrapped);
    } on Object {
      // Tried again at the next start.
    }
  }

  /// Whether the twelve words still have something to open on this device
  /// without the key store.
  Future<bool> hasRecoveryFile() async {
    try {
      return await _recoveryFile?.read() != null;
    } on Object {
      return false;
    }
  }

  /// The twelve words, readable only while the app is unlocked.
  Future<String?> readRecoveryPhrase(Uint8List dek) async {
    final blob = await _store.read(_kRecoveryCopy);
    if (blob == null) return null;
    return decryptUnderDek(dek: dek, blob: blob);
  }

  /// Keeps the DEK in the platform key store without a PIN in front of it.
  Future<void> setDirectKey(Uint8List dek) async {
    await _store.write(_kDirectKey, toHex(dek));
  }

  /// Turns biometric unlock on. The DEK is kept directly so that a successful
  /// `local_auth` check is enough to open the database.
  Future<void> enableBiometrics(Uint8List dek) async {
    await _store.write(_kDirectKey, toHex(dek));
    await _store.write(_kBiometric, '1');
  }

  Future<void> disableBiometrics() async {
    final status = await this.status();
    await _store.write(_kBiometric, '0');
    // Without a PIN the direct key is the only way in, so it has to stay.
    if (status.mode == LockMode.pin) {
      await _store.delete(_kDirectKey);
    }
  }

  /// Removes the PIN. The DEK moves back to being stored directly, which is
  /// only allowed if the caller can supply it - i.e. the app is unlocked.
  Future<void> removePin(Uint8List dek) async {
    await _store.write(_kDirectKey, toHex(dek));
    await _store.delete(_kPinWrap);
    await _clearFailures();
  }

  /// Rewraps the DEK under a new PIN. The database is untouched.
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final dek = await unlockWithPin(currentPin);
    final status = await this.status();
    await setPin(dek: dek, pin: newPin, keepDirectKey: status.biometricEnabled);
  }

  // --- Unlocking ------------------------------------------------------------

  /// Opens the database key with the PIN.
  ///
  /// Throws [InvalidSecretException] on a wrong PIN and records the failure so
  /// the next attempt is throttled.
  Future<Uint8List> unlockWithPin(String pin) async {
    final raw = await _store.read(_kPinWrap);
    if (raw == null) {
      throw StateError('Er is geen pincode ingesteld op dit toestel');
    }
    try {
      final dek = await unwrapDek(wrapped: WrappedKey.decode(raw), secret: pin);
      await _clearFailures();
      return dek;
    } on InvalidSecretException {
      await _recordFailure();
      rethrow;
    }
  }

  /// Opens the database key with the twelve word phrase: from the key
  /// store, or - when that lost it or cannot be read - from the copy on
  /// disk.
  Future<Uint8List> unlockWithRecoveryPhrase(String phrase) async {
    String? raw;
    try {
      raw = await _store.read(_kRecoveryWrap);
    } on Object {
      raw = null;
    }
    raw ??= await _recoveryFile?.read();
    if (raw == null) {
      throw StateError('Er is geen herstelzin bewaard op dit toestel');
    }
    return unwrapDek(wrapped: WrappedKey.decode(raw), secret: phrase);
  }

  /// After the twelve words opened the database without the key store: its
  /// keys written anew, as on a device without a PIN - the PIN went with the
  /// rest. A store that cannot be written or read back is cleared first:
  /// only now, with the key in hand and its copy on disk, is that safe.
  Future<void> restoreKeys({
    required Uint8List dek,
    required String phrase,
  }) async {
    Future<void> write() async {
      await setRecoveryPhrase(dek: dek, phrase: phrase);
      await setDirectKey(dek);
      await _store.delete(_kPinWrap);
      await _store.delete(_kBiometric);
      await _clearFailures();
      final written = await readDirectKey();
      if (written == null || toHex(written) != toHex(dek)) {
        throw StateError('De sleutel is niet bewaard');
      }
      // The whole store read back, not only what was just written: a value
      // left from before that cannot be read stops every later start.
      await status();
    }

    try {
      await write();
    } on Object {
      await _store.deleteAll();
      await write();
    }
  }

  /// The key as stored directly. Returns null when a PIN is the only way in.
  ///
  /// Callers that reach this because biometrics are enabled must run the
  /// `local_auth` check first; see [BiometricService].
  Future<Uint8List?> readDirectKey() async {
    final hex = await _store.read(_kDirectKey);
    if (hex == null) return null;
    return fromHex(hex);
  }

  // --- Failure throttling ---------------------------------------------------

  Future<void> _recordFailure() async {
    final failures = int.tryParse(await _store.read(_kFailures) ?? '') ?? 0;
    await _store.write(_kFailures, '${failures + 1}');
    await _store.write(
      _kLastFailure,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> _clearFailures() async {
    await _store.delete(_kFailures);
    await _store.delete(_kLastFailure);
  }

  /// Wipes every key. The database file becomes permanently unreadable, so
  /// this is only ever called together with deleting it.
  Future<void> wipe() async {
    await _store.delete(_kPinWrap);
    await _store.delete(_kRecoveryWrap);
    await _store.delete(_kRecoveryCopy);
    await _store.delete(_kDirectKey);
    await _store.delete(_kBiometric);
    await _clearFailures();
    await _recoveryFile?.delete();
  }
}
