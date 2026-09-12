/// Which blocks the Start tab shows, and in what order.
///
/// The blocks were always separate widgets; what was fixed was the list they
/// were written in. Storing that list means everyone's first screen can be
/// their own, and it is where the answer lives to "I have a schedule *and*
/// favourites, which do I want on top" - you put both blocks in your layout,
/// or you leave one out.
///
/// Pure Dart: the parsing is worth testing on its own, and the dashboard is
/// not the place to find out that a stored value was damaged.
library;

import 'dart:convert';

enum HomeBlock {
  /// What today is for: the schedule, your favourites, or the last fallback.
  today('vandaag', 'Vandaag', 'Je geplande workout, of waar je op terugvalt'),

  /// Your starred routines, as a list of their own.
  ///
  /// Off to begin with. With no schedule the "Vandaag" block already offers
  /// them, and this one steps aside then rather than saying it twice; with a
  /// schedule it is the way to keep them within reach.
  favourites('favorieten', 'Favorieten', 'Je routines met een ster'),

  week('deze-week', 'Deze week', 'Workouts, sets en volume van deze week'),

  recovery('herstel', 'Herstel', 'Welke spieren nog niet hersteld zijn'),

  records('records', 'Laatste records', 'Wat je onlangs verbeterde'),

  volume('volume', 'Volume', 'Je volume van de laatste acht weken');

  const HomeBlock(this.wire, this.label, this.description);

  /// What is written to the database. Fixed for good: a stored layout from an
  /// older version has to keep meaning the same thing.
  final String wire;

  final String label;
  final String description;

  static HomeBlock? fromWire(String wire) {
    for (final block in HomeBlock.values) {
      if (block.wire == wire) return block;
    }
    return null;
  }

  /// Whether a layout that has never heard of this block should show it.
  bool get onByDefault => this != HomeBlock.favourites;
}

/// The order and the on/off state of every block.
class HomeLayout {
  const HomeLayout({required this.blocks, required this.hidden});

  /// Every block, in the order they appear, whether shown or not. Keeping the
  /// hidden ones in place means switching one back on returns it to where it
  /// was rather than to the bottom.
  final List<HomeBlock> blocks;

  final Set<HomeBlock> hidden;

  /// What the dashboard actually builds.
  List<HomeBlock> get visible => [
    for (final block in blocks)
      if (!hidden.contains(block)) block,
  ];

  bool shows(HomeBlock block) => !hidden.contains(block);

  HomeLayout withVisible(HomeBlock block, {required bool visible}) =>
      HomeLayout(
        blocks: blocks,
        hidden: {
          for (final other in hidden)
            if (other != block) other,
          if (!visible) block,
        },
      );

  /// Moves the block at [from] to [to], where [to] is its index in the list
  /// the block has already left - which is what `onReorderItem` hands over.
  HomeLayout reordered(int from, int to) {
    if (from < 0 || from >= blocks.length) return this;
    final moved = [...blocks];
    final block = moved.removeAt(from);
    moved.insert(to.clamp(0, moved.length), block);
    return HomeLayout(blocks: moved, hidden: hidden);
  }
}

/// The layout of an app that has never been told otherwise.
HomeLayout get defaultHomeLayout => HomeLayout(
  blocks: HomeBlock.values.toList(),
  hidden: {
    for (final block in HomeBlock.values)
      if (!block.onByDefault) block,
  },
);

/// Reads a stored layout, and falls back to the default rather than throwing.
///
/// A block the stored value does not mention is one that did not exist when it
/// was written: it goes at the end, on or off according to its own default. A
/// name this version does not know is dropped. Neither case needs a migration,
/// which is the point of storing it this way.
HomeLayout parseHomeLayout(String? stored) {
  if (stored == null || stored.trim().isEmpty) return defaultHomeLayout;

  final Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    return defaultHomeLayout;
  }
  if (decoded is! Map) return defaultHomeLayout;

  final order = <HomeBlock>[];
  for (final entry in _stringList(decoded['order'])) {
    final block = HomeBlock.fromWire(entry);
    if (block != null && !order.contains(block)) order.add(block);
  }

  final hidden = <HomeBlock>{};
  for (final entry in _stringList(decoded['hidden'])) {
    final block = HomeBlock.fromWire(entry);
    if (block != null) hidden.add(block);
  }

  for (final block in HomeBlock.values) {
    if (order.contains(block)) continue;
    order.add(block);
    if (!block.onByDefault) hidden.add(block);
  }

  return HomeLayout(blocks: order, hidden: hidden);
}

String encodeHomeLayout(HomeLayout layout) => jsonEncode({
  'order': [for (final block in layout.blocks) block.wire],
  'hidden': [
    for (final block in layout.blocks)
      if (layout.hidden.contains(block)) block.wire,
  ],
});

List<String> _stringList(Object? value) => [
  if (value is List)
    for (final entry in value)
      if (entry is String) entry,
];
