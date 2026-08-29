import 'dart:typed_data';

import 'package:fitlog/core/security/key_material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Argon2id at 64 MB is deliberately slow, so these tests get a generous
/// budget. A few of them use reduced parameters where the cost is not the
/// point.
const _timeout = Timeout(Duration(minutes: 5));

void main() {
  group('random material', () {
    test('a DEK is 32 bytes and not all zeroes', () {
      final dek = generateDek();
      expect(dek, hasLength(kDekLengthBytes));
      expect(dek.any((b) => b != 0), isTrue);
    });

    test('two DEKs differ', () {
      expect(generateDek(), isNot(equals(generateDek())));
    });
  });

  group('hex', () {
    test('round trips', () {
      final bytes = generateDek();
      expect(fromHex(toHex(bytes)), equals(bytes));
    });

    test('is lower case and 64 characters for a DEK', () {
      final hex = toHex(generateDek());
      expect(hex, hasLength(64));
      expect(hex, matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('pads single digit bytes', () {
      expect(toHex(Uint8List.fromList([0, 1, 15, 16, 255])), '00010f10ff');
    });
  });

  group('wrap and unwrap', () {
    test('unwraps with the right PIN', () async {
      final dek = generateDek();
      final wrapped = await wrapDek(dek: dek, secret: '123456');
      expect(await unwrapDek(wrapped: wrapped, secret: '123456'), equals(dek));
    }, timeout: _timeout);

    test('rejects the wrong PIN', () async {
      final dek = generateDek();
      final wrapped = await wrapDek(dek: dek, secret: '123456');
      expect(
        () => unwrapDek(wrapped: wrapped, secret: '654321'),
        throwsA(isA<InvalidSecretException>()),
      );
    }, timeout: _timeout);

    test('the wrapped blob does not contain the key', () async {
      final dek = generateDek();
      final wrapped = await wrapDek(dek: dek, secret: '123456');
      expect(wrapped.ciphertext, isNot(equals(dek)));
      expect(wrapped.encode(), isNot(contains(toHex(dek))));
    }, timeout: _timeout);

    test('survives a JSON round trip', () async {
      final dek = generateDek();
      final wrapped = await wrapDek(dek: dek, secret: 'correct horse');
      final restored = WrappedKey.decode(wrapped.encode());

      expect(restored.salt, equals(wrapped.salt));
      expect(restored.nonce, equals(wrapped.nonce));
      expect(restored.memoryKib, wrapped.memoryKib);
      expect(
        await unwrapDek(wrapped: restored, secret: 'correct horse'),
        equals(dek),
      );
    }, timeout: _timeout);

    test('two wraps of the same key and PIN differ', () async {
      final dek = generateDek();
      final a = await wrapDek(dek: dek, secret: '123456');
      final b = await wrapDek(dek: dek, secret: '123456');
      expect(a.salt, isNot(equals(b.salt)));
      expect(a.ciphertext, isNot(equals(b.ciphertext)));
    }, timeout: _timeout);

    test('a tampered ciphertext is rejected', () async {
      final dek = generateDek();
      final wrapped = await wrapDek(dek: dek, secret: '123456');
      final broken = Uint8List.fromList(wrapped.ciphertext)
        ..[0] = wrapped.ciphertext[0] ^ 0xFF;

      expect(
        () => unwrapDek(
          wrapped: WrappedKey(
            salt: wrapped.salt,
            nonce: wrapped.nonce,
            ciphertext: broken,
            mac: wrapped.mac,
          ),
          secret: '123456',
        ),
        throwsA(isA<InvalidSecretException>()),
      );
    }, timeout: _timeout);
  });

  group('deriveKek', () {
    test('is deterministic for the same secret and salt', () async {
      final salt = randomBytes(16);
      final a = await deriveKek(
        secret: 'pw',
        salt: salt,
        memoryKib: 1024,
        iterations: 1,
      );
      final b = await deriveKek(
        secret: 'pw',
        salt: salt,
        memoryKib: 1024,
        iterations: 1,
      );
      expect(a, equals(b));
      expect(a, hasLength(32));
    }, timeout: _timeout);

    test('a different salt gives a different key', () async {
      final a = await deriveKek(
        secret: 'pw',
        salt: randomBytes(16),
        memoryKib: 1024,
        iterations: 1,
      );
      final b = await deriveKek(
        secret: 'pw',
        salt: randomBytes(16),
        memoryKib: 1024,
        iterations: 1,
      );
      expect(a, isNot(equals(b)));
    }, timeout: _timeout);

    test('the stored parameters are the ones used', () async {
      final wrapped = await wrapDek(
        dek: generateDek(),
        secret: 'pw',
        memoryKib: 1024,
        iterations: 1,
        parallelism: 1,
      );
      expect(wrapped.memoryKib, 1024);
      expect(wrapped.iterations, 1);
      expect(wrapped.parallelism, 1);
      expect(WrappedKey.decode(wrapped.encode()).memoryKib, 1024);
    }, timeout: _timeout);
  });
}
