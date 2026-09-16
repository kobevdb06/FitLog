import 'dart:convert';
import 'dart:io';

import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
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
      (apiKey, provider) => AiClient(
        apiKey: apiKey,
        provider: provider,
        client: MockClient((request) async {
          sent.add(request.body);
          return http.Response(
            jsonEncode(reply),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

  /// Google's shape, because Google is the only service the app offers.
  Map<String, Object?> says(String text) => {
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
    'usageMetadata': {'promptTokenCount': 900, 'candidatesTokenCount': 30},
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

    testWidgets('en het scherm wijst naar Google AI Studio', (tester) async {
      await pump(tester, const CoachSettingsScreen());

      expect(
        find.textContaining('Een sleutel van Google AI Studio'),
        findsOneWidget,
      );
      expect(find.textContaining('Anthropic'), findsNothing);
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
    testWidgets('is er maar een, dus er valt niets te kiezen', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      expect(container!.read(coachProviderProvider), CoachProvider.gemini);
      // Geen rij om de dienst om te zetten zolang er een is.
      expect(find.text('Door jou gekozen.'), findsNothing);
      expect(find.textContaining('Afgeleid uit je sleutel'), findsNothing);
    });

    testWidgets('en het model is er een van Google', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      expect(find.text('Gemini 2.5 Flash'), findsOneWidget);
      expect(find.text('Sonnet 5'), findsNothing);
    });

    testWidgets('een sleutel van een andere dienst wordt geweigerd', (
      tester,
    ) async {
      // Anders zou de eerste vraag pas mislukken, met een foutmelding die
      // niets uitlegt.
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.text('Nog geen sleutel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sk-ant-api03-geheim');
      await tester.tap(find.widgetWithText(FilledButton, 'Bewaren'));
      await tester.pumpAndSettle();

      expect(await db.settingsDao.apiKey(), isNull);
      expect(
        find.textContaining('alleen met een sleutel van Google'),
        findsOneWidget,
      );
    });
  });

  group('een sleutel invullen', () {
    testWidgets('zet de coach aan en toont hem afgeschermd', (tester) async {
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.text('Nog geen sleutel'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'AQ.Ab8RNgeheimgeheim1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Bewaren'));
      await tester.pumpAndSettle();

      expect(await db.settingsDao.apiKey(), 'AQ.Ab8RNgeheimgeheim1234');
      // Enough to recognise, not enough to use.
      expect(find.text('AQ.Ab8RN…1234'), findsOneWidget);
      expect(find.text('AQ.Ab8RNgeheimgeheim1234'), findsNothing);
      expect(find.text('Sleutel testen'), findsOneWidget);
    });

    testWidgets('en hem weghalen zet de coach weer uit', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNgeheimgeheim1234');
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.widgetWithText(TextButton, 'Verwijderen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Verwijderen'));
      await tester.pumpAndSettle();

      expect(await db.settingsDao.apiKey(), isNull);
      expect(container!.read(coachEnabledProvider), isFalse);
    });
  });

  group('het model kiezen', () {
    testWidgets('toont de lijst die de dienst zelf teruggeeft', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(
        tester,
        const CoachSettingsScreen(),
        api: apiSaying({
          'models': [
            {
              'name': 'models/gemini-3.5-flash-lite',
              'displayName': 'Gemini 3.5 Flash Lite',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gemini 2.5 Flash'));
      await tester.pumpAndSettle();

      // Een model van na deze versie, opgehaald met jouw sleutel.
      expect(find.text('Gemini 3.5 Flash Lite'), findsOneWidget);

      await tester.tap(find.text('Gemini 3.5 Flash Lite'));
      await tester.pumpAndSettle();

      expect(
        (await db.settingsDao.getSettings()).chatModel,
        'gemini-3.5-flash-lite',
      );
      // En het scherm toont voortaan die naam.
      expect(find.text('gemini-3.5-flash-lite'), findsWidgets);
    });

    testWidgets('en zonder verbinding valt het terug op wat de app kent', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(
        tester,
        const CoachSettingsScreen(),
        api: apiSaying({
          'error': {'message': 'kapot'},
        }, status: 500),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gemini 2.5 Flash'));
      await tester.pumpAndSettle();

      expect(find.textContaining('kon niet opgehaald worden'), findsOneWidget);
      expect(find.text('Gemini 2.5 Flash Lite'), findsOneWidget);
    });
  });

  group('de balk met het dagverbruik', () {
    testWidgets('staat in de instellingen, niet in de chat', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      expect(find.text('VERBRUIK VANDAAG'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Daglimiet: 250 vragen'), findsOneWidget);
    });

    testWidgets('telt de calls van vandaag, niet de berichten', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Vraag');
      // Eén antwoord dat twee calls kostte: de coach zocht eerst iets op.
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'user',
        content: 'Welke routines heb ik?',
      );
      await db.chatDao.addMessage(
        id: 'm-2',
        threadId: 't-1',
        role: 'assistant',
        content: 'Nog geen.',
        requests: 2,
        inputTokens: 1300,
        outputTokens: 50,
      );

      await pump(tester, const CoachSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('2 van 250'), findsOneWidget);
      expect(find.text('1 antwoord'), findsOneWidget);
      expect(find.text('1.300 tokens in, 50 uit'), findsOneWidget);
    });

    testWidgets('en zegt erbij dat het de eigen telling is', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      expect(
        find.textContaining('je echte tegoed kan niemand opvragen'),
        findsOneWidget,
      );
      // En waar de dag van Google begint.
      expect(find.textContaining('Californië'), findsOneWidget);
    });

    testWidgets('de limiet is er een die je zelf zet', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.text('Daglimiet: 250 vragen'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '40');
      await tester.tap(find.widgetWithText(FilledButton, 'Bewaren'));
      await tester.pumpAndSettle();

      expect((await db.settingsDao.getSettings()).coachDailyLimit, 40);
      expect(find.text('Daglimiet: 40 vragen'), findsOneWidget);
    });

    testWidgets('en onzin als limiet wordt niet bewaard', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());

      await tester.tap(find.text('Daglimiet: 250 vragen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nul komma nul');
      await tester.tap(find.widgetWithText(FilledButton, 'Bewaren'));
      await tester.pumpAndSettle();

      expect((await db.settingsDao.getSettings()).coachDailyLimit, isNull);
      expect(find.text('Geef een getal groter dan nul.'), findsOneWidget);
    });
  });

  group('een voorstel in de chat', () {
    testWidgets('staat als kaart met een knop, en maakt pas iets bij een tik', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Maak een oefening');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Zo zou ik hem maken.',
        proposals: encodeProposals([
          CoachProposal.ofExercise(
            const ExerciseProposal(
              name: 'Sledepush',
              primaryMuscle: 'benen',
              equipment: 'slee',
              category: 'duration',
            ),
          ),
        ]),
      );

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      expect(find.text('Voorstel: oefening'), findsOneWidget);
      expect(find.text('Sledepush'), findsOneWidget);
      expect(find.text('benen · slee'), findsOneWidget);
      // Nog niets aangemaakt.
      expect(await db.exercisesDao.countExercises(), 0);

      await tester.tap(find.text('Oefening toevoegen'));
      await tester.pumpAndSettle();

      expect(await db.exercisesDao.countExercises(), 1);
      expect(find.text('Toegevoegd'), findsOneWidget);
      expect(find.text('Oefening toevoegen'), findsNothing);
    });

    testWidgets('een routine toont haar oefeningen en sets', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-bench',
              name: 'Bench Press',
              primaryMuscle: 'borst',
              category: 'barbell',
              createdAt: 0,
            ),
          );
      await db.chatDao.createThread('t-1', 'Maak een routine');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Zo zou ik hem opbouwen.',
        proposals: encodeProposals([
          CoachProposal.ofRoutine(
            const RoutineProposal(
              name: 'Push',
              exercises: [
                ProposedRoutineExercise(
                  exerciseId: 'ex-bench',
                  name: 'Bench Press',
                  sets: 4,
                  targetReps: 8,
                ),
              ],
            ),
          ),
        ]),
      );

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      expect(find.text('Voorstel: routine'), findsOneWidget);
      expect(find.text('4× Bench Press · 8 herhalingen'), findsOneWidget);
      expect(find.text('1 oefeningen · 4 sets'), findsOneWidget);

      await tester.tap(find.text('Routine toevoegen'));
      await tester.pumpAndSettle();

      // Een Future, geen stream: een stream die hier nog openstaat laat een
      // timer achter en de test klaagt terecht.
      final routines = await db.select(db.routinesTable).get();
      expect(routines.single.name, 'Push');
      expect(find.text('Toegevoegd'), findsOneWidget);
    });
  });

  group('eerdere gesprekken', () {
    testWidgets('staan in de lijst achter het klokje', (tester) async {
      // Ze stonden er niet: het scherm las een stream waar niemand op
      // geabonneerd was, en kreeg "nog aan het laden" - dus een lege lijst -
      // terwijl de instellingen wel "1 gesprek" toonden.
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Hoeveel sets voor borst?');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'user',
        content: 'Hoeveel sets voor borst?',
      );

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Nieuw gesprek'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Hoeveel sets voor borst?'),
        findsOneWidget,
      );
    });

    testWidgets('en zonder eerdere gesprekken zegt de lijst dat', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Nog geen eerdere gesprekken.'), findsOneWidget);
    });

    testWidgets('en er een openen toont wat je toen vroeg', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Hoeveel sets voor borst?');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Tussen 10 en 20 per week.',
      );
      await db.chatDao.createThread('t-2', 'En voor rug?');

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ListTile, 'Hoeveel sets voor borst?'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tussen 10 en 20 per week.'), findsOneWidget);
    });
  });

  group('een gesprek', () {
    testWidgets('begint met wat de coach is en waar je kan beginnen', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));

      expect(find.text('Vraag je coach'), findsOneWidget);
      expect(find.text(kCoachOpeners.first), findsOneWidget);
    });

    testWidgets('bewaart je vraag en het antwoord', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
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
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      var first = true;
      await pump(
        tester,
        const CoachScreen(),
        api: (apiKey, provider) => AiClient(
          apiKey: apiKey,
          provider: provider,
          client: MockClient((request) async {
            sent.add(request.body);
            final body = first
                ? {
                    'candidates': [
                      {
                        'content': {
                          'role': 'model',
                          'parts': [
                            {
                              'functionCall': {
                                'name': 'routines',
                                'args': <String, Object?>{},
                              },
                              'thoughtSignature': 'sig-1',
                            },
                          ],
                        },
                      },
                    ],
                    'usageMetadata': {
                      'promptTokenCount': 10,
                      'candidatesTokenCount': 5,
                    },
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
      await db.settingsDao.setApiKey('AQ.Ab8RNfout');
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
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
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
