import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No screen reaches for a Material dropdown.
///
/// Every choice in this app opens the same kind of sheet. A dropdown is a grey
/// slab in a style nothing else here uses, and they came back one at a time -
/// each one looked harmless on its own. This is the sweep that says so once,
/// for every screen at the same time, including the ones whose own tests would
/// mean walking a whole flow to reach them.
void main() {
  test('there is no DropdownButton left in lib/', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Generated code is not ours to style.
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.drift.dart')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('DropdownButton') ||
            lines[i].contains('DropdownMenuItem')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'gebruik een sheet uit dialogs.dart met een PickerField ervoor, '
          'zoals overal elders',
    );
  });
}
