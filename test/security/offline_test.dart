import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The promise the whole app rests on, and the one door in it.
///
/// Until the AI coach, FitLog could not reach the network at all: the release
/// build stripped the INTERNET permission, so the claim was structural. The
/// coach needs the permission, and an Android permission is decided when the
/// app is built, not when a user decides they want a coach - so it is there
/// for everyone, including everyone who never enters an API key.
///
/// What replaces the old guarantee is this: exactly one file in `lib/` can
/// open a connection, it talks to exactly one host, and these tests fail the
/// moment a second one appears. That is what keeps "de app praat met niemand"
/// true for everything that is not the coach.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const main = 'android/app/src/main/AndroidManifest.xml';
  const client = 'lib/features/chat/data/anthropic_client.dart';

  /// Every .dart file under lib/, path and source.
  Iterable<(String, String)> sources() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      yield (entity.path.replaceAll(r'\', '/'), entity.readAsStringSync());
    }
  }

  test('the app declares internet once, and says why', () {
    final manifest = read(main);
    expect(
      RegExp('android.permission.INTERNET').allMatches(manifest).length,
      1,
    );
    expect(manifest, contains('AI coach'));
  });

  test('the release build no longer strips it', () {
    // It used to, which is why the file is still there: it is where a
    // permission a dependency drags in would be removed again.
    const release = 'android/app/src/release/AndroidManifest.xml';
    expect(read(release), isNot(contains('tools:node="remove"')));
  });

  test('exactly one file in the app can speak a network protocol', () {
    final banned = RegExp(
      r"""import\s+'(package:(http|dio|web_socket_channel|grpc)/|dart:html)""",
    );

    final offenders = <String>[];
    for (final (path, source) in sources()) {
      final speaks =
          banned.hasMatch(source) ||
          source.contains('HttpClient(') ||
          source.contains('Socket.connect');
      if (speaks && path != client) offenders.add(path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'only $client may reach the network. Anything else that needs data '
          'from outside the device is a feature this app does not have.',
    );
  });

  test('and it can only reach Anthropic', () {
    final source = read(client);

    expect(source, contains("'https://api.anthropic.com/v1/messages'"));
    // One address, written down once, not assembled from parts at runtime.
    final urls = RegExp(r"'https?://[^']+'").allMatches(source);
    expect(urls.map((m) => m.group(0)), [
      "'https://api.anthropic.com/v1/messages'",
    ]);
  });

  test('nothing else in the app names that host either', () {
    for (final (path, source) in sources()) {
      if (path == client) continue;
      expect(source, isNot(contains('api.anthropic.com')), reason: path);
    }
  });

  test('the key is never written to a log', () {
    // print and debugPrint are the two ways something ends up in logcat, and
    // the file that holds the key is the file that must not use either.
    final source = read(client);
    expect(source, isNot(contains('debugPrint')));
    expect(source, isNot(RegExp(r'(^|\s)print\(')));
  });

  test(
    'the build-time tools are the only other thing that fetches anything',
    () {
      // They run on a computer, never in the app, and the README says so.
      final seed = File('tool/build_exercise_seed.dart').readAsStringSync();
      expect(seed, contains('HttpClient'));
    },
  );
}
