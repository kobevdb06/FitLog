import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/key_material.dart';
import 'package:fitlog/core/security/lockout.dart';
import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _timeout = Timeout(Duration(minutes: 10));

void main() {
  late InMemorySecretStore store;
  late KeyManager manager;

  setUp(() {
    store = InMemorySecretStore();
    manager = KeyManager(store);
  });

  group('status', () {
    test('a fresh device is not initialised', () async {
      final status = await manager.status();
      expect(status.initialised, isFalse);
      expect(status.mode, LockMode.none);
      expect(status.biometricEnabled, isFalse);
      expect(status.hasRecoveryPhrase, isFalse);
    });

    test('skipping the PIN gives an initialised device without a lock',
        () async {
      final dek = manager.createDek();
      await manager.setDirectKey(dek);

      final status = await manager.status();
      expect(status.initialised, isTrue);
      expect(status.mode, LockMode.none);
      expect(await manager.readDirectKey(), equals(dek));
    });
  });

  group('PIN', () {
    test('setting a PIN hides the key and unlocking returns it', () async {
      final dek = manager.createDek();
      await manager.setDirectKey(dek);
      await manager.setPin(dek: dek, pin: '123456');

      final status = await manager.status();
      expect(status.mode, LockMode.pin);
      expect(await manager.readDirectKey(), isNull);
      expect(await manager.unlockWithPin('123456'), equals(dek));
    }, timeout: _timeout);

    test('the raw key is nowhere in storage', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');
      final dump = store.values.values.join('|');
      expect(dump, isNot(contains(toHex(dek))));
    }, timeout: _timeout);

    test('a wrong PIN throws and is counted', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');

      await expectLater(
        manager.unlockWithPin('000000'),
        throwsA(isA<InvalidSecretException>()),
      );
      expect((await manager.status()).consecutiveFailures, 1);

      await expectLater(
        manager.unlockWithPin('000000'),
        throwsA(isA<InvalidSecretException>()),
      );
      expect((await manager.status()).consecutiveFailures, 2);
    }, timeout: _timeout);

    test('a correct PIN clears the failure counter', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');
      await expectLater(
        manager.unlockWithPin('000000'),
        throwsA(isA<InvalidSecretException>()),
      );
      await manager.unlockWithPin('123456');
      expect((await manager.status()).consecutiveFailures, 0);
    }, timeout: _timeout);

    test('changing the PIN keeps the same key', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '111111');
      await manager.changePin(currentPin: '111111', newPin: '222222');

      expect(await manager.unlockWithPin('222222'), equals(dek));
      await expectLater(
        manager.unlockWithPin('111111'),
        throwsA(isA<InvalidSecretException>()),
      );
    }, timeout: _timeout);

    test('removing the PIN puts the key back in direct storage', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');
      await manager.removePin(dek);

      final status = await manager.status();
      expect(status.mode, LockMode.none);
      expect(await manager.readDirectKey(), equals(dek));
    }, timeout: _timeout);

    test('unlocking without a PIN set is a programming error', () async {
      expect(manager.unlockWithPin('123456'), throwsStateError);
    });
  });

  group('recovery phrase', () {
    test('recovers the same key the PIN protects', () async {
      final dek = manager.createDek();
      final phrase = generateRecoveryPhrase();
      await manager.setPin(dek: dek, pin: '123456');
      await manager.setRecoveryPhrase(dek: dek, phrase: phrase);

      expect((await manager.status()).hasRecoveryPhrase, isTrue);
      expect(await manager.unlockWithRecoveryPhrase(phrase), equals(dek));
    }, timeout: _timeout);

    test('still works after the PIN has been changed', () async {
      final dek = manager.createDek();
      final phrase = generateRecoveryPhrase();
      await manager.setPin(dek: dek, pin: '111111');
      await manager.setRecoveryPhrase(dek: dek, phrase: phrase);
      await manager.changePin(currentPin: '111111', newPin: '999999');

      expect(await manager.unlockWithRecoveryPhrase(phrase), equals(dek));
    }, timeout: _timeout);

    test('a different phrase does not open the key', () async {
      final dek = manager.createDek();
      await manager.setRecoveryPhrase(
        dek: dek,
        phrase: generateRecoveryPhrase(),
      );
      expect(
        manager.unlockWithRecoveryPhrase(generateRecoveryPhrase()),
        throwsA(isA<InvalidSecretException>()),
      );
    }, timeout: _timeout);
  });

  group('biometrics', () {
    test('enabling keeps a direct copy next to the PIN wrap', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');
      await manager.enableBiometrics(dek);

      final status = await manager.status();
      expect(status.mode, LockMode.pin);
      expect(status.biometricEnabled, isTrue);
      expect(await manager.readDirectKey(), equals(dek));
    }, timeout: _timeout);

    test('disabling removes the direct copy when a PIN exists', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');
      await manager.enableBiometrics(dek);
      await manager.disableBiometrics();

      expect((await manager.status()).biometricEnabled, isFalse);
      expect(await manager.readDirectKey(), isNull);
    }, timeout: _timeout);

    test('disabling keeps the key when there is no PIN', () async {
      final dek = manager.createDek();
      await manager.setDirectKey(dek);
      await manager.enableBiometrics(dek);
      await manager.disableBiometrics();

      expect(await manager.readDirectKey(), equals(dek));
    });

    test('changing the PIN keeps biometrics working', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '111111');
      await manager.enableBiometrics(dek);
      await manager.changePin(currentPin: '111111', newPin: '222222');

      final status = await manager.status();
      expect(status.biometricEnabled, isTrue);
      expect(await manager.readDirectKey(), equals(dek));
    }, timeout: _timeout);
  });

  group('wipe', () {
    test('leaves nothing behind', () async {
      final dek = manager.createDek();
      await manager.setPin(dek: dek, pin: '123456');
      await manager.setRecoveryPhrase(
        dek: dek,
        phrase: generateRecoveryPhrase(),
      );
      await manager.enableBiometrics(dek);

      await manager.wipe();

      final status = await manager.status();
      expect(status.initialised, isFalse);
      expect(status.hasRecoveryPhrase, isFalse);
      expect(await manager.readDirectKey(), isNull);
    }, timeout: _timeout);
  });

  group('lockout', () {
    test('the first three attempts are free', () {
      expect(lockoutDelay(0), Duration.zero);
      expect(lockoutDelay(1), Duration.zero);
      expect(lockoutDelay(2), Duration.zero);
    });

    test('the delay doubles from the fourth attempt', () {
      expect(lockoutDelay(3), const Duration(seconds: 2));
      expect(lockoutDelay(4), const Duration(seconds: 4));
      expect(lockoutDelay(5), const Duration(seconds: 8));
      expect(lockoutDelay(6), const Duration(seconds: 16));
    });

    test('never goes above thirty seconds', () {
      expect(lockoutDelay(7), kMaxLockout);
      expect(lockoutDelay(50), kMaxLockout);
      expect(lockoutDelay(1000), kMaxLockout);
    });

    test('the remaining wait shrinks with time', () {
      final at = DateTime(2026, 8, 26, 12, 0, 0);
      expect(
        remainingLockout(
          consecutiveFailures: 4,
          lastFailureAt: at,
          now: at.add(const Duration(seconds: 1)),
        ),
        const Duration(seconds: 3),
      );
      expect(
        remainingLockout(
          consecutiveFailures: 4,
          lastFailureAt: at,
          now: at.add(const Duration(seconds: 10)),
        ),
        Duration.zero,
      );
      expect(
        remainingLockout(consecutiveFailures: 4, lastFailureAt: null),
        Duration.zero,
      );
    });
  });
}
