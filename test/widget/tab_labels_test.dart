import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/routing/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// The names under the tabs, with large text on a narrow phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  testWidgets('elke naam op één regel, ook Voortgang', (tester) async {
    final db = createTestDatabase();
    await tester.runAsync(() async {
      await db.settingsDao.ensureInitialized();
      // With the coach there are five tabs, and the least room for each.
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    });
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final router = GoRouter(
      initialLocation: '/een',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            for (final path in ['/een', '/twee', '/drie', '/vier', '/vijf'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (context, state) => const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final labels = ['Start', 'Trainen', 'Voortgang', 'Chat', 'Profiel'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // As high as one line of it in the same style and size.
    for (final label in labels) {
      final finder = find.text(label);
      final element = tester.element(finder);
      final text = tester.widget<Text>(finder);
      final line = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(element).style.merge(text.style),
        ),
        textScaler: MediaQuery.textScalerOf(element),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        tester.getSize(finder).height,
        closeTo(line.height, 1),
        reason: '$label staat op meer dan één regel',
      );
      line.dispose();
    }
  });
}
