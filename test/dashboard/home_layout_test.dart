import 'dart:convert';

import 'package:fitlog/features/dashboard/domain/home_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The list of blocks the Start tab is built from.
void main() {
  group('the default', () {
    test('opens with Vandaag', () {
      expect(defaultHomeLayout.visible.first, HomeBlock.today);
    });

    test('holds every block, favourites switched off', () {
      expect(defaultHomeLayout.blocks, HomeBlock.values);
      expect(defaultHomeLayout.shows(HomeBlock.favourites), isFalse);
      expect(defaultHomeLayout.visible, isNot(contains(HomeBlock.favourites)));
    });

    test('is what an app that was never told otherwise gets', () {
      expect(parseHomeLayout(null).visible, defaultHomeLayout.visible);
      expect(parseHomeLayout('').visible, defaultHomeLayout.visible);
    });
  });

  group('switching a block', () {
    test('off takes it out of the screen but not out of the list', () {
      final off = defaultHomeLayout.withVisible(
        HomeBlock.records,
        visible: false,
      );

      expect(off.visible, isNot(contains(HomeBlock.records)));
      expect(off.blocks, contains(HomeBlock.records));
    });

    test('back on puts it where it was, not at the bottom', () {
      final before = defaultHomeLayout.visible;
      final again = defaultHomeLayout
          .withVisible(HomeBlock.records, visible: false)
          .withVisible(HomeBlock.records, visible: true);

      expect(again.visible, before);
    });

    test('on and off survives being written down and read back', () {
      final layout = defaultHomeLayout
          .withVisible(HomeBlock.favourites, visible: true)
          .withVisible(HomeBlock.volume, visible: false);

      final read = parseHomeLayout(encodeHomeLayout(layout));

      expect(read.visible, layout.visible);
      expect(read.shows(HomeBlock.favourites), isTrue);
      expect(read.shows(HomeBlock.volume), isFalse);
    });
  });

  group('dragging one', () {
    test('down moves it past the ones it passed', () {
      final moved = defaultHomeLayout.reordered(0, 2);

      expect(moved.blocks[2], HomeBlock.today);
      expect(moved.blocks.first, HomeBlock.favourites);
      expect(moved.blocks.toSet(), HomeBlock.values.toSet());
    });

    test('up does the same the other way', () {
      final moved = defaultHomeLayout.reordered(3, 0);

      expect(moved.blocks.first, HomeBlock.recovery);
      expect(moved.blocks.toSet(), HomeBlock.values.toSet());
    });

    test('an order out of range changes nothing', () {
      expect(defaultHomeLayout.reordered(99, 0).blocks, HomeBlock.values);
    });

    test('and the order survives a round trip', () {
      final moved = defaultHomeLayout.reordered(0, 3);

      expect(parseHomeLayout(encodeHomeLayout(moved)).blocks, moved.blocks);
    });
  });

  group('a stored value that cannot be trusted', () {
    test('nonsense falls back rather than throwing', () {
      expect(parseHomeLayout('dit is geen json').visible.isNotEmpty, isTrue);
      expect(parseHomeLayout('[1,2,3]').visible, defaultHomeLayout.visible);
      expect(parseHomeLayout('7').visible, defaultHomeLayout.visible);
    });

    test('a name this version does not know is dropped', () {
      final read = parseHomeLayout(
        jsonEncode({
          'order': ['vandaag', 'raketten', 'herstel'],
          'hidden': <String>[],
        }),
      );

      expect(read.blocks.length, HomeBlock.values.length);
      expect(read.blocks.first, HomeBlock.today);
      expect(read.blocks[1], HomeBlock.recovery);
    });

    test('the same block twice is still one block', () {
      final read = parseHomeLayout(
        jsonEncode({
          'order': ['vandaag', 'vandaag'],
          'hidden': <String>[],
        }),
      );

      expect(read.blocks.length, HomeBlock.values.length);
    });

    test('entries that are not text are ignored', () {
      final read = parseHomeLayout(
        jsonEncode({
          'order': [7, 'vandaag', null],
          'hidden': 'herstel',
        }),
      );

      expect(read.blocks.first, HomeBlock.today);
      expect(read.shows(HomeBlock.recovery), isTrue);
    });
  });

  group('a block this version added', () {
    test('appears even in a layout written before it existed', () {
      // Which is why hiding is a name on a list rather than an absence from
      // one: a new block must not be invisible for everyone who ever arranged
      // their screen.
      final old = jsonEncode({
        'order': ['vandaag', 'deze-week'],
        'hidden': <String>[],
      });

      final read = parseHomeLayout(old);

      expect(read.blocks.take(2), [HomeBlock.today, HomeBlock.week]);
      expect(read.visible, contains(HomeBlock.records));
      expect(read.visible, contains(HomeBlock.volume));
    });

    test('unless it is one that starts out off', () {
      final old = jsonEncode({
        'order': ['vandaag'],
        'hidden': <String>[],
      });

      expect(parseHomeLayout(old).shows(HomeBlock.favourites), isFalse);
    });
  });
}
