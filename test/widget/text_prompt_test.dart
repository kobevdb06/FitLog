import 'package:fitlog/core/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The little dialog that asks for one line of text.
///
/// It is behind every "toevoegen" in the app: a muscle group, a piece of kit,
/// a category, a folder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  Future<String?> ask(WidgetTester tester) async {
    String? answer;
    var asked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  asked = true;
                  answer = await promptForText(context, title: 'Naam');
                },
                child: const Text('Vraag'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Vraag'));
    await tester.pumpAndSettle();
    expect(asked, isTrue);
    return answer;
  }

  testWidgets('gives back what you typed', (tester) async {
    await ask(tester);

    await tester.enterText(find.byType(TextField), 'Slee');
    await tester.tap(find.widgetWithText(FilledButton, 'Opslaan'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and survives its own closing animation', (tester) async {
    // The controller used to be disposed the moment the answer came back,
    // while the dialog was still fading out and rebuilding the field it
    // belonged to. That throws, and it threw in every "toevoegen" in the app.
    await ask(tester);

    await tester.enterText(find.byType(TextField), 'Slee');
    await tester.tap(find.widgetWithText(FilledButton, 'Opslaan'));

    // Frame by frame through the fade rather than settling past it.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('cancelling gives back nothing', (tester) async {
    await ask(tester);

    await tester.enterText(find.byType(TextField), 'Slee');
    await tester.tap(find.widgetWithText(TextButton, 'Annuleren'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
