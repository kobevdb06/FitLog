import 'package:fitlog/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Letting go of a text field the way a phone should: a tap beside it, or
/// closing the keyboard, and the cursor stops blinking - so a page you come
/// back to does not bring the keyboard back with it.
void main() {
  final field = find.byType(TextField);

  bool focused(WidgetTester tester) => tester
      .widget<EditableText>(find.byType(EditableText, skipOffstage: false))
      .focusNode
      .hasFocus;

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: appBuilder,
        home: home,
        routes: {
          '/verder': (context) => const Scaffold(body: Text('Volgende pagina')),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget page({List<Widget> below = const []}) => Builder(
    builder: (context) => Scaffold(
      body: ListView(
        children: [
          const TextField(),
          const SizedBox(height: 40, child: Text('Ernaast')),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/verder'),
            child: const Text('Verder'),
          ),
          ...below,
        ],
      ),
    ),
  );

  testWidgets('een tik naast een veld laat het los', (tester) async {
    await pumpApp(tester, page());
    await tester.tap(field);
    await tester.pump();
    expect(focused(tester), isTrue);

    await tester.tap(find.text('Ernaast'));
    await tester.pump();

    expect(focused(tester), isFalse);
  });

  testWidgets('scrollen laat het veld niet los', (tester) async {
    await pumpApp(
      tester,
      page(
        below: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 60, child: Text('Rij $i')),
        ],
      ),
    );
    await tester.tap(field);
    await tester.pump();

    // A finger that moves is reading the page, not leaving the field.
    await tester.drag(find.text('Rij 3'), const Offset(0, -40));
    await tester.pumpAndSettle();

    expect(focused(tester), isTrue);
  });

  testWidgets('het toetsenbord sluiten laat het veld los', (tester) async {
    addTearDown(tester.view.reset);
    await pumpApp(tester, page());
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    expect(focused(tester), isTrue);

    // The back gesture closes the keyboard and nothing else.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(focused(tester), isFalse);
  });

  testWidgets('terug op de pagina komt het toetsenbord niet mee terug', (
    tester,
  ) async {
    await pumpApp(tester, page());
    await tester.tap(field);
    await tester.pump();

    await tester.tap(find.text('Verder'));
    await tester.pumpAndSettle();
    expect(find.text('Volgende pagina'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(focused(tester), isFalse);
  });

  testWidgets('een tik in een ander veld geeft dat de focus', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(
          children: [
            TextField(key: Key('een')),
            TextField(key: Key('twee')),
          ],
        ),
      ),
    );
    EditableText editable(String key) => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    );

    await tester.tap(find.byKey(const Key('een')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('twee')));
    await tester.pump();

    expect(editable('een').focusNode.hasFocus, isFalse);
    expect(editable('twee').focusNode.hasFocus, isTrue);
  });
}
