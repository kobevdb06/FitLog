import 'package:fitlog/core/util/feedback_service.dart';
import 'package:fitlog/core/widgets/keypad_value.dart';
import 'package:fitlog/core/widgets/numeric_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Haptics and system sounds go through platform channels that do not exist in
/// a test, so the pad is driven without them.
const _silent = FeedbackService(
  hapticsEnabled: false,
  setCheckSoundEnabled: false,
);

void main() {
  setUpAll(initialiseTestLocale);

  Future<KeypadValue> pumpKeypad(
    WidgetTester tester, {
    KeypadFieldKind kind = KeypadFieldKind.weight,
    KeypadValue initial = const KeypadValue.empty(),
    VoidCallback? onNext,
  }) async {
    var value = initial;
    await tester.pumpWidget(
      wrapForTest(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: NumericKeypad(
                value: value,
                kind: kind,
                unitLabel: 'kg',
                feedback: _silent,
                onNext: onNext,
                onChanged: (next) => setState(() => value = next),
                onDone: () {},
              ),
            ),
          ),
        ),
      ),
    );
    return value;
  }

  /// The pad shows the value in its header, so reading the header is the same
  /// as reading what the user sees.
  String headerValue(WidgetTester tester) {
    final headline = tester.widget<Text>(
      find.descendant(
        of: find.byType(NumericKeypad),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.fontSize ==
                  Theme.of(
                    tester.element(find.byType(NumericKeypad)),
                  ).textTheme.headlineSmall?.fontSize,
        ),
      ),
    );
    return headline.data ?? '';
  }

  testWidgets('typing digits builds up the value', (tester) async {
    await pumpKeypad(tester);
    expect(headerValue(tester), '-');

    await tester.tap(find.widgetWithText(SizedBox, '1').first);
    await tester.pump();
    expect(headerValue(tester), '1');

    await tester.tap(find.widgetWithText(SizedBox, '0').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(SizedBox, '0').first);
    await tester.pump();
    expect(headerValue(tester), '100');
  });

  testWidgets('the comma key adds a decimal', (tester) async {
    await pumpKeypad(tester);

    await tester.tap(find.widgetWithText(SizedBox, '8').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(SizedBox, '2').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(SizedBox, ',').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(SizedBox, '5').first);
    await tester.pump();

    expect(headerValue(tester), '82,5');
  });

  testWidgets('the plus and minus keys step by the loaded increments', (
    tester,
  ) async {
    await pumpKeypad(tester, initial: const KeypadValue('100'));

    await tester.tap(find.text('+2,5'));
    await tester.pump();
    expect(headerValue(tester), '102,5');

    await tester.tap(find.text('+1,25'));
    await tester.pump();
    expect(headerValue(tester), '103,75');

    await tester.tap(find.text('−5'));
    await tester.pump();
    expect(headerValue(tester), '98,75');
  });

  testWidgets('reps use whole-number steps and have no comma key', (
    tester,
  ) async {
    await pumpKeypad(
      tester,
      kind: KeypadFieldKind.reps,
      initial: const KeypadValue('8'),
    );

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text(','), findsNothing);

    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(headerValue(tester), '9');
  });

  testWidgets('backspace removes the last digit', (tester) async {
    await pumpKeypad(tester, initial: const KeypadValue('125'));

    await tester.tap(find.byIcon(Icons.backspace_outlined).last);
    await tester.pump();
    expect(headerValue(tester), '12');
  });

  testWidgets('the clear button empties the field', (tester) async {
    await pumpKeypad(tester, initial: const KeypadValue('125'));

    await tester.tap(find.byTooltip('Leegmaken'));
    await tester.pump();
    expect(headerValue(tester), '-');
  });

  testWidgets('the next key is only shown when there is somewhere to go', (
    tester,
  ) async {
    var moved = false;
    await pumpKeypad(tester, onNext: () => moved = true);

    await tester.tap(find.byIcon(Icons.keyboard_tab));
    await tester.pump();
    expect(moved, isTrue);
  });

  testWidgets('the pad never opens the system keyboard', (tester) async {
    await pumpKeypad(tester);
    // A TextField would be the only thing that could raise it.
    expect(find.byType(EditableText), findsNothing);
  });
}
