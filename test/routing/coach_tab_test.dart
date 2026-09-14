import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/app/app_state.dart';
import 'package:fitlog/core/security/key_manager.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:fitlog/routing/router.dart';
import 'package:fitlog/routing/tab_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// The coach as a tab of its own, and the screen its button leads to.
///
/// Driven through the app's real router, because both things that were wrong
/// here were about routing: a tab that had to appear only with a key, and a
/// button that pushed a route belonging to another branch and landed on an
/// empty page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // The router asks the app controller whether it is past onboarding
        // and unlocked; here it simply is.
        appControllerProvider.overrideWith(() => _Ready(db)),
      ],
    );
    final router = container!.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.dark,
          locale: const Locale('nl'),
          supportedLocales: const [Locale('nl')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('welke tabbladen er zijn', () {
    test('zonder sleutel slaat de bar de coach over', () {
      expect(visibleBranches(coach: false), [0, 1, 2, 4]);
      expect(visibleBranches(coach: true), [0, 1, 2, 3, 4]);
      // De chat hoort tussen Voortgang en Profiel.
      expect(visibleBranches(coach: true)[3], kChatBranch);
    });
  });

  group('de bar', () {
    testWidgets('heeft vier tabbladen zolang er geen sleutel is', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Chat'), findsNothing);
      for (final label in ['Start', 'Trainen', 'Voortgang', 'Profiel']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('en vijf zodra er een sleutel staat', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pumpApp(tester);

      expect(find.text('Chat'), findsOneWidget);

      // Tussen Voortgang en Profiel, niet erachter.
      final voortgang = tester.getRect(find.text('Voortgang'));
      final chat = tester.getRect(find.text('Chat'));
      final profiel = tester.getRect(find.text('Profiel'));
      expect(chat.left, greaterThan(voortgang.left));
      expect(chat.left, lessThan(profiel.left));
    });

    testWidgets('en de chat opent op dat tabblad', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pumpApp(tester);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(find.text('Vraag je coach'), findsOneWidget);
      // De bar blijft staan: het is een tabblad, geen scherm erboven.
      expect(find.text('Profiel'), findsOneWidget);
    });
  });

  group('de knop naar de instellingen', () {
    testWidgets('opent ze, in plaats van een wit scherm', (tester) async {
      // Die knop duwde een route uit de Profiel-tak vanaf een scherm dat daar
      // niet in zat. go_router bouwde dan een lege pagina.
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pumpApp(tester);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('AI-coach'), findsOneWidget);
      expect(find.text('SLEUTEL'), findsOneWidget);
    });

    testWidgets('en ze is ook vanuit Instellingen te bereiken', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pumpApp(tester);

      container!.read(routerProvider).push(Routes.settingsCoach);
      await tester.pumpAndSettle();

      expect(find.text('AI-coach'), findsOneWidget);
    });
  });
}

/// An app that is open and unlocked, so the shell is what the router shows.
class _Ready extends AppController {
  _Ready(this._db);

  final AppDatabase _db;

  @override
  AppState build() => AppReady(
    db: _db,
    security: const SecurityStatus(
      initialised: true,
      mode: LockMode.none,
      biometricEnabled: false,
      hasRecoveryPhrase: false,
      consecutiveFailures: 0,
      lastFailureAt: null,
    ),
  );
}
