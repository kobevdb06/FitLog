import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The signing key is the one secret this project cannot replace.
///
/// Android refuses an APK whose signature changed, so a lost or leaked key
/// means nobody can update the app they installed - and reinstalling costs
/// them every workout on the device, because there is no server holding a
/// copy. These check that the key stays out of the repository and that a
/// release is not quietly signed with the debug key.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final ignore = read('.gitignore');
  final gradle = read('android/app/build.gradle.kts');

  test('a keystore is ignored wherever it lands', () {
    expect(ignore, contains('*.jks'));
    expect(ignore, contains('*.keystore'));
  });

  test('so is the file holding its password', () {
    expect(ignore, contains('android/key.properties'));
  });

  test('but the example that holds none is not', () {
    expect(ignore, contains('!**/android/key.properties.example'));
    expect(File('android/key.properties.example').existsSync(), isTrue);
  });

  test('the example names what a real one needs', () {
    final example = read('android/key.properties.example');
    for (final key in [
      'storeFile',
      'storePassword',
      'keyAlias',
      'keyPassword',
    ]) {
      expect(example, contains(key));
    }
    expect(
      example.contains('keytool'),
      isTrue,
      reason: 'it should say how to make one',
    );
  });

  test('nothing of the sort is actually tracked', () {
    final tracked = Process.runSync('git', ['ls-files']).stdout as String;
    final offenders = tracked
        .split('\n')
        .map((line) => line.trim())
        .where(
          (path) =>
              path.endsWith('.jks') ||
              path.endsWith('.keystore') ||
              path.endsWith('key.properties'),
        );
    expect(offenders, isEmpty);
  });

  test('the release build no longer reaches for the debug key on purpose', () {
    // It still falls back to it so a fresh checkout builds, but only inside
    // the branch that says out loud what it just did.
    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")\n')),
      reason: 'that was the unconditional version',
    );
    expect(gradle, contains('hasReleaseKey'));
    expect(gradle, contains('never to hand out'));
  });

  test('the key is read from a file, not written in the build', () {
    expect(gradle, contains('key.properties'));
    for (final secret in ['storePassword = "', 'keyPassword = "']) {
      expect(
        gradle.contains(secret),
        isFalse,
        reason: 'a password belongs in a file git ignores',
      );
    }
  });
}
