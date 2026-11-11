import 'dart:io';

import 'package:fitlog/core/widgets/clip_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A block on Start that cannot show all of itself says so with a fade,
/// rather than cutting its last lines off clean (DECISIONS 290).
void main() {
  Widget box(int lines) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        height: 60,
        child: ClipFade(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lines; i++) const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );

  bool fades(WidgetTester tester) {
    var found = false;
    void visit(Layer layer) {
      if (layer is ShaderMaskLayer) found = true;
      if (layer is ContainerLayer) {
        var child = layer.firstChild;
        while (child != null) {
          visit(child);
          child = child.nextSibling;
        }
      }
    }

    visit(tester.layers.first);
    return found;
  }

  testWidgets('cut off: the bottom fades out', (tester) async {
    await tester.pumpWidget(box(5));
    final render = tester.renderObject<RenderClipFade>(find.byType(ClipFade));
    expect(render.cutsOff, isTrue);
    expect(render.size.height, 60);
    expect(fades(tester), isTrue);
  });

  testWidgets('all of it in sight: no fade', (tester) async {
    await tester.pumpWidget(box(2));
    final render = tester.renderObject<RenderClipFade>(find.byType(ClipFade));
    expect(render.cutsOff, isFalse);
    expect(fades(tester), isFalse);
  });

  test('the blocks on Start use it', () {
    // The block itself is a private widget; its source says which clip.
    final source = File(
      'lib/features/dashboard/presentation/dashboard_screen.dart',
    ).readAsStringSync();
    expect(source, contains('ClipFade('));
    expect(source, isNot(contains('OverflowBox(')));
  });
}
