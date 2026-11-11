import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/core/widgets/charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The numbers on the left are round in the unit you see, not in the unit
/// the app keeps (DECISIONS 278).
void main() {
  setUpAll(initialiseTestLocale);

  const lbPerKg = 1 / 0.45359237;

  String lb(double kg) => (kg * lbPerKg).toStringAsFixed(1);

  testWidgets('in pond: 210, 220, 230 - niet 209,5, 220,5, 231,5', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrendLineChart(
            points: [
              ChartPoint(DateTime(2026, 9, 1), 95),
              ChartPoint(DateTime(2026, 9, 15), 100),
              ChartPoint(DateTime(2026, 10, 1), 104),
            ],
            valueLabel: lb,
            displayScale: lbPerKg,
          ),
        ),
      ),
    );

    final labels = [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        if (text.data != null && RegExp(r'^\d+\.\d$').hasMatch(text.data!))
          double.parse(text.data!),
    ];
    expect(labels, isNotEmpty);
    for (final value in labels) {
      expect(value % 5, closeTo(0, 0.05), reason: '$value is not round');
    }
  });
}
