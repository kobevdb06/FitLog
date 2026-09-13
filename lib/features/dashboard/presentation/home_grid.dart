/// The Start tab laid out as a grid you can rearrange with your finger.
///
/// It used to be a list of switches on a settings screen: you dragged the word
/// "Deze week" above the word "Herstel" and found out what that looked like
/// afterwards. Here you move the real blocks and see the result while you do
/// it, which is how a phone's own home screen works.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/home_layout.dart';

/// How far a block leans while the screen is in arranging mode.
const double kWiggleRadians = 0.012;

/// Two columns, so a small block is half a screen.
const int kHomeColumns = 2;

/// Room above a block for its cross while you are arranging.
///
/// The cross has to sit inside the block - a Stack does not hit test outside
/// its own bounds - and a block's first line is its title, which it would
/// cover. So while arranging, every block moves down far enough to keep the
/// two apart.
const double kCrossRoom = 22;

/// Lays the visible blocks out, wide ones on their own row and small ones in
/// pairs, and hands each one the size it was given.
class HomeGrid extends StatelessWidget {
  const HomeGrid({
    super.key,
    required this.layout,
    this.only,
    required this.editing,
    required this.blockBuilder,
    required this.onMove,
    required this.onResize,
    required this.onHide,
  });

  final HomeLayout layout;

  /// Which of the visible blocks actually have something to draw, or null for
  /// all of them. A block that draws nothing still takes a row in a Wrap, gap
  /// and all, so it has to be left out rather than shrunk.
  final Set<HomeBlock>? only;

  /// Arranging mode: the blocks lean, and dragging one moves it.
  final bool editing;

  /// Draws one block at the size it has been given.
  final Widget Function(HomeBlock block, HomeBlockSize size) blockBuilder;

  /// [block] was dropped where [onto] sits.
  final void Function(HomeBlock block, HomeBlock onto) onMove;
  final void Function(HomeBlock block) onResize;
  final void Function(HomeBlock block) onHide;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // The gap between two small blocks belongs to neither of them.
    final half = (width - AppSpacing.lg * 2 - AppSpacing.md) / kHomeColumns;
    final full = width - AppSpacing.lg * 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final block in layout.visible)
            if (only == null || only!.contains(block))
              SizedBox(
                width: layout.sizeOf(block) == HomeBlockSize.small
                    ? half
                    : full,
                child: _Arrangeable(
                  block: block,
                  editing: editing,
                  onMove: onMove,
                  onResize: () => onResize(block),
                  onHide: () => onHide(block),
                  child: blockBuilder(block, layout.sizeOf(block)),
                ),
              ),
        ],
      ),
    );
  }
}

/// One block, and what you can do to it while arranging.
class _Arrangeable extends StatelessWidget {
  const _Arrangeable({
    required this.block,
    required this.editing,
    required this.onMove,
    required this.onResize,
    required this.onHide,
    required this.child,
  });

  final HomeBlock block;
  final bool editing;
  final void Function(HomeBlock block, HomeBlock onto) onMove;
  final VoidCallback onResize;
  final VoidCallback onHide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!editing) return child;

    // The block itself must not react to taps while you are arranging it: a
    // tap here means "change the size", not "start this workout".
    final frozen = IgnorePointer(child: child);

    return DragTarget<HomeBlock>(
      onWillAcceptWithDetails: (details) => details.data != block,
      onAcceptWithDetails: (details) => onMove(details.data, block),
      builder: (context, candidate, rejected) {
        final aiming = candidate.isNotEmpty;
        return _Wiggle(
          child: Draggable<HomeBlock>(
            data: block,
            // A phone-sized copy under your finger rather than the block at
            // full size, which would cover most of the screen you are aiming
            // at.
            feedback: Opacity(
              opacity: 0.9,
              child: Transform.scale(
                scale: 0.92,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width / kHomeColumns,
                    child: frozen,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: frozen),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: kCrossRoom),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(
                        color: aiming ? AppColors.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: frozen,
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    key: ValueKey('formaat-${block.wire}'),
                    behavior: HitTestBehavior.translucent,
                    onTap: onResize,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 4,
                  child: _CornerButton(
                    key: ValueKey('verberg-${block.wire}'),
                    icon: Icons.close,
                    tooltip: 'Van het startscherm halen',
                    onTap: onHide,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The small lean that says a thing can be moved.
class _Wiggle extends StatefulWidget {
  const _Wiggle({required this.child});

  final Widget child;

  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Someone who asked their phone to stop animating things asked this too.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: (_controller.value - 0.5) * 2 * kWiggleRadians,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _CornerButton extends StatelessWidget {
  const _CornerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }
}
