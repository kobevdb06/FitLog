import 'dart:io';

import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/core/widgets/charts.dart';
import 'package:fitlog/core/widgets/numeric_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// What TalkBack hears, and what a finger can hit (DECISIONS 292).
void main() {
  setUpAll(initialiseTestLocale);

  testWidgets('a chart says what it shows', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TrendLineChart(
                points: [
                  ChartPoint(DateTime(2026, 9, 1), 80),
                  ChartPoint(DateTime(2026, 10, 1), 90),
                ],
              ),
              const SimpleBarChart(values: [3, 4], labels: ['ma', 'di']),
              const Sparkline(values: [1, 2, 3]),
              const MiniBarChart(values: [1, 2]),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('van 80 naar 90')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('ma 3, di 4')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('van 1 naar 3')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1, 2')), findsWidgets);
    handle.dispose();
  });

  testWidgets('the keypad handle that says it closes, closes', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KeypadHandle(onDismiss: () => closed++)),
      ),
    );
    await tester.tap(find.byType(KeypadHandle));
    expect(closed, 1);
  });

  test('every icon button named in the report has a name', () {
    for (final (path, count) in [
      ('lib/features/history/presentation/history_screen.dart', 2),
      ('lib/features/workout/presentation/pr_attempt_screen.dart', 2),
      ('lib/features/workout/presentation/rest_timer_screen.dart', 1),
      ('lib/features/onboarding/presentation/onboarding_flow.dart', 1),
      ('lib/features/exercises/presentation/exercise_library_screen.dart', 1),
    ]) {
      final source = File(path).readAsStringSync();
      final unnamed = RegExp(r'IconButton\(\s*(?!tooltip)(icon|onPressed)')
          .allMatches(source)
          .length;
      expect(unnamed, 0, reason: '$path: $count to name');
    }
  });
}
