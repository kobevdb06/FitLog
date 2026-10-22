import 'package:flutter/material.dart';

/// A column that shows as many of its children as fit, whole - never half a
/// row cut off at the bottom of a block.
///
/// A block on the Start tab has the size you gave it, and a list in it has as
/// much room as that leaves: five records in a tall block, two in a short
/// one. The ones that do not fit are laid out below the edge and clipped.
class FitColumn extends StatelessWidget {
  const FitColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: CustomMultiChildLayout(
      delegate: _FitDelegate(children.length),
      children: [
        for (final (i, child) in children.indexed)
          LayoutId(id: i, child: child),
      ],
    ),
  );
}

class _FitDelegate extends MultiChildLayoutDelegate {
  _FitDelegate(this.count);

  final int count;

  @override
  void performLayout(Size size) {
    var y = 0.0;
    var full = false;
    for (var i = 0; i < count; i++) {
      final child = layoutChild(i, BoxConstraints.tightFor(width: size.width));
      if (!full && y + child.height <= size.height + 0.5) {
        positionChild(i, Offset(0, y));
        y += child.height;
      } else {
        full = true;
        positionChild(i, Offset(0, size.height + 1));
      }
    }
  }

  @override
  bool shouldRelayout(_FitDelegate old) => old.count != count;
}
