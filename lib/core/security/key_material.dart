import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Key derivation and key wrapping. Pure Dart, no Flutter import, so the whole
/// scheme can be exercised from unit tests.
///
/// The scheme in one paragraph: a random 32 byte **data encryption key** (DEK)
/// is the SQLCipher passphrase. The DEK itself is never written to disk in the
/// clear. Instead it is encrypted ("wrapped") with a **key encryption key**
/// (KEK) that is derived with Argon2id from something the user knows - a PIN or
/// the twelve word recovery phrase. Changing the PIN rewraps the DEK; the
/// database is never re-encrypted.

/// Length of the data encryption key, in bytes.
const int kDekLengthBytes = 32;

/// Argon2id parameters. Memory is in KiB, so 65536 is 64 MB.
const int kArgonMemoryKib = 65536;
const int kArgonIterations = 3;
const int kArgonParallelism = 2;

const int _saltLength = 16;
const int _nonceLength = 12;

/// Thrown when a wrapped key cannot be opened with the supplied secret.
class InvalidSecretException implements Exception {
  const InvalidSecretException();

  @override
  String toString() => 'InvalidSecretException';
}

/// A DEK encrypted under a KEK, plus everything needed to derive that KEK
/// again. Safe to persist: without the user's secret it is opaque.
class WrappedKey {
  const WrappedKey({
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    this.memoryKib = kArgonMemoryKib,
    this.iterations = kArgonIterations,
    this.parallelism = kArgonParallelism,
  });

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  /// Stored alongside the blob so the parameters can be raised later without
  /// locking anyone out of an older wrap.
  final int memoryKib;
  final int iterations;
  final int parallelism;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'ct': base64Encode(ciphertext),
    'mac': base64Encode(mac),
    'm': memoryKib,
    't': iterations,
    'p': parallelism,
  };

  String encode() => jsonEncode(toJson());

  static WrappedKey decode(String raw) =>
      WrappedKey.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  factory WrappedKey.fromJson(Map<String, dynamic> json) => WrappedKey(
    salt: base64Decode(json['salt'] as String),
    nonce: base64Decode(json['nonce'] as String),
    ciphertext: base64Decode(json['ct'] as String),
    mac: base64Decode(json['mac'] as String),
    memoryKib: (json['m'] as num?)?.toInt() ?? kArgonMemoryKib,
    iterations: (json['t'] as num?)?.toInt() ?? kArgonIterations,
    parallelism: (json['p'] as num?)?.toInt() ?? kArgonParallelism,
  );
}

/// Cryptographically secure random bytes.
Uint8List randomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// A fresh data encryption key.
Uint8List generateDek() => randomBytes(kDekLengthBytes);

/// Lower-case hex, the form SQLCipher wants in `PRAGMA key = "x'...'"`.
String toHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List fromHex(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Runs Argon2id in a separate isolate.
///
/// 64 MB of memory for three passes takes long enough that doing it on the UI
/// isolate would drop frames on the lock screen.
Future<Uint8List> deriveKek({
  required String secret,
  required Uint8List salt,
  int memoryKib = kArgonMemoryKib,
  int iterations = kArgonIterations,
  int parallelism = kArgonParallelism,
}) {
  return Isolate.run(
    () => _deriveKekSync(
      secret: secret,
      salt: salt,
      memoryKib: memoryKib,
      iterations: iterations,
      parallelism: parallelism,
    ),
  );
}

/// The same derivation without the isolate hop. Used by tests and from inside
/// [deriveKek].
Future<Uint8List> _deriveKekSync({
  required String secret,
  required Uint8List salt,
  required int memoryKib,
  required int iterations,
  required int parallelism,
}) async {
  final algorithm = Argon2id(
    memory: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
    hashLength: kDekLengthBytes,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(secret)),
    nonce: salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}

/// Encrypts [dek] under a KEK derived from [secret].
Future<WrappedKey> wrapDek({
  required Uint8List dek,
  required String secret,
  Uint8List? salt,
  Uint8List? nonce,
  int memoryKib = kArgonMemoryKib,
  int iterations = kArgonIterations,
  int parallelism = kArgonParallelism,
}) async {
  final actualSalt = salt ?? randomBytes(_saltLength);
  final actualNonce = nonce ?? randomBytes(_nonceLength);

  final kek = await deriveKek(
    secret: secret,
    salt: actualSalt,
    memoryKib: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
  );

  final box = await AesGcm.with256bits().encrypt(
    dek,
    secretKey: SecretKey(kek),
    nonce: actualNonce,
  );

  return WrappedKey(
    salt: actualSalt,
    nonce: actualNonce,
    ciphertext: Uint8List.fromList(box.cipherText),
    mac: Uint8List.fromList(box.mac.bytes),
    memoryKib: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
  );
}

/// Encrypts [plaintext] directly under the DEK.
///
/// Used for the copy of the recovery phrase that Settings can show again: it
/// is only readable when the database key is already in memory, which means
/// the app is unlocked.
Future<String> encryptUnderDek({
  required Uint8List dek,
  required String plaintext,
}) async {
  final nonce = randomBytes(_nonceLength);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(plaintext),
    secretKey: SecretKey(dek),
    nonce: nonce,
  );
  return jsonEncode({
    'nonce': base64Encode(nonce),
    'ct': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

/// The inverse of [encryptUnderDek]. Returns null when the blob does not
/// belong to this key.
Future<String?> decryptUnderDek({
  required Uint8List dek,
  required String blob,
}) async {
  try {
    final json = jsonDecode(blob) as Map<String, dynamic>;
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        base64Decode(json['ct'] as String),
        nonce: base64Decode(json['nonce'] as String),
        mac: Mac(base64Decode(json['mac'] as String)),
      ),
      secretKey: SecretKey(dek),
    );
    return utf8.decode(clear);
  } on SecretBoxAuthenticationError {
    return null;
  } on FormatException {
    return null;
  }
}

/// Recovers the DEK from [wrapped].
///
/// Throws [InvalidSecretException] when [secret] is wrong; AES-GCM's
/// authentication tag makes that unambiguous.
Future<Uint8List> unwrapDek({
  required WrappedKey wrapped,
  required String secret,
}) async {
  final kek = await deriveKek(
    secret: secret,
    salt: wrapped.salt,
    memoryKib: wrapped.memoryKib,
    iterations: wrapped.iterations,
    parallelism: wrapped.parallelism,
  );

  try {
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        wrapped.ciphertext,
        nonce: wrapped.nonce,
        mac: Mac(wrapped.mac),
      ),
      secretKey: SecretKey(kek),
    );
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw const InvalidSecretException();
  }
}
