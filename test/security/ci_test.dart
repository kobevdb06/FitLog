import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What runs on GitHub (DECISIONS 296 and 297).
void main() {
  test('every push is analyzed and tested, in a zone with summer time', () {
    final ci = File('.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('flutter analyze'));
    expect(ci, contains('flutter test'));
    expect(ci, contains('TZ: Europe/Brussels'));
    expect(ci, contains('push:'));
  });

  test('the iOS build only runs by hand', () {
    final ios = File('.github/workflows/ios.yml').readAsStringSync();
    final on = ios.substring(
      ios.indexOf('\non:'),
      ios.indexOf('\nconcurrency:'),
    );
    expect(on, contains('workflow_dispatch:'));
    expect(on, isNot(contains('push:')));
  });
}
