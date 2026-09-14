import 'dart:convert';
import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/presentation/coach_screen.dart';
import 'package:fitlog/features/chat/presentation/coach_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// The coach on screen: switched off until there is a key, and showing its
/// receipts once there is one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initialiseTestLocale);

  late AppDatabase db;
  ProviderContainer? container;

  /// Everything the fake API was asked, so a test can prove what left.
  late List<String> sent;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    sent = [];
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  /// A coach whose API says [reply] to everything.
  CoachClientFactory apiSaying(Object reply, {int status = 200}) =>
      (apiKey) => AiClient(
        apiKey: apiKey,
        client: MockClient((request) async {
          sent.add(request.body);
          return http.Response(
            jsonEncode(reply),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

  Map<String, Object?> says(String text) => {
    'content': [
      {'type': 'text', 'text': text},
    ],
    'usage': {'input_tokens': 900, 'output_tokens': 30},
  };

  Future<void> pump(WidgetTester tester, Widget screen, {Object? api}) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => AppPaths(Directory.systemTemp)),
        if (api != null)
          coachClientFactoryProvider.overrideWithValue(
            api as CoachClientFactory,
          ),
      ],
    );

    await tester.pumpWidget(wrapWithContainer(container!, screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('zonder sleutel', () {
    testWidgets('is de coach uit en zegt het scherm waarom', (tester) async {
      await pump(tester, const CoachDisabledScreen());

      expect(find.text('De coach staat uit'), findsOneWidget);
      expect(find.textContaining('geen enkele verbinding'), findsOneWidget);
    });

    testWidgets('en de instellingen bieden alleen een sleutel aan', (
      tester,
    ) async {
      await pump(tester, const CoachSettingsScreen());

      expect(find.text('Nog geen sleutel'), findsOneWidget);
      expect(find.text('Sleutel testen'), findsNothing);
      expect(find.text('MODEL'), findsNothing);
    });
  });

  group('welke dienst', () {
    testWidgets('wordt geraden, en je kan het rechtzetten', (tester) async {
      // Het nieuwe sleutelformaat van Google werd eerst voor Anthropic
      // aangezien; daarom staat er nu ook een knop.
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      expect(find.text('Google Gemini'), findsOneWidget);
      expect(
        find.text('Afgeleid uit je sleutel. Klopt dat niet, tik hier.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Google Gemini'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Anthropic').last);
      await tester.pumpAndSettle();

      expect(container!.read(coachProviderProvider), CoachProvider.anthropic);
      expect(find.text('Door jou gekozen.'), findsOneWidget);
    });

    testWidgets('en het model volgt de dienst', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      expect(find.text('Gemini 2.5 Flash'), findsOneWidget);
      expect(find.text('Sonnet 5'), findsNothing);
    });
  });

  group('een sleutel invullen', () {
    testWidgets('zet de coach aan en toont hem afgeschermd', (tester) async {
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.text('Nog geen sleutel'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'sk-ant-api03-geheimgeheim-1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Bewaren'));
      await tester.pumpAndSettle();

      expect(await db.settingsDao.apiKey(), 'sk-ant-api03-geheimgeheim-1234');
      // Enough to recognise, not enough to use.
      expect(find.text('sk-ant-a…1234'), findsOneWidget);
      expect(find.text('sk-ant-api03-geheimgeheim-1234'), findsNothing);
      expect(find.text('Sleutel testen'), findsOneWidget);
    });

    testWidgets('en hem weghalen zet de coach weer uit', (tester) async {
      await db.settingsDao.setApiKey('sk-ant-api03-geheimgeheim-1234');
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.widgetWithText(TextButton, 'Verwijderen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Verwijderen'));
      await tester.pumpAndSettle();

      expect(await db.settingsDao.apiKey(), isNull);
      expect(container!.read(coachEnabledProvider), isFalse);
    });
  });

  group('een gesprek', () {
    testWidgets('begint met wat de coach is en waar je kan beginnen', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('sk-ant-test');
      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));

      expect(find.text('Vraag je coach'), findsOneWidget);
      expect(find.text(kCoachOpeners.first), findsOneWidget);
    });

    testWidgets('bewaart je vraag en het antwoord', (tester) async {
      await db.settingsDao.setApiKey('sk-ant-test');
      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying(says('Tussen 10 en 20 sets per week.')),
      );

      await tester.enterText(
        find.byType(TextField),
        'Hoeveel sets voor borst?',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.text('Hoeveel sets voor borst?'), findsOneWidget);
      expect(find.text('Tussen 10 en 20 sets per week.'), findsOneWidget);
      // Wat het kostte staat erbij: het is de sleutel van de gebruiker.
      expect(find.textContaining('900 in'), findsOneWidget);

      final threads = await db.chatDao.newestThread();
      expect(threads!.title, 'Hoeveel sets voor borst?');
      expect(await db.chatDao.messages(threads.id), hasLength(2));
    });

    testWidgets('en toont wat het over jou heeft opgezocht', (tester) async {
      await db.settingsDao.setApiKey('sk-ant-test');
      var first = true;
      await pump(
        tester,
        const CoachScreen(),
        api: (apiKey) => AiClient(
          apiKey: apiKey,
          client: MockClient((request) async {
            sent.add(request.body);
            final body = first
                ? {
                    'content': [
                      {
                        'type': 'tool_use',
                        'id': 'toolu_1',
                        'name': 'routines',
                        'input': <String, Object?>{},
                      },
                    ],
                    'usage': {'input_tokens': 10, 'output_tokens': 5},
                  }
                : says('Je hebt nog geen routines.');
            first = false;
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Welke routines heb ik?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.text('Je hebt nog geen routines.'), findsOneWidget);
      expect(find.textContaining('Bekeken: je routines'), findsOneWidget);
    });

    testWidgets('een geweigerde sleutel wijst naar de instellingen', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('sk-ant-fout');
      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying({
          'error': {'message': 'invalid x-api-key'},
        }, status: 401),
      );

      await tester.enterText(find.byType(TextField), 'Hoi');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.textContaining('wordt niet aanvaard'), findsOneWidget);
      expect(find.text('Naar instellingen'), findsOneWidget);
      // De vraag blijft staan: een mislukt antwoord mag hem niet meenemen.
      expect(find.text('Hoi'), findsOneWidget);
    });

    testWidgets('en de vraag gaat één keer de deur uit', (tester) async {
      await db.settingsDao.setApiKey('sk-ant-test');
      await pump(tester, const CoachScreen(), api: apiSaying(says('Ja.')));

      await tester.enterText(find.byType(TextField), 'Is 3x8 genoeg?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single, contains('Is 3x8 genoeg?'));
      // De sleutel zit in de header, niet in wat verstuurd wordt.
      expect(sent.single, isNot(contains('sk-ant')));
    });
  });
}
