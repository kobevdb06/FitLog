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

  test('and what a build leaves behind: a heap dump, an APK', () {
    // Gradle writes a heap dump when it runs out of memory, and that can
    // hold the passwords it had read. An APK in the root is a build to
    // hand out, not source: one of 93 MB went in by mistake (DECISIONS
    // 264).
    expect(ignore, contains('*.hprof'));
    expect(ignore, contains('/*.apk'));
  });

  test('and Gradle writes no heap dump to begin with (DECISIONS 306)', () {
    // Ignored, a dump still lands in the project, passwords and all.
    expect(
      read('android/gradle.properties'),
      isNot(contains('HeapDumpOnOutOfMemoryError')),
    );
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
              path.endsWith('key.properties') ||
              path.endsWith('.hprof') ||
              path.endsWith('.apk') ||
              path.endsWith('.aab'),
        );
    expect(offenders, isEmpty);
  });

  test('the release build no longer reaches for the debug key on purpose', () {
    // It still falls back to it so a fresh checkout builds, but only inside
    // the branch that says out loud what it just did.
    //
    // Read with the line endings taken out. This used to look for the debug
    // line followed by a bare newline, which only ever passed because a
    // Windows checkout ends its lines in \r\n: on any other machine the one
    // legitimate fallback line matched it, and the test failed.
    final text = gradle.replaceAll('\r\n', '\n');
    const debug = 'signingConfig = signingConfigs.getByName("debug")';

    expect(
      debug.allMatches(text),
      hasLength(1),
      reason: 'one fallback, and no second, unconditional one',
    );
    final fallback = text.indexOf(debug);
    final branch = text.lastIndexOf('} else {', fallback);
    expect(
      branch,
      greaterThan(text.indexOf('if (hasReleaseKey)')),
      reason: 'the debug key only where there is no release key',
    );
    expect(
      text.substring(branch, fallback).trim(),
      '} else {',
      reason: 'and as the first thing that branch does',
    );
    expect(text, contains('never to hand out'));
  });

  test('without the release key, a release build stops, unless asked', () {
    // It fell back to the debug key without a sound but a line in the log:
    // exactly what a build in a worktree did (DECISIONS 298).
    final text = gradle.replaceAll('\r\n', '\n');
    expect(text, contains('allow-debug-signing'));
    expect(text, contains('requireReleaseKey'));
    expect(text, contains('preReleaseBuild'));
    expect(text, contains('GradleException'));
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
