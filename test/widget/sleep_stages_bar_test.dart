import 'package:fitlog/features/progress/presentation/sleep_stages_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The stages of a night as a bar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  testWidgets('elke fase is te zien, even hoog als het balkje', (
    tester,
  ) async {
    await tester.pumpWidget(
      appFrame(
        const Scaffold(
          body: SleepStagesBar(
            length: Duration(hours: 7),
            light: 230,
            rem: 95,
            deep: 70,
          ),
        ),
      ),
    );

    // Deep, REM, light, and the half hour neither placed.
    final parts = find.descendant(
      of: find.byType(Row).first,
      matching: find.byType(ColoredBox),
    );
    expect(parts, findsNWidgets(4));
    for (final part in tester.widgetList(parts)) {
      final size = tester.getSize(find.byWidget(part));
      expect(size.height, 16, reason: 'een fase van 0 hoog is niet te zien');
      expect(size.width, greaterThan(0));
    }
  });
}
