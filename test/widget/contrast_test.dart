import 'dart:math' as math;

import 'package:fitlog/core/theme/app_colors.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/core/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contrast ratio of WCAG 2: 1:1 for the same colour, 21:1 for black on
/// white. Text needs 4.5:1; borders, icons and lines need 3:1.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Colours you can read, in light mode as well (DECISIONS 305).
void main() {
  final light = AppTheme.light;
  final dark = AppTheme.dark;

  /// [read] run inside [theme], for the colours that depend on it.
  Future<T> inTheme<T>(
    WidgetTester tester,
    ThemeData theme,
    T Function(BuildContext context) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return value;
  }

  test('white on a filled button reaches 4.5:1, in both modes', () {
    for (final theme in [light, dark]) {
      final fill = theme.filledButtonTheme.style!.backgroundColor!.resolve({})!;
      final text = theme.filledButtonTheme.style!.foregroundColor!.resolve({})!;
      expect(contrast(text, fill), greaterThanOrEqualTo(4.5));
    }
    expect(
      contrast(Colors.white, AppColors.dangerFill),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(Colors.white, AppColors.accentFill),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('in light mode the accent, green, amber and red read at '
      '4.5:1, on a card and on the background', (tester) async {
    final colours = await inTheme(
      tester,
      light,
      (context) => [
        AppColors.accentOf(context),
        AppColors.successOf(context),
        AppColors.recordOf(context),
        AppColors.dangerOf(context),
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.error,
      ],
    );
    for (final colour in colours) {
      for (final ground in [
        light.colorScheme.surface,
        AppColors.lightBackground,
      ]) {
        expect(
          contrast(colour, ground),
          greaterThanOrEqualTo(4.5),
          reason: '$colour on $ground',
        );
      }
    }
  });

  testWidgets('in dark mode they stay as they were', (tester) async {
    final colours = await inTheme(
      tester,
      dark,
      (context) => [
        AppColors.accentOf(context),
        AppColors.successOf(context),
        AppColors.recordOf(context),
        AppColors.dangerOf(context),
      ],
    );
    expect(colours, [
      AppColors.accent,
      AppColors.success,
      AppColors.record,
      AppColors.danger,
    ]);
  });

  test('the border of a field reaches 3:1 against its fill and the card '
      'around it', () {
    for (final theme in [light, dark]) {
      final input = theme.inputDecorationTheme;
      final border = input.enabledBorder!.borderSide.color;
      for (final ground in [input.fillColor!, theme.colorScheme.surface]) {
        expect(
          contrast(border, ground),
          greaterThanOrEqualTo(3),
          reason: '${theme.brightness}: $border on $ground',
        );
      }
    }
  });

  test('a switch that is off has an edge of 3:1', () {
    for (final theme in [light, dark]) {
      final edge = theme.switchTheme.trackOutlineColor!.resolve({})!;
      expect(
        contrast(edge, theme.colorScheme.surface),
        greaterThanOrEqualTo(3),
        reason: '${theme.brightness}',
      );
    }
  });

  testWidgets('the letters of a muscle read at 4.5:1 in light mode', (
    tester,
  ) async {
    for (final muscle in AppColors.muscleColors.keys) {
      await tester.pumpWidget(
        MaterialApp(
          theme: light,
          home: Scaffold(body: MuscleAvatar(muscle: muscle)),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(MuscleAvatar),
          matching: find.byType(Text),
        ),
      );
      final box =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(MuscleAvatar),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      final ground = Color.alphaBlend(box.color!, light.colorScheme.surface);
      expect(
        contrast(text.style!.color!, ground),
        greaterThanOrEqualTo(4.5),
        reason: muscle,
      );
    }
  });
}
