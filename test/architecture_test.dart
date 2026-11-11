import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// How the code hangs together (DECISIONS 300).
void main() {
  test('core never reaches into a feature', () {
    // The app controller fetched the photo store from features/photos: the
    // base of the app depended on one of the rooms built on it.
    final offenders = <String>[];
    for (final file in Directory('lib/core').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(file.readAsStringSync());
      for (final import in imports) {
        final target = import.group(1)!;
        if (target.contains('features/'))
          offenders.add('${file.path}: $target');
      }
    }
    expect(offenders, isEmpty);
  });
}
