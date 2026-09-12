import 'dart:io';

import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/routing/pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// How a pushed page arrives.
///
/// A row that ends in a chevron pointing right should open something that
/// comes from the right. Two things have to hold for that: the theme has to
/// ask for the movement, and the route has to use a page that consults the
/// theme at all.
void main() {
  Future<GoRouter> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/lijst',
      routes: [
        GoRoute(
          path: '/lijst',
          pageBuilder: (context, state) =>
              appPage(state, const Scaffold(body: Text('Lijst'))),
        ),
        GoRoute(
          path: '/detail',
          pageBuilder: (context, state) =>
              appPage(state, const Scaffold(body: Text('Detail'))),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('it slides in from the right', (tester) async {
    final router = await pump(tester);

    router.push('/detail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final arriving = tester.getTopLeft(find.text('Detail')).dx;
    expect(arriving, greaterThan(0), reason: 'nog onderweg, van rechts');

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Detail')).dx, 0);
  });

  testWidgets('and the list slides a little way out under it', (tester) async {
    final router = await pump(tester);
    final before = tester.getTopLeft(find.text('Lijst')).dx;

    router.push('/detail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.getTopLeft(find.text('Lijst')).dx, lessThan(before));
  });

  test('every ordinary route says which page it uses', () {
    // go_router works the page type out from the widget tree and caches
    // whatever it decides the first time it is asked. Here it lands on
    // "neither Material nor Cupertino", and the fallback has no transition at
    // all - which is why the whole app used to move instantly. A route that
    // leaves it to the guess brings that back, so there must not be one.
    final source = File('lib/routing/router.dart').readAsStringSync();

    expect(
      source.contains('builder: (context, state) =>'),
      isFalse,
      reason: 'gebruik appPage of risingPage, niet de gok van go_router',
    );
  });
}
