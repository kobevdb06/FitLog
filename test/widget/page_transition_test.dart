import 'package:fitlog/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a pushed page arrives.
///
/// A row that ends in a chevron pointing right should open something that
/// comes from the right. Android's own default is a zoom, which says nothing
/// about direction and leaves that arrow meaning nothing.
void main() {
  for (final (name, theme) in [
    ('donker', AppTheme.dark),
    ('licht', AppTheme.light),
  ]) {
    testWidgets('a pushed page slides in from the right ($name)', (
      tester,
    ) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          navigatorKey: key,
          home: const Scaffold(body: Text('Lijst')),
        ),
      );

      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Detail')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // Part way in: to the right of where it will settle, and moving.
      final width = tester.getSize(find.byType(MaterialApp)).width;
      final arriving = tester.getTopLeft(find.text('Detail')).dx;
      expect(arriving, greaterThan(0));
      expect(arriving, lessThan(width));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Detail')).dx, lessThan(arriving));
    });
  }

  testWidgets('and the list it came from is still behind it', (tester) async {
    // The outgoing page slides a little rather than vanishing, which is what
    // makes the two read as one movement.
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        navigatorKey: key,
        home: const Scaffold(body: Text('Lijst')),
      ),
    );
    final before = tester.getTopLeft(find.text('Lijst')).dx;

    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => const Scaffold(body: Text('Detail')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.getTopLeft(find.text('Lijst')).dx, lessThan(before));
  });
}
