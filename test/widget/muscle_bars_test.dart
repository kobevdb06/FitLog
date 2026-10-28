import 'package:fitlog/core/widgets/muscle_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A bar per muscle group, with its name in front of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  testWidgets('met grote letters staat de naam er voluit', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      appFrame(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(32),
            child: MuscleBars(
              bars: [
                MuscleBar(muscle: 'biceps', value: 3, label: '3'),
                MuscleBar(muscle: 'borst', value: 2.5, label: '2,5'),
              ],
            ),
          ),
        ),
      ),
    );

    final finder = find.text('Biceps');
    final text = tester.widget<Text>(finder);
    final whole = TextPainter(
      text: TextSpan(
        text: 'Biceps',
        style: DefaultTextStyle.of(tester.element(finder)).style.merge(
          text.style,
        ),
      ),
      textScaler: MediaQuery.textScalerOf(tester.element(finder)),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(
      tester.getSize(finder).width,
      greaterThanOrEqualTo(whole.width - 0.5),
      reason: 'de naam is afgekapt',
    );
    whole.dispose();
  });
}
