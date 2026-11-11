import 'package:fitlog/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Text up to 1.4, what the layouts are made for; with *Grotere tekst
/// toestaan* up to 2.0 (DECISIONS 307).
void main() {
  /// The scale a screen gets when Android asks for [android].
  Future<double> scaleFor(
    WidgetTester tester, {
    required double android,
    required bool largeText,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = android;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    late double scale;
    await tester.pumpWidget(
      appFrame(
        Builder(
          builder: (context) {
            scale = MediaQuery.textScalerOf(context).scale(10) / 10;
            return const SizedBox();
          },
        ),
        largeText: largeText,
      ),
    );
    return scale;
  }

  testWidgets('without the setting, text stops at 1.4', (tester) async {
    expect(await scaleFor(tester, android: 1.2, largeText: false), 1.2);
    expect(
      await scaleFor(tester, android: 2.0, largeText: false),
      kTextScaleLimit,
    );
  });

  testWidgets('with it, text follows Android up to 2.0', (tester) async {
    expect(await scaleFor(tester, android: 1.7, largeText: true), 1.7);
    expect(await scaleFor(tester, android: 2.0, largeText: true), 2.0);
    expect(
      await scaleFor(tester, android: 3.0, largeText: true),
      kLargeTextScaleLimit,
    );
  });
}
