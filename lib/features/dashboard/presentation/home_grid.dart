/// The Start tab as a grid you arrange with your finger, the way a phone's
/// own home screen is arranged.
///
/// Hold a block and it is in your hand: it follows your finger, and an
/// outline shows the cells it would land on - green where there is room, the
/// accent colour where it would trade places with a block its size, red where
/// something is in the way. Tap a block while arranging and it gets a frame
/// with a handle on every edge: drag one and the block grows or shrinks a
/// cell at a time, stopping at its neighbours. Nothing ever moves on its own,
/// and a place a block leaves stays empty.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/back_gesture.dart';
import '../domain/home_layout.dart';

/// The room between two cells.
const double kHomeGap = AppSpacing.md;

/// The height of a row at normal text size.
const double kHomeRowHeight = 56;

/// How long a block is held before it is in your hand. Shorter than a long
/// press elsewhere: arranging is what holding a block is for.
const Duration kHomeHold = Duration(milliseconds: 350);

/// Empty rows below the last block while arranging, so a block always has
/// somewhere to go.
const int kHomeSpareRows = 2;

/// The margin around the cells. The handles and the cross sit half outside a
/// block, and what lies outside the grid cannot be touched: a block across
/// the full width had a right handle nobody could reach.
const double kHomeInset = AppSpacing.lg;

/// A row grows with the text, the way a launcher's cells do, so what fits in
/// a block at normal text still fits at large text.
double homeRowHeight(BuildContext context) =>
    kHomeRowHeight *
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6).toDouble();

/// Where the cells are on screen.
class HomeGeometry {
  /// [width] is the grid's, its margins included.
  HomeGeometry({required double width, required this.rowHeight})
    : cellWidth =
          (width - 2 * kHomeInset - kHomeGap * (kHomeColumns - 1)) /
          kHomeColumns;

  final double cellWidth;
  final double rowHeight;

  double get stepX => cellWidth + kHomeGap;
  double get stepY => rowHeight + kHomeGap;

  Rect rectOf(HomeSpot spot) => Rect.fromLTWH(
    kHomeInset + spot.x * stepX,
    kHomeInset + spot.y * stepY,
    spot.w * stepX - kHomeGap,
    spot.h * stepY - kHomeGap,
  );

  /// The whole grid, its margins included.
  double heightOf(int rows) =>
      rows <= 0 ? 0 : rows * stepY - kHomeGap + 2 * kHomeInset;

  /// The cell a block drawn with its top left at [topLeft] lands on.
  (int, int) cellAt(Offset topLeft) => (
    ((topLeft.dx - kHomeInset) / stepX).round(),
    ((topLeft.dy - kHomeInset) / stepY).round(),
  );
}

class HomeGrid extends StatefulWidget {
  const HomeGrid({
    super.key,
    required this.layout,
    required this.editing,
    required this.blockBuilder,
    required this.onChanged,
    required this.onStartEditing,
  });

  final HomeLayout layout;

  /// Arranging: the cells show, and a block is moved rather than used.
  final bool editing;

  /// Draws one block in the place it was given.
  final Widget Function(HomeBlock block, HomeSpot spot) blockBuilder;

  final ValueChanged<HomeLayout> onChanged;

  /// A block was held while not arranging: arranging starts, and the block
  /// is already in your hand.
  final VoidCallback onStartEditing;

  @override
  State<HomeGrid> createState() => _HomeGridState();
}

class _HomeGridState extends State<HomeGrid> {
  /// The block with the frame and the handles.
  HomeBlock? _selected;

  // A block in your hand.
  HomeBlock? _moving;
  Offset _finger = Offset.zero;
  double _scrolledFrom = 0;
  (int, int)? _target;
  HomeDrop _drop = HomeDrop.fits;
  HomeBlock? _swapWith;
  Timer? _autoScroll;
  double _scrollSpeed = 0;
  HomeGeometry? _geometry;

  // An edge in your hand.
  HomeBlock? _resizing;
  HomeSpot? _resized;
  double _edgeDrag = 0;

  // A chip from the row above, over the grid.
  HomeBlock? _chipBlock;
  Offset _chipAt = Offset.zero;
  HomeSpot? _adding;

  // The side handles, kept from Android's back gesture.
  final _sideHandles = [GlobalKey(), GlobalKey()];
  List<Rect> _keptOff = const [];
  Rect _screen = Rect.zero;
  bool _keepAsked = false;
  final _scrollsFollowed = <ScrollPosition>[];

  HomeLayout get _layout => widget.layout;

  ScrollPosition? get _scroll => Scrollable.maybeOf(context)?.position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The page scrolls up and down and the tabs slide sideways, and the
    // handles go along without the grid being built again.
    final positions = [
      for (final axis in Axis.values)
        ?Scrollable.maybeOf(context, axis: axis)?.position,
    ];
    if (listEquals(positions, _scrollsFollowed)) return;
    for (final position in _scrollsFollowed) {
      position.removeListener(_keepHandlesFreeAfterLayout);
    }
    _scrollsFollowed
      ..clear()
      ..addAll(positions);
    for (final position in positions) {
      position.addListener(_keepHandlesFreeAfterLayout);
    }
  }

  @override
  void didUpdateWidget(HomeGrid old) {
    super.didUpdateWidget(old);
    if (!widget.editing || (_selected != null && !_layout.shows(_selected!))) {
      _selected = null;
    }
    // A block from the row above lands on the first free place, which can
    // be below the screen: the page goes there, and the block has its frame
    // to be sized right away.
    final added = [
      for (final block in _layout.visible)
        if (!old.layout.shows(block)) block,
    ];
    if (widget.editing && old.editing && added.length == 1) {
      _selected = added.single;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _bringIntoView(added.single),
      );
    }
  }

  void _bringIntoView(HomeBlock block) {
    final box = mounted ? context.findRenderObject() : null;
    final spot = _layout.spotOf(block);
    final geometry = _geometry;
    if (box is! RenderBox || spot == null || geometry == null) return;
    box.showOnScreen(
      rect: geometry.rectOf(spot).inflate(kHomeInset),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    for (final position in _scrollsFollowed) {
      position.removeListener(_keepHandlesFreeAfterLayout);
    }
    if (_keptOff.isNotEmpty) BackGesture.keepOff(const []);
    super.dispose();
  }

  /// After the next layout, when the handles are where they are going: a
  /// scroll tells its listeners before anything has moved.
  void _keepHandlesFreeAfterLayout() {
    if (_keepAsked) return;
    _keepAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepAsked = false;
      if (mounted) _keepHandlesFree();
    });
  }

  /// Where the side handles are on screen now, asked of Android whenever it
  /// changes: a swipe from the edge there drags the handle instead of
  /// closing the app.
  void _keepHandlesFree() {
    final screen = _screen;
    final rects = <Rect>[
      if (widget.editing && _selected != null && _moving == null)
        for (final key in _sideHandles)
          if (key.currentContext?.findRenderObject() case final RenderBox box
              when box.attached && box.hasSize)
            if ((box.localToGlobal(Offset.zero) & box.size) case final rect
                when rect.overlaps(screen))
              rect,
    ];
    if (listEquals(rects, _keptOff)) return;
    _keptOff = rects;
    BackGesture.keepOff(rects);
  }

  // ---- moving ---------------------------------------------------------

  void _pickUp(HomeBlock block) {
    if (!widget.editing) widget.onStartEditing();
    HapticFeedback.mediumImpact();
    final spot = _layout.spotOf(block)!;
    setState(() {
      _moving = block;
      _selected = null;
      _finger = Offset.zero;
      _scrolledFrom = _scroll?.pixels ?? 0;
      _target = (spot.x, spot.y);
      _drop = HomeDrop.fits;
    });
  }

  /// How far the block is from its place: the finger, and whatever the page
  /// scrolled under it since.
  Offset get _moveOffset =>
      _finger + Offset(0, (_scroll?.pixels ?? 0) - _scrolledFrom);

  void _drag(Offset finger, Offset global) {
    if (_moving == null) return;
    _finger = finger;
    _aim();
    _followEdge(global);
  }

  void _aim() {
    final block = _moving;
    final geometry = _geometry;
    if (block == null || geometry == null) return;
    final spot = _layout.spotOf(block)!;
    final (cx, cy) = geometry.cellAt(
      geometry.rectOf(spot).topLeft + _moveOffset,
    );
    final x = cx.clamp(0, kHomeColumns - spot.w);
    final y = _rowWithin(cy);
    final (drop, other) = x == spot.x && y == spot.y
        ? (HomeDrop.fits, null)
        : _layout.dropAt(block, x, y);
    if ((x, y) != _target) HapticFeedback.selectionClick();
    setState(() {
      _target = (x, y);
      _drop = drop;
      _swapWith = drop == HomeDrop.swaps ? other : null;
    });
  }

  void _letGo() {
    _stopScrolling();
    final block = _moving;
    final target = _target;
    setState(() {
      _moving = null;
      _target = null;
      _swapWith = null;
    });
    if (block == null || target == null) return;
    final spot = _layout.spotOf(block)!;
    if (target == (spot.x, spot.y)) return;
    final next = _layout.moved(block, target.$1, target.$2);
    if (!identical(next, _layout)) widget.onChanged(next);
  }

  /// Near the top or the bottom of the screen the page scrolls along, so a
  /// block - or a chip - can go further than the screen is high.
  void _followEdge(Offset global) {
    final scrollable = Scrollable.maybeOf(context);
    final box = scrollable?.context.findRenderObject();
    if (scrollable == null || box is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const zone = 72.0;
    const fastest = 14.0;
    _scrollSpeed = global.dy < top + zone
        ? -fastest * (top + zone - global.dy) / zone
        : global.dy > bottom - zone
        ? fastest * (global.dy - bottom + zone) / zone
        : 0;
    if (_scrollSpeed == 0) {
      _stopScrolling();
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final position = _scroll;
      if (position == null) return;
      final to = (position.pixels + _scrollSpeed).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (to == position.pixels) return;
      position.jumpTo(to);
      if (_moving != null) {
        _aim();
      } else if (_chipBlock case final block?) {
        setState(() => _adding = _chipSpot(block, _chipAt));
      }
    });
  }

  /// A block starts at most on the last of the spare rows. Further down, the
  /// grid would grow under the finger and the page scroll after it without
  /// end.
  int _rowWithin(int row) =>
      row.clamp(0, _layout.rows + kHomeSpareRows - 1).toInt();

  void _stopScrolling() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  // ---- resizing -------------------------------------------------------

  void _edgeStart(HomeBlock block) => setState(() {
    _resizing = block;
    _resized = _layout.spotOf(block);
    _edgeDrag = 0;
  });

  void _edgeUpdate(HomeEdge edge, double delta) {
    final block = _resizing;
    final geometry = _geometry;
    if (block == null || geometry == null) return;
    _edgeDrag += delta;
    final step = edge == HomeEdge.left || edge == HomeEdge.right
        ? geometry.stepX
        : geometry.stepY;
    final grow = edge == HomeEdge.left || edge == HomeEdge.top
        ? -_edgeDrag
        : _edgeDrag;
    final next = _layout.stretched(block, edge, (grow / step).round());
    if (next == _resized) return;
    HapticFeedback.selectionClick();
    setState(() => _resized = next);
  }

  void _edgeEnd() {
    final block = _resizing;
    final spot = _resized;
    setState(() {
      _resizing = null;
      _resized = null;
    });
    if (block == null || spot == null || spot == _layout.spotOf(block)) return;
    widget.onChanged(_layout.placed(block, spot));
  }

  // ---- a chip from above ----------------------------------------------

  HomeSpot? _chipSpot(HomeBlock block, Offset global) {
    final geometry = _geometry;
    final box = context.findRenderObject();
    if (geometry == null || box is! RenderBox) return null;
    final sizes = block.sizes;
    final (cx, cy) = geometry.cellAt(box.globalToLocal(global));
    return HomeSpot(
      cx.clamp(0, kHomeColumns - sizes.w),
      _rowWithin(cy),
      sizes.w,
      sizes.h,
    );
  }

  // ---- what a screen reader can do instead ------------------------------

  Map<CustomSemanticsAction, VoidCallback> _actions(HomeBlock block) {
    final spot = _layout.spotOf(block)!;
    final actions = <CustomSemanticsAction, VoidCallback>{};
    void offer(String label, HomeLayout next) {
      if (identical(next, _layout)) return;
      actions[CustomSemanticsAction(label: label)] = () =>
          widget.onChanged(next);
    }

    void move(String label, int dx, int dy) {
      final x = spot.x + dx;
      final y = spot.y + dy;
      if (x < 0 || y < 0 || x + spot.w > kHomeColumns) return;
      offer(label, _layout.moved(block, x, y));
    }

    void stretch(String label, HomeEdge edge, int steps) {
      final to = _layout.stretched(block, edge, steps);
      if (to != spot) offer(label, _layout.placed(block, to));
    }

    move('Naar links', -1, 0);
    move('Naar rechts', 1, 0);
    move('Omhoog', 0, -1);
    move('Omlaag', 0, 1);
    stretch('Breder', HomeEdge.right, 1);
    stretch('Smaller', HomeEdge.right, -1);
    stretch('Hoger', HomeEdge.bottom, 1);
    stretch('Lager', HomeEdge.bottom, -1);
    offer('Van het startscherm halen', _layout.without(block));
    return actions;
  }

  // ---- drawing --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _screen = Offset.zero & MediaQuery.sizeOf(context);
    _keepHandlesFreeAfterLayout();
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _geometry = HomeGeometry(
          width: constraints.maxWidth,
          rowHeight: homeRowHeight(context),
        );
        final theme = Theme.of(context);
        final editing = widget.editing;

        final moving = _moving;
        final target = _target;
        final targetSpot = moving == null || target == null
            ? null
            : _layout.spotOf(moving)!.at(target.$1, target.$2);

        var rows = _layout.rows;
        for (final extra in [targetSpot, _resized, _adding]) {
          if (extra != null) rows = math.max(rows, extra.bottom);
        }
        if (editing) rows += kHomeSpareRows;

        final selected = _selected;
        final selectedSpot = selected == null
            ? null
            : _resized ?? _layout.spotOf(selected);

        final stack = SizedBox(
          height: geometry.heightOf(rows),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (editing)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CellsPainter(
                      geometry: geometry,
                      rows: rows,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                ),
              for (final block in _layout.visible)
                if (block != moving)
                  _block(
                    block,
                    geometry,
                    // The block it would trade places with is already in the
                    // place it would get.
                    at: block == _swapWith ? _layout.spotOf(moving!) : null,
                  ),
              if (_adding case final spot?)
                _outline(
                  geometry.rectOf(spot),
                  color: _layout.fits(_chipBlock!, spot)
                      ? AppColors.success
                      : theme.colorScheme.error,
                ),
              if (selected != null &&
                  selectedSpot != null &&
                  _resized != null &&
                  _resized != _layout.spotOf(selected))
                _outline(
                  geometry.rectOf(selectedSpot),
                  color: theme.colorScheme.primary,
                  label: '${selectedSpot.w} × ${selectedSpot.h}',
                ),
              if (moving != null) _block(moving, geometry),
              // Over the block in your hand, which covers the cells once it
              // is right above them.
              if (targetSpot != null)
                _outline(
                  geometry.rectOf(targetSpot),
                  color: switch (_drop) {
                    HomeDrop.fits => AppColors.success,
                    HomeDrop.swaps => theme.colorScheme.primary,
                    HomeDrop.blocked => theme.colorScheme.error,
                  },
                  label: _drop == HomeDrop.swaps ? 'Wisselen' : null,
                ),
              if (editing && selected != null && moving == null)
                ..._frame(selected, geometry),
            ],
          ),
        );

        return DragTarget<HomeBlock>(
          onWillAcceptWithDetails: (details) =>
              editing && !_layout.shows(details.data),
          onMove: (details) {
            setState(() {
              _chipBlock = details.data;
              _chipAt = details.offset;
              _adding = _chipSpot(details.data, details.offset);
            });
            _followEdge(details.offset);
          },
          onLeave: (_) {
            _stopScrolling();
            setState(() {
              _chipBlock = null;
              _adding = null;
            });
          },
          onAcceptWithDetails: (details) {
            _stopScrolling();
            final spot = _adding;
            setState(() {
              _chipBlock = null;
              _adding = null;
            });
            if (spot != null && _layout.fits(details.data, spot)) {
              widget.onChanged(_layout.withShown(details.data, at: spot));
            }
          },
          builder: (context, _, _) => GestureDetector(
            // A tap beside the blocks puts the frame away.
            onTap: editing && selected != null
                ? () => setState(() => _selected = null)
                : null,
            behavior: HitTestBehavior.translucent,
            child: stack,
          ),
        );
      },
    );
  }

  Widget _block(HomeBlock block, HomeGeometry geometry, {HomeSpot? at}) {
    final spot = at ?? _layout.spotOf(block)!;
    final moving = block == _moving;
    final rect = geometry
        .rectOf(spot)
        .shift(moving ? _moveOffset : Offset.zero);
    final editing = widget.editing;

    Widget child = IgnorePointer(
      ignoring: editing,
      child: widget.blockBuilder(block, spot),
    );
    if (moving) {
      child = Transform.scale(
        scale: 1.03,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: child,
        ),
      );
    }

    return Positioned.fromRect(
      key: ValueKey('blok-${block.wire}'),
      rect: rect,
      child: Semantics(
        customSemanticsActions: editing && !moving ? _actions(block) : null,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(
                    duration: kHomeHold,
                    debugOwner: this,
                  ),
                  (recognizer) => recognizer
                    ..onLongPressStart = ((_) => _pickUp(block))
                    ..onLongPressMoveUpdate = ((details) =>
                        _drag(details.offsetFromOrigin, details.globalPosition))
                    ..onLongPressEnd = ((_) => _letGo())
                    ..onLongPressCancel = (() {
                      if (_moving == block) _letGo();
                    }),
                ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (recognizer) => recognizer.onTap = widget.editing
                      ? () => setState(
                          () => _selected = _selected == block ? null : block,
                        )
                      : null,
                ),
          },
          child: child,
        ),
      ),
    );
  }

  Widget _outline(Rect rect, {required Color color, String? label}) =>
      Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            alignment: Alignment.center,
            child: label == null
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
      );

  /// The frame of the selected block: a handle on every edge and the cross.
  List<Widget> _frame(HomeBlock block, HomeGeometry geometry) {
    final rect = geometry.rectOf(_layout.spotOf(block)!);
    final color = Theme.of(context).colorScheme.primary;
    const touch = 44.0;

    Widget handle(HomeEdge edge, Offset centre) {
      final horizontal = edge == HomeEdge.left || edge == HomeEdge.right;
      return Positioned(
        key: ValueKey('rand-${block.wire}-${edge.name}'),
        left: centre.dx - touch / 2,
        top: centre.dy - touch / 2,
        width: touch,
        height: touch,
        child: Semantics(
          key: switch (edge) {
            HomeEdge.left => _sideHandles.first,
            HomeEdge.right => _sideHandles.last,
            _ => null,
          },
          label: switch (edge) {
            HomeEdge.left => 'Linkerrand',
            HomeEdge.right => 'Rechterrand',
            HomeEdge.top => 'Bovenrand',
            HomeEdge.bottom => 'Onderrand',
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: horizontal ? (_) => _edgeStart(block) : null,
            onHorizontalDragUpdate: horizontal
                ? (details) => _edgeUpdate(edge, details.delta.dx)
                : null,
            onHorizontalDragEnd: horizontal ? (_) => _edgeEnd() : null,
            onVerticalDragStart: horizontal ? null : (_) => _edgeStart(block),
            onVerticalDragUpdate: horizontal
                ? null
                : (details) => _edgeUpdate(edge, details.delta.dy),
            onVerticalDragEnd: horizontal ? null : (_) => _edgeEnd(),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return [
      Positioned.fromRect(
        rect: rect.inflate(3),
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 3),
            ),
          ),
        ),
      ),
      handle(HomeEdge.left, rect.centerLeft),
      handle(HomeEdge.right, rect.centerRight),
      handle(HomeEdge.top, rect.topCenter),
      handle(HomeEdge.bottom, rect.bottomCenter),
      Positioned(
        key: ValueKey('weg-${block.wire}'),
        left: rect.right - 16,
        top: rect.top - 16,
        child: Tooltip(
          message: 'Van het startscherm halen',
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                setState(() => _selected = null);
                widget.onChanged(_layout.without(block));
              },
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// The cells, drawn as fine dashed boxes while arranging.
class _CellsPainter extends CustomPainter {
  _CellsPainter({
    required this.geometry,
    required this.rows,
    required this.color,
  });

  final HomeGeometry geometry;
  final int rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < kHomeColumns; x++) {
        final rect = geometry.rectOf(HomeSpot(x, y, 1, 1));
        final path = Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
        for (final metric in path.computeMetrics()) {
          for (var at = 0.0; at < metric.length; at += 8) {
            canvas.drawPath(metric.extractPath(at, at + 4), paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CellsPainter old) =>
      old.rows != rows ||
      old.color != color ||
      old.geometry.cellWidth != geometry.cellWidth ||
      old.geometry.rowHeight != geometry.rowHeight;
}
