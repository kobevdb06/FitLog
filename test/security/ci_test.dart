import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What runs on GitHub (DECISIONS 296 and 297).
void main() {
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
