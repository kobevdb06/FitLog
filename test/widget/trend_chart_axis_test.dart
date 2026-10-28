import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/core/formatting/formatters.dart';
import 'package:fitlog/core/widgets/charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The numbers beside a line chart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  final day = DateTime(2026, 10, 1);

  Future<List<Text>> axis(WidgetTester tester, List<double> values) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appFrame(
        Scaffold(
          body: TrendLineChart(
            height: 140,
            points: [
              for (final (i, v) in values.indexed)
                ChartPoint(day.add(Duration(days: i)), v),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    // The numbers on the left: everything that is not a date.
    return [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        if (!(text.data ?? '').contains(RegExp('[a-z]'))) text,
    ];
  }

  testWidgets('ronde getallen, met een komma, en niet over elkaar', (
    tester,
  ) async {
    // Resting heart rate: a few beats around 55.
    final labels = await axis(tester, [54, 57, 55, 56, 54, 57, 54]);

    final shown = [for (final text in labels) text.data!];
    expect(shown, isNotEmpty);
    for (final label in shown) {
      expect(label, isNot(contains('.')), reason: 'geen punt: $label');
      expect(num.tryParse(label.replaceAll(',', '.')), isNotNull);
    }
    // Every step the same: round numbers, evenly apart.
    final numbers = [
      for (final label in shown) double.parse(label.replaceAll(',', '.')),
    ]..sort();
    for (var i = 2; i < numbers.length; i++) {
      expect(
        numbers[i] - numbers[i - 1],
        closeTo(numbers[1] - numbers[0], 0.001),
        reason: '$numbers',
      );
    }
    final rects = [
      for (final text in labels) tester.getRect(find.byWidget(text)),
    ]..sort((a, b) => a.top.compareTo(b.top));
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom));
    }
  });

  test('een getal naast een grafiek schrijft een komma', () {
    expect(Formatters.number(52.5), '52,5');
    expect(Formatters.number(60), '60');
    expect(Formatters.number(94.75), '94,75');
  });
}
