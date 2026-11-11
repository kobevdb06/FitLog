import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [child] out at its own height and cuts it off where the box ends -
/// and when something is cut off, the bottom fades out.
///
/// A block on Start cut its last lines off clean, without so much as an
/// ellipsis, and a number cut in half looked like data that is not there
/// (DECISIONS 290). The fade says there is more.
class ClipFade extends SingleChildRenderObjectWidget {
  const ClipFade({super.key, super.child, this.fade = 28});

  /// How tall the fade at the bottom is.
  final double fade;

  @override
  RenderClipFade createRenderObject(BuildContext context) =>
      RenderClipFade(fade: fade);

  @override
  void updateRenderObject(BuildContext context, RenderClipFade renderObject) {
    renderObject.fade = fade;
  }
}

class RenderClipFade extends RenderProxyBox {
  RenderClipFade({required this._fade});

  double _fade;
  set fade(double value) {
    if (value == _fade) return;
    _fade = value;
    markNeedsPaint();
  }

  final _clip = LayerHandle<ClipRectLayer>();
  final _mask = LayerHandle<ShaderMaskLayer>();

  /// Whether the child is taller than the box, and so cut off.
  bool get cutsOff {
    final child = this.child;
    return child != null && child.size.height > size.height + 0.5;
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : child.size.width,
        constraints.hasBoundedHeight
            ? constraints.maxHeight
            : child.size.height,
      ),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    return super.hitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) {
        if (!cutsOff || size.height <= 0) {
          _mask.layer = null;
          context.paintChild(child, offset);
          return;
        }
        final start = (1 - _fade / size.height).clamp(0.0, 1.0);
        final layer = _mask.layer ?? ShaderMaskLayer();
        layer
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            stops: [start, 1],
          ).createShader(Offset.zero & size)
          ..maskRect = offset & size
          ..blendMode = BlendMode.dstIn;
        _mask.layer = layer;
        context.pushLayer(
          layer,
          (context, offset) => context.paintChild(child, offset),
          offset,
        );
      },
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    _mask.layer = null;
    super.dispose();
  }
}
