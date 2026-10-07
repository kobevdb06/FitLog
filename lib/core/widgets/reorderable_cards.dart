import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_spacing.dart';

/// What a card shows of itself while the cards are being put in order.
class ReorderSummary {
  const ReorderSummary({
    required this.leading,
    required this.title,
    this.subtitle,
    this.accent,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// The colour of its border, as on the card itself: a superset.
  final Color? accent;
}

/// Cards that go in another order by the handle on each of them: the
/// exercises of a session, and of a routine.
///
/// Picking one up folds every card to a single row. A card full of sets is
/// taller than what is left of the screen below your finger, and a list
/// scrolls by itself while what you hold sticks out over its edge - so it ran
/// to the very end, and whatever you picked up landed last. Folded, the row
/// you hold stays under your finger, the others close up around it, and the
/// whole order fits on the screen. Letting go unfolds them again, with the
/// card you moved where you let go of it.
class ReorderableCards extends StatefulWidget {
  const ReorderableCards({
    super.key,
    required this.itemCount,
    required this.keyOf,
    required this.cardBuilder,
    required this.summaryOf,
    required this.onReorder,
    this.itemPadding = EdgeInsets.zero,
    this.header,
    this.footer,
  });

  final int itemCount;

  /// A key that stays with an item wherever it moves.
  final Key Function(int index) keyOf;

  /// The full card, with [handle] where it is picked up.
  final Widget Function(BuildContext context, int index, Widget handle)
  cardBuilder;

  /// The card folded to one row.
  final ReorderSummary Function(int index) summaryOf;

  /// [to] is where it ends up once it has left [from], as [List.insert]
  /// takes it.
  final void Function(int from, int to) onReorder;

  final EdgeInsets itemPadding;

  /// Above the cards and below them, scrolling with them.
  final Widget? header;
  final Widget? footer;

  @override
  State<ReorderableCards> createState() => _ReorderableCardsState();
}

class _ReorderableCardsState extends State<ReorderableCards> {
  final _scroll = ScrollController();
  final _list = GlobalKey<SliverReorderableListState>();

  /// One per item, to find where it is on screen. They also carry a card
  /// into the lifted copy and back, so nothing in it starts over.
  final _boxes = <Key, GlobalKey>{};

  /// The order on screen while the owner catches up with a move: a session
  /// writes it to the database first, and for a frame or two the old order
  /// would come back.
  List<Key>? _moved;

  bool _folded = false;
  Key? _held;

  /// Room above the folded cards that keeps the one you hold where it was.
  double _spacer = 0;

  /// Room below them, so folding never pulls the list back.
  double _tail = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<Key> get _ownerKeys => [
    for (var i = 0; i < widget.itemCount; i++) widget.keyOf(i),
  ];

  /// The owner's indices in the order they are shown.
  List<int> _order() {
    final keys = _ownerKeys;
    final moved = _moved;
    if (moved != null) {
      final caughtUp =
          moved.length == keys.length &&
          Iterable<int>.generate(keys.length).every((i) => moved[i] == keys[i]);
      final sameItems =
          moved.length == keys.length && moved.toSet().containsAll(keys);
      if (!caughtUp && sameItems) {
        final at = {for (var i = 0; i < keys.length; i++) keys[i]: i};
        return [for (final key in moved) at[key]!];
      }
      _moved = null;
    }
    return [for (var i = 0; i < keys.length; i++) i];
  }

  GlobalKey _boxFor(Key key) =>
      _boxes.putIfAbsent(key, () => GlobalKey(debugLabel: 'card $key'));

  double? _topOf(Key key) {
    final box = _boxes[key]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _press(int index, Key key, PointerDownEvent event) {
    final list = _list.currentState;
    if (list == null || _folded) return;
    late final _FoldFirstDrag recognizer;
    recognizer = _FoldFirstDrag(
      debugOwner: this,
      onAccepted: () => _fold(key, recognizer),
      onAbandoned: () => _unfold(keepInPlace: false),
    );
    // The phone's own touch slop, the one the list scrolls with: Android's is
    // smaller than Flutter's default, and a scroll that knows it sooner wins
    // every drag before it starts.
    recognizer.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    list.startItemDragReorder(
      index: index,
      event: event,
      recognizer: recognizer,
    );
  }

  /// Folds the cards, then puts the one you hold back under your finger
  /// before the drag starts: the list takes the size of what you hold at
  /// that moment, and it has to be the folded size.
  void _fold(Key key, _FoldFirstDrag recognizer) {
    if (!_scroll.hasClients) {
      recognizer.ready();
      return;
    }
    final before = _topOf(key);
    final position = _scroll.position;
    setState(() {
      _folded = true;
      _held = key;
      _spacer = 0;
      _tail = position.pixels + position.viewportDimension;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_folded || !_scroll.hasClients) return;
      final after = _topOf(key);
      final spacer = before == null || after == null
          ? 0.0
          : math.max(0.0, before - after);
      // Only as much room below as it takes to stay where the list is.
      final position = _scroll.position;
      final content =
          position.maxScrollExtent +
          position.viewportDimension -
          _tail +
          spacer;
      final tail = math.max(
        0.0,
        position.pixels + position.viewportDimension - content,
      );
      if ((spacer - _spacer).abs() < 0.5 && (tail - _tail).abs() < 0.5) {
        recognizer.ready();
        return;
      }
      setState(() {
        _spacer = spacer;
        _tail = tail;
      });
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) recognizer.ready();
      });
    });
  }

  void _unfold({required bool keepInPlace}) {
    if (!mounted || !_folded) return;
    final key = _held;
    final dropped = key == null || !keepInPlace ? null : _topOf(key);
    setState(() {
      _folded = false;
      _held = null;
      _spacer = 0;
      _tail = 0;
    });
    if (key != null && dropped != null) _keepAt(key, dropped);
  }

  /// Scrolls the unfolded list so the card you moved is where you let go of
  /// it. The cards it passes may not have been laid out yet; a few frames
  /// find it.
  void _keepAt(Key key, double top, [int attempt = 0]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _folded || !_scroll.hasClients) return;
      final position = _scroll.position;
      double clamp(double offset) =>
          offset.clamp(position.minScrollExtent, position.maxScrollExtent);

      final now = _topOf(key);
      if (now != null) {
        final target = clamp(position.pixels + now - top);
        if ((target - position.pixels).abs() < 1) return;
        position.jumpTo(target);
        if (attempt < 4) _keepAt(key, top, attempt + 1);
        return;
      }
      if (attempt >= 8) return;
      // Not laid out: off the screen. A screen at a time toward it.
      final shown = [for (final i in _order()) widget.keyOf(i)];
      final index = shown.indexOf(key);
      final laidOut = [
        for (var i = 0; i < shown.length; i++)
          if (_topOf(shown[i]) != null) i,
      ];
      final below = laidOut.isEmpty || index > laidOut.last;
      final step = position.viewportDimension * (below ? 1 : -1);
      final target = clamp(position.pixels + step);
      if ((target - position.pixels).abs() < 1) return;
      position.jumpTo(target);
      _keepAt(key, top, attempt + 1);
    });
  }

  void _moveItem(int from, int to) {
    final order = _order();
    final keys = [for (final i in order) widget.keyOf(i)];
    keys.insert(to, keys.removeAt(from));
    setState(() => _moved = keys);
    // The owner has caught up with the last move by the time a new drag
    // ends, so what is on screen is its own order.
    widget.onReorder(order[from], to);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order();
    final keys = [for (final i in order) widget.keyOf(i)];
    if (!_folded) _boxes.removeWhere((key, _) => !keys.contains(key));

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        if (_spacer > 0) SliverToBoxAdapter(child: SizedBox(height: _spacer)),
        SliverReorderableList(
          key: _list,
          itemCount: order.length,
          onReorderItem: _moveItem,
          proxyDecorator: (child, index, animation) =>
              _Lifted(onGone: () => _unfold(keepInPlace: true), child: child),
          itemBuilder: (context, index) {
            final source = order[index];
            final key = keys[index];
            final handle = ReorderHandle(
              onPointerDown: (event) => _press(index, key, event),
            );
            return KeyedSubtree(
              key: key,
              child: KeyedSubtree(
                key: _boxFor(key),
                child: Padding(
                  padding: widget.itemPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_folded)
                        _FoldedCard(
                          summary: widget.summaryOf(source),
                          handle: handle,
                        ),
                      // Kept while folded, out of sight: what is half typed
                      // in a card is still there when it unfolds.
                      Visibility(
                        key: const ValueKey('card'),
                        visible: !_folded,
                        maintainState: true,
                        child: widget.cardBuilder(context, source, handle),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
        if (_tail > 0) SliverToBoxAdapter(child: SizedBox(height: _tail)),
      ],
    );
  }
}

/// The handle a card is picked up by, the same on every card that has one.
class ReorderHandle extends StatelessWidget {
  const ReorderHandle({super.key, required this.onPointerDown});

  final PointerDownEventListener onPointerDown;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verslepen om de volgorde te wijzigen',
      child: Listener(
        onPointerDown: onPointerDown,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FoldedCard extends StatelessWidget {
  const _FoldedCard({required this.summary, required this.handle});

  final ReorderSummary summary;
  final Widget handle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lifted = context.dependOnInheritedWidgetOfExactType<_LiftedScope>();
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: lifted != null
              ? theme.colorScheme.primary
              : summary.accent ?? theme.colorScheme.outline,
        ),
        boxShadow: [
          if (lifted != null)
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            handle,
            const SizedBox(width: AppSpacing.xs),
            summary.leading,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (summary.subtitle != null)
                    Text(
                      summary.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card you hold: drawn lifted, and gone when the drag is over.
class _Lifted extends StatefulWidget {
  const _Lifted({required this.onGone, required this.child});

  final VoidCallback onGone;
  final Widget child;

  @override
  State<_Lifted> createState() => _LiftedState();
}

class _LiftedState extends State<_Lifted> {
  @override
  void dispose() {
    // Gone at the end of the drop, once the list has put it in its place:
    // the frame is still being built, so the unfolding waits for its end.
    final onGone = widget.onGone;
    SchedulerBinding.instance.addPostFrameCallback((_) => onGone());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _LiftedScope(
    child: Material(type: MaterialType.transparency, child: widget.child),
  );
}

class _LiftedScope extends InheritedWidget {
  const _LiftedScope({required super.child});

  @override
  bool updateShouldNotify(_LiftedScope oldWidget) => false;
}

/// A drag that only starts once the cards have folded.
///
/// Like an immediate drag, it is a drag as soon as the finger moves past the
/// slop; the list is told only when [ready] says the folded cards are laid
/// out.
class _FoldFirstDrag extends MultiDragGestureRecognizer {
  _FoldFirstDrag({
    super.debugOwner,
    required this.onAccepted,
    required this.onAbandoned,
  });

  /// It is a drag: fold the cards, then call [ready].
  final VoidCallback onAccepted;

  /// It was a drag, and the finger left before it could start.
  final VoidCallback onAbandoned;

  bool _ready = false;
  _FoldFirstPointer? _pointer;

  void ready() {
    _ready = true;
    _pointer?._release();
  }

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _pointer = _FoldFirstPointer(
        event.position,
        event.kind,
        gestureSettings,
        this,
      );

  @override
  String get debugDescription => 'fold first drag';
}

class _FoldFirstPointer extends MultiDragPointerState {
  _FoldFirstPointer(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this._owner,
  );

  final _FoldFirstDrag _owner;
  GestureMultiDragStartCallback? _start;
  bool _accepted = false;
  bool _started = false;

  @override
  void checkForResolutionAfterMove() {
    if (_accepted) return;
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    _accepted = true;
    _start = starter;
    if (_owner._ready) {
      _release();
    } else {
      _owner.onAccepted();
    }
  }

  void _release() {
    final start = _start;
    if (start == null || _started) return;
    _start = null;
    _started = true;
    start(initialPosition);
  }

  @override
  void dispose() {
    final abandoned = _accepted && !_started;
    _start = null;
    if (identical(_owner._pointer, this)) _owner._pointer = null;
    super.dispose();
    if (abandoned) _owner.onAbandoned();
  }
}
