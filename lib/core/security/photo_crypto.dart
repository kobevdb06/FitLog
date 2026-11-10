import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The key photos are sealed with while the app is open: the database key,
/// set when the database opens and cleared when the app locks (DECISIONS
/// 257). Null while locked, and before the app opened.
abstract final class PhotoKey {
  static Uint8List? current;
}

/// A sealed photo that would not open with the key in hand.
class PhotoUnreadableException implements Exception {
  const PhotoUnreadableException(this.reason);

  final String reason;

  @override
  String toString() => 'PhotoUnreadableException: $reason';
}

/// Photos sealed on the phone, as the database is (DECISIONS 257).
///
/// The progress photos and the photos sent to the coach are what FitLog
/// keeps that is most sensitive, and they lay in the photo folder as plain
/// JPEGs while the privacy page said otherwise. Now each file is sealed with
/// AES-GCM under a key of its own, derived from the database key - so a PIN,
/// a new PIN or the twelve words change nothing about it, and a backup,
/// which carries the database key, opens its photos as it opens its data.
///
/// A sealed file starts with "FLPH" and a version byte; a plain one from
/// before is read as it is, until it is sealed in its turn.
abstract final class PhotoCrypto {
  static const List<int> _magic = [0x46, 0x4C, 0x50, 0x48]; // "FLPH"
  static const int _version = 1;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _headerLength = 4 + 1 + _nonceLength;

  /// Whether [bytes] are a sealed photo.
  static bool isSealed(List<int> bytes) =>
      bytes.length >= _headerLength + _macLength &&
      bytes[0] == _magic[0] &&
      bytes[1] == _magic[1] &&
      bytes[2] == _magic[2] &&
      bytes[3] == _magic[3] &&
      bytes[4] == _version;

  /// [plain] sealed under [dek]. On its own isolate: about a tenth of a
  /// second for a photo, too long for the frame it would hold up.
  static Future<Uint8List> seal(Uint8List plain, Uint8List dek) =>
      Isolate.run(() => _seal(plain, dek));

  /// [bytes] opened with [dek] when they are sealed, and as they are when
  /// they are not.
  static Future<Uint8List> open(Uint8List bytes, Uint8List? dek) {
    if (!isSealed(bytes)) return Future.value(bytes);
    if (dek == null) {
      return Future.error(
        const PhotoUnreadableException('de app is vergrendeld'),
      );
    }
    return Isolate.run(() => _open(bytes, dek));
  }

  static Future<SecretKey> _key(Uint8List dek) => Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  ).deriveKey(secretKey: SecretKey(dek), info: utf8.encode('fitlog photos 1'));

  static Future<Uint8List> _seal(Uint8List plain, Uint8List dek) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(
      plain,
      secretKey: await _key(dek),
      nonce: nonce,
    );
    return (BytesBuilder(copy: false)
          ..add(_magic)
          ..addByte(_version)
          ..add(nonce)
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .takeBytes();
  }

  static Future<Uint8List> _open(Uint8List bytes, Uint8List dek) async {
    final nonce = Uint8List.sublistView(bytes, 5, _headerLength);
    final cipherText = Uint8List.sublistView(
      bytes,
      _headerLength,
      bytes.length - _macLength,
    );
    final mac = Uint8List.sublistView(bytes, bytes.length - _macLength);
    try {
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: await _key(dek),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const PhotoUnreadableException('de sleutel past niet');
    }
  }
}
