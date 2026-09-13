import 'dart:io';

import 'package:fitlog/features/settings/presentation/about_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The version the app tells you about has to be the version you installed.
///
/// It is written down twice - once for the build, once for the Over-scherm -
/// and a bump that only lands in one of the two is invisible until someone
/// reports a bug against a version that was never released.
void main() {
  test('the About screen names the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'no version: line in pubspec.yaml');
    expect(AboutScreen.appVersion, match!.group(1));
  });
}
