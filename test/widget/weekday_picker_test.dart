import 'package:fitlog/core/calc/schedule.dart';
import 'package:fitlog/core/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The sheet that asks on which days a routine is done.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  Future<void> open(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    // The largest text the app allows.
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      appFrame(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  pickWeekdays(context, current: WeekdaySet.of([1, 4])),
              child: const Text('Dagen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dagen'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('alle zeven dagen op een regel, ${width.toInt()} breed', (
      tester,
    ) async {
      await open(tester, width: width);

      final monday = tester.getCenter(find.text('ma'));
      final sunday = tester.getCenter(find.text('zo'));
      expect(sunday.dy, monday.dy, reason: 'zondag staat op een nieuwe regel');
      expect(tester.getRect(find.text('zo')).right, lessThan(width));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('een tik kiest een dag, Klaar geeft ze terug', (tester) async {
    WeekdaySet? picked;
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appFrame(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await pickWeekdays(
                context,
                current: WeekdaySet.of([1, 4]),
              ),
              child: const Text('Dagen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dagen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('zo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klaar'));
    await tester.pumpAndSettle();

    expect(picked?.weekdays, [1, 4, 7]);
  });
}
