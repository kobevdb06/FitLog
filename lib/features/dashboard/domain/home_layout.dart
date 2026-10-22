/// The Start tab as a grid, the way a phone's own home screen is one.
///
/// Four columns, rows of one height, and every block in a place of its own
/// with a size of its own, in cells. Nothing ever moves to fill a gap: a
/// block that leaves a place leaves it empty, and a block only goes where
/// there is room - or trades places with one exactly its size.
///
/// It used to be a list poured into rows: moving one block moved every block
/// after it, and the whole screen shifted under your finger.
///
/// Pure Dart: the rules are worth testing on their own, and the dashboard is
/// not the place to find out that a stored value was damaged.
library;

import 'dart:convert';
import 'dart:math' as math;

/// Columns across the screen.
const int kHomeColumns = 4;

enum HomeBlock {
  /// What today is for: the schedule, your favourites, or the last fallback.
  today('vandaag', 'Vandaag', 'Je geplande workout, of waar je op terugvalt'),

  /// Your starred routines, as a list of their own.
  ///
  /// Off to begin with. With no schedule the "Vandaag" block already offers
  /// them; with a schedule this is the way to keep them within reach.
  favourites('favorieten', 'Favorieten', 'Je routines met een ster'),

  week('deze-week', 'Deze week', 'Workouts, sets en volume van deze week'),

  recovery('herstel', 'Herstel', 'Welke spieren nog niet hersteld zijn'),

  records('records', 'Laatste records', 'Wat je onlangs verbeterde'),

  volume('volume', 'Volume', 'Je volume van de laatste acht weken'),

  /// Today's steps, from the watch.
  steps('stappen', 'Stappen', 'Je stappen van vandaag, van je horloge'),

  /// A way in to the coach.
  coach('coach', 'Coach', 'Een vraag stellen aan je AI-coach');

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

  /// How small and how big it may be, and how big it starts, in cells.
  ///
  /// Never one column: a quarter of a phone has no room for a word and a
  /// number. One row only for the two that say one line.
  HomeBlockSizes get sizes => switch (this) {
    today ||
    favourites ||
    recovery ||
    records => const HomeBlockSizes(minW: 2, minH: 2, maxH: 5, w: 4, h: 3),
    volume => const HomeBlockSizes(minW: 2, minH: 2, maxH: 4, w: 4, h: 3),
    week => const HomeBlockSizes(minW: 2, minH: 2, maxH: 3, w: 4, h: 2),
    steps => const HomeBlockSizes(minW: 2, minH: 1, maxH: 2, w: 4, h: 2),
    coach => const HomeBlockSizes(minW: 2, minH: 1, maxH: 2, w: 4, h: 1),
  };

  /// Whether a layout that has never heard of this block should show it.
  bool get onByDefault => this != HomeBlock.favourites;
}

class HomeBlockSizes {
  const HomeBlockSizes({
    required this.minW,
    required this.minH,
    this.maxW = kHomeColumns,
    required this.maxH,
    required this.w,
    required this.h,
  });

  final int minW;
  final int minH;
  final int maxW;
  final int maxH;

  /// What it starts at.
  final int w;
  final int h;

  int clampW(int w) => w.clamp(minW, maxW);
  int clampH(int h) => h.clamp(minH, maxH);
}

/// How much room a block draws itself in: the two widths a block knows how
/// to fill. Three columns or four is wide; two is small.
enum HomeBlockSize {
  wide,
  small;

  static HomeBlockSize of(HomeSpot spot) =>
      spot.w >= 3 ? HomeBlockSize.wide : HomeBlockSize.small;
}

/// A block's place: its top left cell and how many cells it takes.
class HomeSpot {
  const HomeSpot(this.x, this.y, this.w, this.h);

  final int x;
  final int y;
  final int w;
  final int h;

  int get right => x + w;
  int get bottom => y + h;

  bool overlaps(HomeSpot other) =>
      x < other.right &&
      other.x < right &&
      y < other.bottom &&
      other.y < bottom;

  HomeSpot at(int x, int y) => HomeSpot(x, y, w, h);

  @override
  bool operator ==(Object other) =>
      other is HomeSpot &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'HomeSpot($x, $y, $w × $h)';
}

/// Which edge of a block is being dragged.
enum HomeEdge { left, top, right, bottom }

/// What letting a block go somewhere does.
enum HomeDrop {
  /// It goes there.
  fits,

  /// It trades places with the block of its size that is there.
  swaps,

  /// Something is in the way: it goes back where it came from.
  blocked,
}

/// Every block on the screen and its place. A block without one is off the
/// screen, waiting in the row of chips.
class HomeLayout {
  const HomeLayout(this.spots);

  final Map<HomeBlock, HomeSpot> spots;

  bool shows(HomeBlock block) => spots.containsKey(block);

  HomeSpot? spotOf(HomeBlock block) => spots[block];

  /// What the dashboard builds, top to bottom and left to right - the order
  /// a screen reader reads it in.
  List<HomeBlock> get visible => [...spots.keys]
    ..sort((a, b) {
      final one = spots[a]!;
      final two = spots[b]!;
      return one.y != two.y ? one.y - two.y : one.x - two.x;
    });

  /// The blocks that are off the screen.
  List<HomeBlock> get hidden => [
    for (final block in HomeBlock.values)
      if (!shows(block)) block,
  ];

  /// How many rows the blocks take, empty ones between them included.
  int get rows =>
      spots.values.fold(0, (most, spot) => math.max(most, spot.bottom));

  /// Whether [block] may take [spot]: on the grid, within its sizes, and over
  /// no other block.
  bool fits(HomeBlock block, HomeSpot spot) {
    final sizes = block.sizes;
    if (spot.x < 0 || spot.y < 0 || spot.right > kHomeColumns) return false;
    if (spot.w < sizes.minW ||
        spot.w > sizes.maxW ||
        spot.h < sizes.minH ||
        spot.h > sizes.maxH) {
      return false;
    }
    for (final MapEntry(key: other, value: there) in spots.entries) {
      if (other != block && there.overlaps(spot)) return false;
    }
    return true;
  }

  /// What letting [block] go with its top left at [x], [y] does, and with
  /// which block it would trade places.
  (HomeDrop, HomeBlock?) dropAt(HomeBlock block, int x, int y) {
    final own = spots[block];
    if (own == null) return (HomeDrop.blocked, null);
    final to = own.at(x, y);
    if (fits(block, to)) return (HomeDrop.fits, null);
    // Exactly on a block of its own size: they trade places. Partly over one
    // is in the way - nothing is pushed aside.
    for (final MapEntry(key: other, value: there) in spots.entries) {
      if (other != block && there == to) return (HomeDrop.swaps, other);
    }
    return (HomeDrop.blocked, null);
  }

  /// [block] let go at [x], [y]: moved, traded, or left where it was.
  HomeLayout moved(HomeBlock block, int x, int y) {
    final own = spots[block];
    if (own == null) return this;
    final (drop, other) = dropAt(block, x, y);
    return switch (drop) {
      HomeDrop.fits => _with({block: own.at(x, y)}),
      HomeDrop.swaps => _with({block: own.at(x, y), other!: own}),
      HomeDrop.blocked => this,
    };
  }

  /// [block] with [edge] dragged by [steps] cells - more room for a positive
  /// number, less for a negative one - as far as its sizes, the grid and its
  /// neighbours allow, one cell at a time.
  HomeSpot stretched(HomeBlock block, HomeEdge edge, int steps) {
    final own = spots[block]!;
    var best = own;
    final step = steps.sign;
    for (var i = 1; i <= steps.abs(); i++) {
      final next = _edgeMoved(own, edge, i * step);
      if (!fits(block, next)) break;
      best = next;
    }
    return best;
  }

  static HomeSpot _edgeMoved(HomeSpot spot, HomeEdge edge, int by) =>
      switch (edge) {
        HomeEdge.left => HomeSpot(spot.x - by, spot.y, spot.w + by, spot.h),
        HomeEdge.right => HomeSpot(spot.x, spot.y, spot.w + by, spot.h),
        HomeEdge.top => HomeSpot(spot.x, spot.y - by, spot.w, spot.h + by),
        HomeEdge.bottom => HomeSpot(spot.x, spot.y, spot.w, spot.h + by),
      };

  /// [block] at [spot], when it may be there; otherwise unchanged.
  HomeLayout placed(HomeBlock block, HomeSpot spot) =>
      fits(block, spot) ? _with({block: spot}) : this;

  /// Off the screen; its place stays empty.
  HomeLayout without(HomeBlock block) => HomeLayout({...spots}..remove(block));

  /// Back on the screen: at [at] when there is room, otherwise in the first
  /// free place its starting size fits, from the top.
  HomeLayout withShown(HomeBlock block, {HomeSpot? at}) {
    if (shows(block)) return this;
    if (at != null && fits(block, at)) return _with({block: at});
    final sizes = block.sizes;
    return _with({block: firstFree(block, sizes.w, sizes.h)});
  }

  /// The first place, top to bottom and left to right, where [block] fits at
  /// [w] by [h]. There always is one: below the last block it is all room.
  HomeSpot firstFree(HomeBlock block, int w, int h) {
    for (var y = 0; ; y++) {
      for (var x = 0; x + w <= kHomeColumns; x++) {
        final spot = HomeSpot(x, y, w, h);
        if (fits(block, spot)) return spot;
      }
    }
  }

  HomeLayout _with(Map<HomeBlock, HomeSpot> changes) =>
      HomeLayout({...spots, ...changes});
}

/// The layout of an app that has never been told otherwise: the blocks under
/// each other at their starting size. Steps only with a watch to count them,
/// the coach only with a key - without either the block has nothing to say.
HomeLayout defaultHomeLayout({bool health = false, bool coach = false}) {
  var layout = const HomeLayout({});
  for (final block in HomeBlock.values) {
    if (!block.onByDefault) continue;
    if (block == HomeBlock.steps && !health) continue;
    if (block == HomeBlock.coach && !coach) continue;
    final sizes = block.sizes;
    layout = layout._with({block: HomeSpot(0, layout.rows, sizes.w, sizes.h)});
  }
  return layout;
}

/// Reads a stored layout, and falls back to the default rather than throwing.
///
/// A place that is damaged - off the grid, the wrong size, over another block
/// - is mended into the first free place that fits. A block the stored value
/// does not mention did not exist when it was written: it joins at the
/// bottom, on or off according to its own default.
///
/// A layout from before the grid - an order, and which blocks were half
/// width - is laid out once the way it looked: full width blocks under each
/// other, two half ones side by side.
HomeLayout parseHomeLayout(
  String? stored, {
  bool health = false,
  bool coach = false,
}) {
  final fallback = defaultHomeLayout(health: health, coach: coach);
  if (stored == null || stored.trim().isEmpty) return fallback;

  final Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    return fallback;
  }
  if (decoded is! Map) return fallback;

  final known = <HomeBlock>{};
  var layout = const HomeLayout({});

  if (decoded['spots'] is Map) {
    for (final MapEntry(:key, :value) in (decoded['spots'] as Map).entries) {
      final block = key is String ? HomeBlock.fromWire(key) : null;
      if (block == null || known.contains(block) || value is! List) continue;
      final cells = [for (final n in value) n is num ? n.toInt() : 0];
      if (cells.length != 4) continue;
      known.add(block);
      layout = _mended(layout, block, cells[0], cells[1], cells[2], cells[3]);
    }
    for (final wire in _stringList(decoded['hidden'])) {
      if (HomeBlock.fromWire(wire) case final block?) known.add(block);
    }
  } else {
    layout = _fromList(decoded, known);
  }

  for (final block in HomeBlock.values) {
    if (known.contains(block) || !block.onByDefault) continue;
    final sizes = block.sizes;
    layout = layout._with({block: HomeSpot(0, layout.rows, sizes.w, sizes.h)});
  }
  return layout;
}

/// [block] at the place it was stored at, or as near as the rules allow.
HomeLayout _mended(
  HomeLayout layout,
  HomeBlock block,
  int x,
  int y,
  int w,
  int h,
) {
  final sizes = block.sizes;
  final width = sizes.clampW(w);
  final spot = HomeSpot(
    x.clamp(0, kHomeColumns - width),
    math.max(0, y),
    width,
    sizes.clampH(h),
  );
  return layout.fits(block, spot)
      ? layout._with({block: spot})
      : layout._with({block: layout.firstFree(block, spot.w, spot.h)});
}

/// A layout from before the grid: blocks in order, each full width or half.
HomeLayout _fromList(Map<dynamic, dynamic> decoded, Set<HomeBlock> known) {
  final order = <HomeBlock>[];
  for (final wire in _stringList(decoded['order'])) {
    final block = HomeBlock.fromWire(wire);
    if (block != null && !order.contains(block)) order.add(block);
  }
  final hidden = {
    for (final wire in _stringList(decoded['hidden']))
      ?HomeBlock.fromWire(wire),
  };
  final small = {
    for (final wire in _stringList(decoded['small'])) ?HomeBlock.fromWire(wire),
  };
  known.addAll(order);
  known.addAll(hidden);

  var layout = const HomeLayout({});
  // A half block waiting for a second one beside it.
  HomeSpot? half;
  for (final block in order) {
    if (hidden.contains(block)) continue;
    final sizes = block.sizes;
    if (!small.contains(block)) {
      half = null;
      layout = layout._with({block: HomeSpot(0, layout.rows, 4, sizes.h)});
    } else if (half != null) {
      layout = layout._with({block: HomeSpot(2, half.y, 2, sizes.h)});
      half = null;
    } else {
      half = HomeSpot(0, layout.rows, 2, sizes.h);
      layout = layout._with({block: half});
    }
  }
  return layout;
}

String encodeHomeLayout(HomeLayout layout) => jsonEncode({
  'v': 2,
  'spots': {
    for (final block in layout.visible)
      block.wire: [
        layout.spots[block]!.x,
        layout.spots[block]!.y,
        layout.spots[block]!.w,
        layout.spots[block]!.h,
      ],
  },
  'hidden': [for (final block in layout.hidden) block.wire],
});

List<String> _stringList(Object? value) => [
  if (value is List)
    for (final entry in value)
      if (entry is String) entry,
];
