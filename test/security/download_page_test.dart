import 'dart:io';

import 'package:fitlog/features/chat/data/links.dart';
import 'package:flutter_test/flutter_test.dart';

/// The download page: what a tester sees before installing anything.
///
/// It names the version it hands out, so a bump that forgets the page shows up
/// here rather than as a tester running something other than what the page
/// promised. And it says it loads nothing from elsewhere, which only holds as
/// long as nobody adds a font, a script or a picture from another site.
void main() {
  final page = File('docs/index.html').readAsStringSync();

  String pubspecVersion() => RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

  test('the button names the version in pubspec.yaml', () {
    expect(page, contains('Download FitLog ${pubspecVersion()}'));
  });

  test('and says what is new in it', () {
    final minor = pubspecVersion().split('.').take(2).join('.');
    expect(page, contains('Nieuw in $minor'));
  });

  test('it offers the 64-bit file, and the 32-bit one for older phones', () {
    expect(page, contains('data-repo="/releases/latest/download/fitlog.apk"'));
    expect(
      page,
      contains('data-repo="/releases/latest/download/fitlog-32bit.apk"'),
    );
  });

  test('it loads nothing from elsewhere', () {
    expect(page, isNot(contains('<script src')));
    expect(page, isNot(contains('<img')));
    expect(page, isNot(contains('<iframe')));
    expect(page, isNot(contains('@import')));
    expect(page, isNot(contains('url(')));
    for (final link in RegExp(r'<link[^>]*>').allMatches(page)) {
      expect(link.group(0), isNot(contains('http')));
    }
  });

  test('the app finds a newer version on this very page', () {
    expect(kSiteUrl, 'https://kobevdb06.github.io/FitLog/');
  });

  test('it names the maker as he writes his name', () {
    expect(page, contains('Kobe Vandenberk'));
  });
}
