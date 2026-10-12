import 'dart:convert';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/theme/app_theme.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/links.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/presentation/coach_key_screen.dart';
import 'package:fitlog/features/chat/presentation/coach_settings_screen.dart';
import 'package:fitlog/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// Android, as far as links go: it remembers what it was asked to open.
class _Opener implements LinkOpener {
  final opened = <String>[];
  final over = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }

  @override
  Future<bool> openOver(String url) async {
    over.add(url);
    return true;
  }
}

/// Switching the coach on: why, fetching a key, pasting it, tested first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  late _Opener opener;
  late List<http.Request> sent;
  ProviderContainer? container;

  /// What the clipboard holds, and whether anyone read it.
  String? clipboard;
  var clipboardRead = false;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    opener = _Opener();
    sent = [];
    clipboard = null;
    clipboardRead = false;
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  ProviderContainer newContainer({int status = 200}) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      linkOpenerProvider.overrideWithValue(opener),
      coachClientFactoryProvider.overrideWithValue(
        (apiKey, provider) => AiClient(
          apiKey: apiKey,
          provider: provider,
          client: MockClient((request) async {
            sent.add(request);
            return http.Response(
              jsonEncode(
                status == 200
                    ? {
                        'models': [
                          {
                            'name': 'models/gemini-2.5-flash',
                            'displayName': 'Gemini 2.5 Flash',
                            'supportedGenerationMethods': ['generateContent'],
                          },
                        ],
                      }
                    : {
                        'error': {'message': 'API key not valid.'},
                      },
              ),
              status,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ),
    ],
  );

  void fakeClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.hasStrings':
            return {'value': clipboard != null};
          case 'Clipboard.getData':
            clipboardRead = true;
            return clipboard == null ? null : {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    bool pasteFirst = false,
    int status = 200,
  }) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fakeClipboard(tester);
    container = newContainer(status: status);
    await tester.pumpWidget(
      wrapWithContainer(container!, CoachKeyScreen(pasteFirst: pasteFirst)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('eerst waarom, met wat Google met een gratis sleutel mag', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Stap 1 van 3'), findsOneWidget);
    expect(find.text('Je eigen, gratis coach'), findsOneWidget);
    expect(
      find.textContaining('om zijn producten te verbeteren'),
      findsOneWidget,
    );
    await tester.tap(find.text('Voorwaarden van Google'));
    await tester.pumpAndSettle();
    expect(opener.opened, [kGeminiTermsUrl]);
  });

  testWidgets('Haal mijn gratis sleutel opent AI Studio over de app, en '
      'wacht dan op de sleutel', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();

    expect(find.text('Stap 2 van 3'), findsOneWidget);
    expect(find.text('Log in met je Google-account.'), findsOneWidget);
    expect(
      find.text('Kopieer de sleutel en kom terug naar FitLog.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Haal mijn gratis sleutel'));
    await tester.pumpAndSettle();

    expect(opener.over, [kAiStudioKeyUrl]);
    expect(opener.opened, isEmpty, reason: 'over the app, not instead of it');
    expect(find.text('Plak je sleutel'), findsOneWidget);
  });

  testWidgets('wie al een sleutel heeft, gaat meteen naar plakken', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ik heb al een sleutel'));
    await tester.pumpAndSettle();

    expect(find.text('Stap 3 van 3'), findsOneWidget);
    expect(opener.over, isEmpty);
  });

  testWidgets('plakken en testen: de sleutel wordt bewaard en de coach '
      'staat aan', (tester) async {
    clipboard = ' AQ.Ab8RNgeheimgeheim1234\n';
    await pump(tester, pasteFirst: true);

    await tester.tap(find.text('Plak sleutel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testen en bewaren'));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.apiKey(), 'AQ.Ab8RNgeheimgeheim1234');
    expect(sent.single.headers['x-goog-api-key'], 'AQ.Ab8RNgeheimgeheim1234');
    expect(sent.single.url.path, endsWith('/models'));
    expect(find.text('Je coach staat aan'), findsOneWidget);
    expect(find.text('Stel je eerste vraag'), findsOneWidget);
  });

  testWidgets('een sleutel die niet werkt, wordt niet bewaard', (tester) async {
    await pump(tester, pasteFirst: true, status: 400);

    await tester.enterText(find.byType(TextField), 'AQ.fout');
    await tester.tap(find.text('Testen en bewaren'));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.apiKey(), isNull);
    expect(find.textContaining('Deze sleutel werkt niet'), findsOneWidget);
    expect(find.text('Je coach staat aan'), findsNothing);
  });

  testWidgets('een sleutel van een andere dienst wordt geweigerd, zonder '
      'iets te versturen', (tester) async {
    await pump(tester, pasteFirst: true);

    await tester.enterText(find.byType(TextField), 'sk-ant-api03-geheim');
    await tester.tap(find.text('Testen en bewaren'));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.apiKey(), isNull);
    expect(
      find.textContaining('alleen met een sleutel van Google'),
      findsOneWidget,
    );
    expect(sent, isEmpty);
  });

  testWidgets('het scherm ziet dat er iets op het klembord staat, zonder '
      'het te lezen', (tester) async {
    clipboard = 'AQ.Ab8RNgeheimgeheim1234';
    await pump(tester, pasteFirst: true);

    expect(find.text('Er staat iets op je klembord.'), findsOneWidget);
    // Android meldt het lezen van het klembord; dat gebeurt pas na een tik.
    expect(clipboardRead, isFalse);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('en ziet het opnieuw als je terugkomt uit AI Studio', (
    tester,
  ) async {
    await pump(tester, pasteFirst: true);
    expect(find.text('Er staat iets op je klembord.'), findsNothing);

    clipboard = 'AQ.Ab8RNgeheimgeheim1234';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Er staat iets op je klembord.'), findsOneWidget);
    expect(clipboardRead, isFalse);
  });

  group('vanuit de instellingen', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fakeClipboard(tester);
      container = newContainer();
      final router = GoRouter(
        initialLocation: Routes.settingsCoach,
        routes: [
          GoRoute(
            path: Routes.settingsCoach,
            builder: (context, state) => const CoachSettingsScreen(),
          ),
          GoRoute(
            path: Routes.coachKey,
            builder: (context, state) => CoachKeyScreen(
              pasteFirst: state.uri.queryParameters['stap'] == 'plakken',
            ),
          ),
        ],
      );
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
      await tester.pumpAndSettle();
    }

    testWidgets('zonder sleutel begint Coach aanzetten bij het begin', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Coach aanzetten'));
      await tester.pumpAndSettle();

      expect(find.byType(CoachKeyScreen), findsOneWidget);
      expect(find.text('Stap 1 van 3'), findsOneWidget);
    });

    testWidgets('met een sleutel gaat een tik meteen naar plakken', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNgeheimgeheim1234');
      await pumpSettings(tester);

      await tester.tap(find.text('AQ.Ab8RN…1234'));
      await tester.pumpAndSettle();

      expect(find.text('Plak je sleutel'), findsOneWidget);
    });
  });
}
