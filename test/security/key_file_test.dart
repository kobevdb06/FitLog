import 'dart:io';

import 'package:fitlog/core/security/key_file.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/security/key_material.dart';
import 'package:fitlog/core/security/recovery_phrase.dart';
import 'package:fitlog/core/security/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _timeout = Timeout(Duration(minutes: 10));

/// The key under the twelve words, kept a second time in a file of its own.
///
/// The key store wiped every value it held on a single error, and with them
/// every copy of the database key: the phrase then had nothing left to open,
/// while the database itself was still on the phone (DECISIONS 241).
void main() {
  late InMemorySecretStore store;
  late InMemoryKeyFile file;
  late KeyManager manager;
  late String phrase;

  setUp(() {
    store = InMemorySecretStore();
    file = InMemoryKeyFile();
    manager = KeyManager(store, recoveryFile: file);
    phrase = generateRecoveryPhrase();
  });

  test('the phrase is kept on disk too, without the key in the open', () async {
    final dek = manager.createDek();
    await manager.setRecoveryPhrase(dek: dek, phrase: phrase);

    expect(file.value, isNotNull);
    expect(file.value, isNot(contains(toHex(dek))));
    expect(await manager.hasRecoveryFile(), isTrue);
  }, timeout: _timeout);

  test(
    'a key store that lost everything: the phrase still opens the key',
    () async {
      final dek = manager.createDek();
      await manager.setRecoveryPhrase(dek: dek, phrase: phrase);
      await manager.setDirectKey(dek);

      await store.deleteAll();

      expect((await manager.status()).initialised, isFalse);
      expect(await manager.unlockWithRecoveryPhrase(phrase), equals(dek));
    },
    timeout: _timeout,
  );

  test(
    'a key store that cannot be read: the phrase still opens the key',
    () async {
      final dek = manager.createDek();
      await manager.setRecoveryPhrase(dek: dek, phrase: phrase);
      final broken = _BrokenStore()..values.addAll(store.values);

      final unlocked = await KeyManager(
        broken,
        recoveryFile: file,
      ).unlockWithRecoveryPhrase(phrase);

      expect(unlocked, equals(dek));
    },
    timeout: _timeout,
  );

  test('a device set up before the copy on disk gets one at its next '
      'start', () async {
    final dek = manager.createDek();
    await KeyManager(store).setRecoveryPhrase(dek: dek, phrase: phrase);
    expect(file.value, isNull);

    await manager.keepRecoveryFile();

    expect(file.value, store.values['fitlog.dek.recovery']);
  }, timeout: _timeout);

  test(
    'the keys are written anew, without the PIN that went with the rest',
    () async {
      final dek = manager.createDek();
      await manager.setRecoveryPhrase(dek: dek, phrase: phrase);
      await store.deleteAll();

      await manager.restoreKeys(dek: dek, phrase: phrase);

      final status = await manager.status();
      expect(status.initialised, isTrue);
      expect(status.mode, LockMode.none);
      expect(status.hasRecoveryPhrase, isTrue);
      expect(await manager.readDirectKey(), equals(dek));
    },
    timeout: _timeout,
  );

  test(
    'a key store that refuses to be written is cleared, and only then',
    () async {
      final dek = manager.createDek();
      await manager.setRecoveryPhrase(dek: dek, phrase: phrase);
      final stuck = _StuckUntilCleared()..values.addAll(store.values);

      await KeyManager(
        stuck,
        recoveryFile: file,
      ).restoreKeys(dek: dek, phrase: phrase);

      expect(stuck.cleared, isTrue);
      expect(stuck.values['fitlog.dek.direct'], toHex(dek));
    },
    timeout: _timeout,
  );

  test('a value left behind that cannot be read is cleared as well', () async {
    final dek = manager.createDek();
    await manager.setRecoveryPhrase(dek: dek, phrase: phrase);
    final poisoned = _PoisonedUntilCleared()..values.addAll(store.values);

    await KeyManager(
      poisoned,
      recoveryFile: file,
    ).restoreKeys(dek: dek, phrase: phrase);

    expect(poisoned.cleared, isTrue);
    expect((await KeyManager(poisoned).status()).initialised, isTrue);
  }, timeout: _timeout);

  test('wiping takes the copy on disk as well', () async {
    final dek = manager.createDek();
    await manager.setRecoveryPhrase(dek: dek, phrase: phrase);

    await manager.wipe();

    expect(file.value, isNull);
    expect(await manager.hasRecoveryFile(), isFalse);
  }, timeout: _timeout);

  test('on disk it is written whole, and read back', () async {
    final dir = await Directory.systemTemp.createTemp('fitlog_keyfile');
    addTearDown(() => dir.delete(recursive: true));
    final disk = DiskKeyFile(() async => File('${dir.path}/fitlog.recovery'));

    expect(await disk.read(), isNull);
    await disk.write('een');
    await disk.write('twee');
    expect(await disk.read(), 'twee');
    expect(File('${dir.path}/fitlog.recovery.tmp').existsSync(), isFalse);
    await disk.delete();
    expect(await disk.read(), isNull);
  });
}

/// A key store that answers every read with an error, as one whose
/// Keystore key went missing.
class _BrokenStore extends InMemorySecretStore {
  @override
  Future<String?> read(String key) async =>
      throw StateError('Keystore kan niet ontsleutelen');
}

/// A key store that refuses every write until it is cleared.
class _StuckUntilCleared extends InMemorySecretStore {
  bool cleared = false;

  @override
  Future<void> write(String key, String value) async {
    if (!cleared) throw StateError('Keystore weigert');
    await super.write(key, value);
  }

  @override
  Future<void> deleteAll() async {
    cleared = true;
    await super.deleteAll();
  }
}

/// A key store with one value that cannot be read, however often it is
/// written, until the whole store is cleared.
class _PoisonedUntilCleared extends InMemorySecretStore {
  bool cleared = false;

  @override
  Future<String?> read(String key) async {
    if (!cleared && key == 'fitlog.dek.recovery') {
      throw StateError('Keystore kan niet ontsleutelen');
    }
    return super.read(key);
  }

  @override
  Future<void> deleteAll() async {
    cleared = true;
    await super.deleteAll();
  }
}
