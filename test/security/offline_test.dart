import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one promise the whole app rests on: it cannot reach the network.
///
/// Adding the QR scanner brought Google's barcode library in with it, and a
/// dependency that declares INTERNET in its own manifest would have had it
/// merged into ours without anyone noticing. These check the guards that stop
/// that, so the next dependency cannot undo it quietly either.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const main = 'android/app/src/main/AndroidManifest.xml';
  const release = 'android/app/src/release/AndroidManifest.xml';

  test('the app asks for no internet permission of its own', () {
    expect(read(main).contains('android.permission.INTERNET'), isFalse);
  });

  test('and the release build strips one a dependency asks for', () {
    final manifest = read(release);
    expect(manifest, contains('android.permission.INTERNET'));
    expect(
      manifest,
      contains('tools:node="remove"'),
      reason: 'the permission must be named only to be removed',
    );
  });

  test('debug and profile keep it, because the tooling needs it', () {
    for (final flavour in ['debug', 'profile']) {
      expect(
        read('android/app/src/$flavour/AndroidManifest.xml'),
        contains('android.permission.INTERNET'),
      );
    }
  });

  test('nothing in the app speaks a network protocol', () {
    final offenders = <String>[];
    final banned = RegExp(
      r"""import\s+'(package:(http|dio|web_socket_channel|grpc)/|dart:html)""",
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (banned.hasMatch(source) ||
          source.contains('HttpClient(') ||
          source.contains('Socket.connect')) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty);
  });

  test('the build-time tools are the only thing that fetches anything', () {
    // They run on a computer, never in the app, and the README says so.
    final seed = File('tool/build_exercise_seed.dart').readAsStringSync();
    expect(seed, contains('HttpClient'));
  });
}
