import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/calc/deload.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/links.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/chat/domain/answer_report.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/domain/coach_suggestions.dart';
import 'package:fitlog/features/chat/presentation/coach_drawer.dart';
import 'package:fitlog/features/chat/presentation/coach_memory_screen.dart';
import 'package:fitlog/features/chat/presentation/coach_screen.dart';
import 'package:fitlog/features/chat/presentation/coach_session.dart';
import 'package:fitlog/features/chat/presentation/coach_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// [thread] is the conversation the Chat tab shows, as a pick from the
  /// list would; without it the tab opens on a new one.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String? thread,
    CoachSuggester? suggester,
    Object? api,
    bool drawing = false,
    LinkOpener? opener,
    Size size = const Size(1100, 2400),
  }) async {
    tester.view.physicalSize = size;
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
        if (drawing) imageGenerationProvider.overrideWithValue(true),
        if (opener != null) linkOpenerProvider.overrideWithValue(opener),
        if (suggester != null)
          coachSuggesterProvider.overrideWithValue(suggester),
      ],
    );

    if (thread != null) {
      container!.read(coachSessionControllerProvider.notifier).show(thread);
    }
    await tester.pumpWidget(wrapWithContainer(container!, screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('zonder sleutel', () {
    testWidgets('is de coach uit en zegt het scherm waarom', (tester) async {
      await pump(tester, const CoachDisabledScreen());

      expect(find.text('De coach staat uit'), findsOneWidget);
      expect(find.textContaining('geen enkele verbinding'), findsOneWidget);
      // Alleen Google wordt nog aangeboden, en de weg erheen is de flow.
      expect(find.textContaining('Anthropic'), findsNothing);
      expect(find.textContaining('Google'), findsOneWidget);
      expect(find.text('Coach aanzetten'), findsOneWidget);
    });

    testWidgets('en het scherm wijst naar Google AI Studio', (tester) async {
      await pump(tester, const CoachSettingsScreen());

      expect(
        find.textContaining('sleutel van Google AI Studio'),
        findsOneWidget,
      );
      expect(find.textContaining('Anthropic'), findsNothing);
    });

    testWidgets('en de instellingen bieden alleen een sleutel aan', (
      tester,
    ) async {
      await pump(tester, const CoachSettingsScreen());

      expect(find.text('Coach aanzetten'), findsOneWidget);
      expect(find.text('Sleutel testen'), findsNothing);
      expect(find.text('MODEL'), findsNothing);
    });
  });

  group('wat er meegaat', () {
    testWidgets('zegt wat Google met een gratis sleutel mag, en waar dat '
        'staat', (tester) async {
      final opener = _Opener();
      await pump(tester, const CoachSettingsScreen(), opener: opener);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('om zijn producten te verbeteren'),
        findsOneWidget,
      );
      await tester.tap(find.text('Voorwaarden van Google'));
      await tester.pumpAndSettle();
      expect(opener.opened, [kGeminiTermsUrl]);
    });
  });

  group('tekenen staat uit', () {
    testWidgets('geen sectie Afbeeldingen, ook niet met een token', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
      await pump(tester, const CoachSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('AFBEELDINGEN'), findsNothing);
      expect(find.text('Hugging Face'), findsNothing);
      expect(find.text('Materiaal mee tekenen'), findsNothing);
      expect(container!.read(canDrawImagesProvider), isFalse);
      // De rest van de instellingen staat er gewoon.
      expect(find.text('MODEL'), findsOneWidget);
    });

    testWidgets('en geen knop met tekeningen op een voorstel', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
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
              startImagePrompt: 'A person crouched behind a sled',
              endImagePrompt: 'A person leaning into the sled',
            ),
          ),
        ]),
      );

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oefening toevoegen'), findsOneWidget);
      expect(find.text('Toevoegen mét tekeningen'), findsNothing);
      expect(find.textContaining('Hugging Face'), findsNothing);
    });
  });

  group('welk gesprek de tab opent', () {
    testWidgets('zonder workout een nieuw, ook met eerdere gesprekken', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Hoeveel sets voor borst?');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Tien tot twintig per week.',
      );

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      expect(find.text('Vraag je coach'), findsOneWidget);
      expect(find.text('Tien tot twintig per week.'), findsNothing);
    });

    testWidgets('tijdens een workout dat van de workout, met wat het eiland '
        'vroeg', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      await db.chatDao.createThread(
        't-w',
        'Push A · vandaag',
        workoutId: workout,
      );
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-w',
        role: 'assistant',
        content: 'Ja, set 3 op 80 kg kan.',
      );

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      expect(find.text('Ja, set 3 op 80 kg kan.'), findsOneWidget);
      expect(find.textContaining('Push A · loopt'), findsOneWidget);
      expect(find.text('Hetzelfde gesprek als in het eiland'), findsOneWidget);
    });
  });

  group('het geheugen', () {
    /// An answer with the card of a note the coach just wrote.
    Future<void> remembered(WidgetTester tester, {bool first = true}) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      final id = await db.coachNotesDao.add(
        'Linkerknie doet pijn bij diepe squats: tot parallel.',
        kind: CoachNoteKind.limit,
      );
      await db.chatDao.createThread('t-1', 'Mijn knie');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Genoteerd.',
        proposals: encodeProposals([
          CoachProposal.ofNote(
            NoteProposal(
              id: id,
              text: 'Linkerknie doet pijn bij diepe squats: tot parallel.',
              kind: 'limit',
              action: NoteAction.made,
              first: first,
            ),
          ),
        ]),
      );
      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('een notitie staat als kaartje, en de eerste zegt wat het '
        'geheugen is', (tester) async {
      await remembered(tester);

      expect(find.text('Onthouden'), findsOneWidget);
      expect(
        find.text('Linkerknie doet pijn bij diepe squats: tot parallel.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Instellingen → AI-coach → Geheugen'),
        findsOneWidget,
      );
      expect(find.text('Aanpassen'), findsOneWidget);
      expect(find.text('Vergeten'), findsOneWidget);
    });

    testWidgets('Vergeten wist ze, en het kaartje zegt dat', (tester) async {
      await remembered(tester, first: false);

      await tester.tap(find.text('Vergeten'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(await tester.runAsync(() => db.coachNotesDao.notes()), isEmpty);
      expect(find.text('Niet meer in het geheugen.'), findsOneWidget);
      expect(find.text('Aanpassen'), findsNothing);
    });

    testWidgets('Aanpassen verandert ze, ook op het kaartje', (tester) async {
      await remembered(tester, first: false);

      await tester.tap(find.text('Aanpassen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Linkerknie: geen diepe squats.',
      );
      await tester.tap(find.text('Opslaan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        (await tester.runAsync(() => db.coachNotesDao.notes()))!.single.note,
        'Linkerknie: geen diepe squats.',
      );
      expect(find.text('Linkerknie: geen diepe squats.'), findsOneWidget);
    });

    testWidgets('het scherm Geheugen: de notities, aanpassen, vergeten en '
        'uitzetten', (tester) async {
      await db.coachNotesDao.add(
        'Doel: 100 kg bankdrukken',
        kind: CoachNoteKind.goal,
      );
      await db.coachNotesDao.add('Wil korte antwoorden');
      await pump(tester, const CoachMemoryScreen());
      await tester.pumpAndSettle();

      expect(find.text('2 VAN $kCoachNoteMax NOTITIES'), findsOneWidget);
      expect(find.text('Doel: 100 kg bankdrukken'), findsOneWidget);

      await tester.tap(find.byTooltip('Vergeten').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Wil korte antwoorden'), findsNothing);
      expect(find.text('1 VAN $kCoachNoteMax NOTITIES'), findsOneWidget);

      await tester.tap(find.text('De coach onthoudt dingen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        (await tester.runAsync(db.settingsDao.getSettings))!.coachMemory,
        isFalse,
      );
      expect(
        find.textContaining('Uit. De notities blijven bewaard'),
        findsOneWidget,
      );
    });

    testWidgets('en er een toevoegen', (tester) async {
      await pump(tester, const CoachMemoryScreen());
      await tester.pumpAndSettle();
      expect(find.text('NOG GEEN NOTITIES'), findsOneWidget);

      await tester.tap(find.text('Notitie toevoegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Traint op zaterdag');
      await tester.tap(find.text('Opslaan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Traint op zaterdag'), findsOneWidget);
    });

    testWidgets('de instellingen zeggen of het aan staat, en hoeveel', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.coachNotesDao.add('Een');
      await db.coachNotesDao.add('Twee');
      await pump(tester, const CoachSettingsScreen());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Geheugen'), 200);
      expect(find.text('Aan · 2 notities'), findsOneWidget);
    });
  });

  group('een deload van de coach', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    /// The coach's card, on a 360dp phone with large text.
    Future<void> withCard(WidgetTester tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Deload?');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Neem een paar lichtere dagen.',
        proposals: encodeProposals([
          CoachProposal.ofDeload(
            DeloadProposal(
              from: today,
              days: 5,
              plan: const DeloadPlan(setsPercent: 40),
              reason: 'Zeven weken zonder pauze.',
            ),
          ),
        ]),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
        size: const Size(360, 2400),
      );
      await tester.pumpAndSettle();
    }

    Future<DeloadWeekRow?> current(WidgetTester tester) => tester
        .runAsync<DeloadWeekRow?>(() => db.deloadDao.currentAt(DateTime.now()));

    testWidgets('een kaart met Starten en Aanpassen, even hoog naast elkaar', (
      tester,
    ) async {
      await withCard(tester);

      expect(find.text('Voorstel: deload'), findsOneWidget);
      expect(find.text('Deload van 5 dagen'), findsOneWidget);
      expect(find.text('Zeven weken zonder pauze.'), findsOneWidget);
      expect(find.textContaining('Werksets −40%'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final start = find.widgetWithText(FilledButton, 'Starten');
      final adjust = find.widgetWithText(OutlinedButton, 'Aanpassen');
      expect(tester.getSize(start).height, tester.getSize(adjust).height);
      expect(tester.getCenter(start).dy, tester.getCenter(adjust).dy);
    });

    testWidgets('Starten start ze, en de kaart zegt het', (tester) async {
      await withCard(tester);

      await tester.tap(find.text('Starten'));
      await tester.pumpAndSettle();

      final deload = (await current(tester))!;
      expect(deload.source, 'coach');
      expect(deload.days, 5);
      expect(deload.plan.setsPercent, 40);
      expect(find.text('Ingepland'), findsOneWidget);
      expect(find.text('Starten'), findsNothing);
      expect(find.text('Bekijken'), findsNothing);
    });

    testWidgets('Aanpassen opent het startblad met de cijfers van de coach', (
      tester,
    ) async {
      await withCard(tester);

      await tester.tap(find.text('Aanpassen'));
      await tester.pumpAndSettle();
      expect(find.text('5 dagen'), findsOneWidget);
      await tester.tap(find.byTooltip('Een dag langer'));
      await tester.pumpAndSettle();
      final start = find.text('Deload starten').last;
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();

      final deload = (await current(tester))!;
      expect(deload.days, 6);
      expect(deload.source, 'coach');
      expect(deload.plan.setsPercent, 40);
      expect(find.text('Ingepland'), findsOneWidget);
      expect(find.text('Deload van 6 dagen'), findsOneWidget);
    });
  });

  group('wie de tekeningen maakt', () {
    /// Het tekenen staat los van de coach, maar wordt op hetzelfde scherm
    /// ingesteld, dus er moet een sleutel zijn om er iets van te zien. En het
    /// staat uit voor de app; hier aan, om de logica te bewaken die blijft.
    Future<void> openSettings(WidgetTester tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen(), drawing: true);
      await tester.pumpAndSettle();
    }

    testWidgets('staat standaard op Hugging Face, met een token en meer '
        'niet', (tester) async {
      await openSettings(tester);

      expect(find.text('Hugging Face'), findsOneWidget);
      // Geen account-ID: die vraagt alleen de andere dienst.
      expect(find.text('Nog geen account-ID'), findsNothing);
      expect(find.text('Nog geen token'), findsOneWidget);
    });

    testWidgets('en met Cloudflare komt het account-ID erbij', (tester) async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageProvider: Value('cloudflare')),
      );
      await openSettings(tester);

      expect(find.text('Cloudflare'), findsOneWidget);
      expect(find.text('Nog geen account-ID'), findsOneWidget);
      expect(find.text('Nog geen token'), findsOneWidget);
    });

    testWidgets('en een schakelaar bepaalt of het materiaal mee mag', (
      tester,
    ) async {
      await openSettings(tester);

      final tile = find.widgetWithText(SwitchListTile, 'Materiaal mee tekenen');
      expect(tile, findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(container!.read(coachImageEquipmentProvider), isFalse);
      expect(find.textContaining('lege handen'), findsOneWidget);
    });

    testWidgets('je kiest eerst, en de vraag komt daarna', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Hugging Face'));
      await tester.pumpAndSettle();
      expect(find.text('Wie tekent?'), findsOneWidget);

      await tester.tap(find.text('Cloudflare').last);
      await tester.pumpAndSettle();

      expect(
        container!.read(coachDrawingServiceProvider),
        DrawingService.cloudflare,
      );
      // En pas nu wordt er naar een account gevraagd.
      expect(find.text('Nog geen account-ID'), findsOneWidget);
    });

    testWidgets('en overstappen laat geen sleutel van de vorige staan', (
      tester,
    ) async {
      // Een token van de een is bij de ander niets waard, en blijven staan
      // zou de app laten tekenen met een sleutel die daar geweigerd wordt.
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
      await openSettings(tester);

      await tester.tap(find.text('Hugging Face'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cloudflare').last);
      await tester.pumpAndSettle();

      expect(container!.read(coachImageKeyProvider), isNull);
      expect(container!.read(canDrawImagesProvider), isFalse);
    });
  });

  group('wat de coach over je weet', () {
    Future<void> openSettings(WidgetTester tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachSettingsScreen());
      await tester.pumpAndSettle();
    }

    final tile = find.widgetWithText(SwitchListTile, 'Je profiel delen');

    testWidgets('staat uit, en zegt waar je ze invult', (tester) async {
      await openSettings(tester);

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(find.textContaining('Nog niets ingevuld'), findsOneWidget);
    });

    testWidgets('toont wat er mee zou gaan, en aan gaat het mee', (
      tester,
    ) async {
      await tester.runAsync(
        () => db.settingsDao.upsertProfile(
          sex: const Value('female'),
          heightCm: const Value(168),
        ),
      );
      await openSettings(tester);
      expect(
        find.textContaining('Zou meegaan: vrouw, 168 cm.'),
        findsOneWidget,
      );

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        (await tester.runAsync(db.settingsDao.getSettings))!.coachSeesProfile,
        isTrue,
      );
      expect(
        find.text('Gaat mee met elke vraag: vrouw, 168 cm.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('de instellingen wijzen ook naar de privacyverklaring', (
    tester,
  ) async {
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    final opener = _Opener();
    await pump(
      tester,
      const CoachSettingsScreen(),
      opener: opener,
      size: const Size(360, 2400),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacyverklaring'));
    await tester.pumpAndSettle();

    expect(opener.opened, [kPrivacyUrl]);
    expect(tester.takeException(), isNull);
  });

  group('gezondheidsgegevens', () {
    final tile = find.widgetWithText(
      SwitchListTile,
      'Gezondheidsgegevens delen met de coach',
    );

    Future<bool> shared(WidgetTester tester) async =>
        (await tester.runAsync(db.settingsDao.getSettings))!.coachSeesHealth;

    testWidgets('staan uit, en aanzetten zegt eerst waar ze heen gaan', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      // Phone width, where the long title has to wrap.
      await pump(
        tester,
        const CoachSettingsScreen(),
        size: const Size(360, 2400),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(
        find.textContaining('Uit. Wat uit Health Connect komt'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Delen met de coach?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('naar Google'),
        ),
        findsOneWidget,
      );

      // Annuleren laat het uit.
      await tester.tap(find.text('Annuleren'));
      await tester.pumpAndSettle();
      expect(await shared(tester), isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delen'));
      await tester.pumpAndSettle();
      expect(await shared(tester), isTrue);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      // Uitzetten vraagt niets.
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Delen met de coach?'), findsNothing);
      expect(await shared(tester), isFalse);
    });
  });

  group('waar je traint', () {
    testWidgets('staat op Profiel; hier alleen of de coach het ziet', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(
          coachGym: Value('Basic-Fit Gent, geen smith machine'),
        ),
      );
      await pump(tester, const CoachSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Waar je traint'), findsNothing);
      expect(
        find.textContaining('Zou meegaan: waar je traint.'),
        findsOneWidget,
      );
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
  });

  group('op een smal toestel met grote letters', () {
    testWidgets('passen de knoppen bij de sleutel op het scherm', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNgeheimgeheim1234');
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(
        tester,
        const CoachSettingsScreen(),
        size: const Size(360, 2400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleutel testen'), findsOneWidget);
      expect(find.text('Verwijderen'), findsOneWidget);
      // An overflow anywhere fails the test on its own.
      expect(tester.takeException(), isNull);
    });
  });

  group('een sleutel invullen', () {
    testWidgets('een bewaarde sleutel staat er afgeschermd', (tester) async {
      // Invullen gebeurt in Coach aanzetten (coach_key_test).
      await db.settingsDao.setApiKey('AQ.Ab8RNgeheimgeheim1234');
      await pump(tester, const CoachSettingsScreen());
      await tester.pumpAndSettle();

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

    testWidgets('zet de lichte Gemini 3-modellen onder Aanbevolen', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(
        tester,
        const CoachSettingsScreen(),
        api: apiSaying({
          'models': [
            for (final wire in [
              'gemini-3.5-flash-lite',
              'gemini-3.1-flash-lite',
              'gemini-3-pro',
              'gemini-2.5-flash',
            ])
              {
                'name': 'models/$wire',
                'displayName': wire,
                'supportedGenerationMethods': ['generateContent'],
              },
          ],
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gemini 2.5 Flash'));
      await tester.pumpAndSettle();

      expect(find.text('AANBEVOLEN'), findsOneWidget);
      expect(find.text('ALLES WAT JE SLEUTEL KAN'), findsOneWidget);

      // De twee lichte 3-modellen staan boven de rest.
      final aanbevolen = tester.getRect(find.text('AANBEVOLEN'));
      final rest = tester.getRect(find.text('ALLES WAT JE SLEUTEL KAN'));
      for (final wire in ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite']) {
        final row = tester.getRect(find.text(wire).first);
        expect(row.top, greaterThan(aanbevolen.top));
        expect(row.top, lessThan(rest.top));
      }
      expect(
        tester.getRect(find.text('gemini-3-pro').first).top,
        greaterThan(rest.top),
      );
    });

    testWidgets('en zonder zulke modellen is er geen kopje', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(
        tester,
        const CoachSettingsScreen(),
        api: apiSaying({
          'models': [
            {
              'name': 'models/gemini-2.5-flash',
              'displayName': 'Gemini 2.5 Flash',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gemini 2.5 Flash'));
      await tester.pumpAndSettle();

      expect(find.text('AANBEVOLEN'), findsNothing);
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

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
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

    testWidgets("Toevoegen met foto's: de oefening, en de twee prompts", (
      tester,
    ) async {
      const start =
          'Een realistische foto van een persoon in sportkleding, van opzij, '
          'gehurkt achter een geladen slee.';
      const end =
          'Dezelfde persoon, op dezelfde plek en vanuit dezelfde hoek, nu aan '
          'het eind van de beweging: benen gestrekt, de slee een stap verder.';
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
              startImagePrompt: start,
              endImagePrompt: end,
            ),
          ),
        ]),
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      final opener = _Opener();

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
        opener: opener,
      );
      await tester.pumpAndSettle();

      expect(find.text("Toevoegen met foto's"), findsOneWidget);
      await tester.tap(find.text("Toevoegen met foto's"));
      await tester.pumpAndSettle();

      expect(await db.exercisesDao.countExercises(), 1);
      expect(find.text("Foto's maken met Gemini"), findsOneWidget);
      expect(find.text(start), findsOneWidget);
      expect(find.text(end), findsOneWidget);

      await tester.tap(find.text('Kopiëren').first);
      await tester.pumpAndSettle();
      expect(copied, start);
      expect(find.text('Gekopieerd'), findsOneWidget);

      await tester.tap(find.text('Open Gemini'));
      await tester.pumpAndSettle();
      expect(opener.opened, [kGeminiUrl]);

      // Dicht, en later terug te vinden op de kaart.
      Navigator.of(tester.element(find.text(start))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Toegevoegd'), findsOneWidget);
      await tester.tap(find.text("Prompts voor de foto's"));
      await tester.pumpAndSettle();
      expect(find.text(end), findsOneWidget);
    });

    testWidgets('een wijziging aan een eigen oefening: wat, en Toepassen', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-own',
              name: 'Sledepush',
              primaryMuscle: 'benen',
              category: 'duration',
              isCustom: const Value(true),
              createdAt: 0,
            ),
          );
      await db.chatDao.createThread('t-1', 'Pas mijn oefening aan');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Zo zou ik hem aanpassen.',
        proposals: encodeProposals([
          CoachProposal.ofExerciseChange(
            const ExerciseChangeProposal(
              exerciseId: 'ex-own',
              exerciseName: 'Sledepush',
              equipment: 'slee',
              instructions: 'Duw laag.',
              reason: 'Met het materiaal erbij.',
            ),
          ),
        ]),
      );

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voorstel: oefening aanpassen'), findsOneWidget);
      expect(find.text('Sledepush'), findsOneWidget);
      expect(find.text('Met het materiaal erbij.'), findsOneWidget);
      expect(find.text('Materiaal: slee'), findsOneWidget);
      expect(find.text('Uitleg: Duw laag.'), findsOneWidget);
      // Nog niets veranderd.
      expect((await db.exercisesDao.getById('ex-own'))!.equipment, isNull);

      await tester.tap(find.text('Toepassen'));
      await tester.pumpAndSettle();

      final row = (await db.exercisesDao.getById('ex-own'))!;
      expect(row.equipment, 'slee');
      expect(row.instructions, 'Duw laag.');
      expect(find.text('Toegepast'), findsOneWidget);
      expect(find.text('Toepassen'), findsNothing);
    });

    testWidgets('past op een smalle telefoon met grote letters', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db
          .into(db.exercisesTable)
          .insert(
            ExercisesTableCompanion.insert(
              id: 'ex-own',
              name: 'Sledepush',
              primaryMuscle: 'benen',
              category: 'duration',
              isCustom: const Value(true),
              createdAt: 0,
            ),
          );
      await db.chatDao.createThread('t-1', 'Oefeningen');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Twee voorstellen.',
        proposals: encodeProposals([
          CoachProposal.ofExercise(
            const ExerciseProposal(
              name: 'Single-Arm Landmine Press (half kneeling, neutral grip)',
              primaryMuscle: 'schouders',
              secondaryMuscles: ['triceps', 'buik'],
              equipment: 'landmine',
              startImagePrompt:
                  'Een realistische foto van een persoon in sportkleding die '
                  'halfgeknield naast een landmine zit, de stang op '
                  'schouderhoogte in één hand, van opzij gezien.',
              endImagePrompt:
                  'Dezelfde persoon, op dezelfde plek en vanuit dezelfde hoek, '
                  'nu aan het eind van de beweging: de arm gestrekt schuin '
                  'omhoog.',
            ),
          ),
          CoachProposal.ofExerciseChange(
            const ExerciseChangeProposal(
              exerciseId: 'ex-own',
              exerciseName: 'Sledepush',
              name: 'Sledepush met lage handen',
              primaryMuscle: 'quadriceps',
              secondaryMuscles: ['bilspieren', 'kuiten'],
              equipment: 'slee',
              instructions:
                  'Duw laag, met gestrekte armen, en houd je rug recht.',
              reason: 'Een duidelijkere naam en uitleg.',
            ),
          ),
        ]),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
        opener: _Opener(),
        size: const Size(360, 2600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text("Toevoegen met foto's"));
      await tester.pumpAndSettle();
      expect(find.text("Foto's maken met Gemini"), findsOneWidget);
      // An overflow anywhere fails the test on its own.
      expect(tester.takeException(), isNull);
    });

    testWidgets("zonder prompts geen knop met foto's", (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Maak een oefening');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Zo zou ik hem maken.',
        proposals: encodeProposals([
          CoachProposal.ofExercise(
            const ExerciseProposal(name: 'Sledepush', primaryMuscle: 'benen'),
          ),
        ]),
      );

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oefening toevoegen'), findsOneWidget);
      expect(find.text("Toevoegen met foto's"), findsNothing);
    });

    testWidgets('met een token staat er een tweede knop, met wat het kost', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
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
              startImagePrompt: 'A person crouched behind a sled',
              endImagePrompt: 'A person leaning into the sled',
            ),
          ),
        ]),
      );

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
        drawing: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Oefening toevoegen'), findsOneWidget);
      expect(find.text('Toevoegen mét tekeningen'), findsOneWidget);
      expect(find.textContaining('Kost tegoed'), findsOneWidget);
    });

    testWidgets('zonder token is die tweede knop er niet', (tester) async {
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
              startImagePrompt: 'A person crouched behind a sled',
              endImagePrompt: 'A person leaning into the sled',
            ),
          ),
        ]),
      );

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oefening toevoegen'), findsOneWidget);
      expect(find.text('Toevoegen mét tekeningen'), findsNothing);
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

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voorstel: routine'), findsOneWidget);
      expect(find.text('4× Bench Press · 8 herhalingen'), findsOneWidget);
      expect(find.text('1 oefening · 4 sets'), findsOneWidget);

      await tester.tap(find.text('Routine toevoegen'));
      await tester.pumpAndSettle();

      // Een Future, geen stream: een stream die hier nog openstaat laat een
      // timer achter en de test klaagt terecht.
      final routines = await db.select(db.routinesTable).get();
      expect(routines.single.name, 'Push');
      expect(find.text('Toegevoegd'), findsOneWidget);
    });

    testWidgets('wat de coach zelf aanpaste, zegt wat en waarom, zonder '
        'knop om toe te voegen', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Zwaarder graag');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'assistant',
        content: 'Aangepast.',
        proposals: encodeProposals([
          CoachProposal.ofCoachRoutine(
            const RoutineProposal(
              name: 'Chest day',
              exercises: [
                ProposedRoutineExercise(
                  exerciseId: 'ex-bench',
                  name: 'Bench Press',
                  sets: 4,
                  targetReps: 5,
                ),
              ],
            ),
            appliedId: 'r-1',
            made: false,
            change: 'Zwaarder en minder herhalingen: je bench staat stil.',
          ),
        ]),
      );

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aangepast door de coach'), findsOneWidget);
      expect(
        find.text('Zwaarder en minder herhalingen: je bench staat stil.'),
        findsOneWidget,
      );
      expect(find.text('4× Bench Press · 5 herhalingen'), findsOneWidget);
      expect(find.text('In de map Coach'), findsOneWidget);
      expect(find.text('Bekijken'), findsOneWidget);
      expect(find.text('Routine toevoegen'), findsNothing);
    });
  });

  group('eerdere gesprekken', () {
    /// A conversation last added to [daysAgo] days ago.
    Future<void> thread(
      String id,
      String title, {
      int daysAgo = 0,
      String? workoutId,
      String? answer,
    }) async {
      await db.chatDao.createThread(id, title, workoutId: workoutId);
      if (answer != null) {
        await db.chatDao.addMessage(
          id: 'm-$id',
          threadId: id,
          role: 'assistant',
          content: answer,
        );
      }
      final at = DateTime.now().subtract(Duration(days: daysAgo));
      await db.customStatement(
        'UPDATE chat_threads SET updated_at = ? WHERE id = ?',
        [at.millisecondsSinceEpoch, id],
      );
    }

    Future<void> openPanel(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Gesprekken'));
      await tester.pumpAndSettle();
    }

    testWidgets('staan in het paneel, per dag', (tester) async {
      // Ze stonden er ooit niet: het scherm las een stream waar niemand op
      // geabonneerd was, en kreeg "nog aan het laden" - een lege lijst.
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await thread('t-1', 'Wat train ik vandaag?');
      await thread('t-2', 'Deloadweek plannen', daysAgo: 1);
      await thread('t-3', 'Routine voor thuis', daysAgo: 3);
      await thread('t-4', 'Hoe log ik een dropset?', daysAgo: 20);

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();
      await openPanel(tester);

      expect(find.text('Nieuw gesprek'), findsOneWidget);
      for (final (heading, title) in [
        ('Vandaag', 'Wat train ik vandaag?'),
        ('Gisteren', 'Deloadweek plannen'),
        ('Afgelopen week', 'Routine voor thuis'),
        ('Eerder', 'Hoe log ik een dropset?'),
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
        expect(
          tester.getTopLeft(find.text(heading)).dy,
          lessThan(tester.getTopLeft(find.text(title)).dy),
          reason: '$title onder $heading',
        );
      }
    });

    testWidgets('en zonder eerdere gesprekken zegt het paneel dat', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await openPanel(tester);

      expect(
        find.text('Nog geen gesprekken. Wat je vraagt, komt hier.'),
        findsOneWidget,
      );
    });

    testWidgets('en er een openen toont wat je toen vroeg', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await thread(
        't-1',
        'Hoeveel sets voor borst?',
        answer: 'Tussen 10 en 20 per week.',
      );
      await thread('t-2', 'En voor rug?');

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();
      await openPanel(tester);
      await tester.tap(
        find.widgetWithText(ListTile, 'Hoeveel sets voor borst?'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tussen 10 en 20 per week.'), findsOneWidget);
      expect(find.text('Nieuw gesprek'), findsNothing);
    });

    testWidgets('zoeken vindt ook wat er in een gesprek staat', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await thread(
        't-1',
        'Hoeveel sets voor borst?',
        answer: 'Tussen 10 en 20 per week.',
      );
      await thread('t-2', 'En voor rug?');

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();
      await openPanel(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Zoek in gesprekken'),
        'per week',
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ListTile, 'Hoeveel sets voor borst?'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ListTile, 'En voor rug?'), findsNothing);
    });

    testWidgets('hernoemen en verwijderen, met de knop Meer', (tester) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await thread('t-1', 'Hoeveel sets voor borst?', answer: 'Tien.');

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();
      await openPanel(tester);

      await tester.tap(find.byTooltip('Meer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hernoemen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Borst');
      await tester.tap(find.text('Opslaan'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Borst'), findsOneWidget);

      await tester.tap(find.byTooltip('Meer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwijderen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwijderen').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Borst'), findsNothing);
      // The one on screen is gone: the tab is on a new one.
      await tester.tapAt(const Offset(1000, 400));
      // The panel's 250 ms on its way out.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Vraag je coach'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.chatDao.threadExists('t-1')),
        isFalse,
      );
    });

    testWidgets('het gesprek van de lopende workout staat bovenaan, onder Nu', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      final workout = await db.workoutsDao.startWorkout(
        name: 'Push A',
        defaultRestSeconds: 90,
      );
      await thread('t-1', 'Wat train ik vandaag?');
      await thread('t-w', 'Push A · vandaag', workoutId: workout);

      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();
      await openPanel(tester);

      expect(find.text('Nu'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Push A · vandaag')).dy,
        lessThan(tester.getTopLeft(find.text('Vandaag')).dy),
      );
    });

    testWidgets('Nieuw gesprek in de balk maakt het scherm leeg', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await thread('t-1', 'Hoeveel sets?', answer: 'Tien.');

      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tien.'), findsOneWidget);

      await tester.tap(find.byTooltip('Nieuw gesprek'));
      await tester.pumpAndSettle();

      expect(find.text('Tien.'), findsNothing);
      expect(find.text('Vraag je coach'), findsOneWidget);
    });

    testWidgets('het paneel past op een smalle gsm met grote letters', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await thread('t-1', 'Een vraag met een lange naam die niet past');
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying(says('ok')),
        size: const Size(360, 800),
      );
      await tester.pumpAndSettle();
      await openPanel(tester);

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.text('Nieuw gesprek')).dx,
        lessThan(360),
      );
    });

    test('een dag telt op de kalender, ook als de klok verspringt', () {
      // 28 March 2027: the clocks go forward in Belgium.
      final monday = DateTime(2027, 3, 29, 8);
      expect(
        ThreadGroup.of(DateTime(2027, 3, 28, 23), monday),
        ThreadGroup.yesterday,
      );
      expect(
        ThreadGroup.of(DateTime(2027, 3, 27, 9), monday),
        ThreadGroup.week,
      );
      expect(
        ThreadGroup.of(DateTime(2027, 3, 22, 9), monday),
        ThreadGroup.earlier,
      );
      expect(
        ThreadGroup.of(DateTime(2027, 3, 29, 0, 5), monday),
        ThreadGroup.today,
      );
    });
  });

  group('een gesprek', () {
    testWidgets('begint met wat de coach is, en vragen voor jou', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();

      expect(find.text('Vraag je coach'), findsOneWidget);
      expect(find.text('Voor jou, nu'), findsOneWidget);
      // An empty logbook: how to begin.
      expect(
        find.text('Maak een schema voor drie dagen per week.'),
        findsOneWidget,
      );
      expect(find.text('Om te beginnen'), findsWidgets);
    });

    testWidgets('een workout die start, krijgt vragen over de workout', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      await pump(tester, const CoachScreen(), api: apiSaying(says('ok')));
      await tester.pumpAndSettle();
      expect(find.text('Om te beginnen'), findsWidgets);

      await tester.runAsync(
        () => db.workoutsDao.startWorkout(
          name: 'Losse workout',
          defaultRestSeconds: 90,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Losse workout · loopt'), findsOneWidget);
      expect(find.text('Nu bezig: Losse workout'), findsWidgets);
    });

    testWidgets('Andere vragen toont de volgende, en een tik stelt de vraag', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying(says('Rustig opbouwen.')),
        suggester: _Suggests([
          for (var i = 1; i <= 6; i++)
            CoachSuggestion(
              question: 'Vraag $i?',
              why: 'Waarom $i',
              reason: SuggestionReason.general,
            ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vraag 4?'), findsOneWidget);
      expect(find.text('Vraag 5?'), findsNothing);
      expect(find.text('Waarom 1'), findsOneWidget);

      await tester.tap(find.text('Andere vragen'));
      await tester.pumpAndSettle();
      expect(find.text('Vraag 5?'), findsOneWidget);
      expect(find.text('Vraag 6?'), findsOneWidget);
      expect(find.text('Vraag 1?'), findsNothing);

      await tester.tap(find.text('Vraag 5?'));
      await tester.pumpAndSettle();
      expect(sent.single, contains('Vraag 5?'));
      expect(find.text('Rustig opbouwen.'), findsOneWidget);
    });

    testWidgets('de vragen passen op een smalle gsm met grote letters', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying(says('ok')),
        size: const Size(360, 1400),
        suggester: const _Suggests([
          CoachSuggestion(
            question:
                'Hoe kom ik voorbij mijn stilstand op Incline Dumbbell '
                'Bench Press?',
            why: 'Staat 12 weken stil',
            reason: SuggestionReason.stalled,
          ),
          CoachSuggestion(
            question: 'Mag ik vandaag quadriceps trainen?',
            why: 'Quadriceps nog 14 u herstel',
            reason: SuggestionReason.recovery,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Staat 12 weken stil'), findsOneWidget);
    });

    testWidgets('het antwoord groeit terwijl het geschreven wordt', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      final pieces = StreamController<List<int>>();
      await pump(
        tester,
        const CoachScreen(),
        api: (String apiKey, CoachProvider provider) => AiClient(
          apiKey: apiKey,
          provider: provider,
          client: MockClient.streaming(
            (request, _) async => http.StreamedResponse(
              pieces.stream,
              200,
              headers: {'content-type': 'text/event-stream'},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hoeveel sets?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      expect(find.text('De coach denkt na…'), findsOneWidget);

      pieces.add(utf8.encode('data: ${jsonEncode(says('Tussen tien '))}\n\n'));
      await tester.pumpAndSettle();

      // Al te lezen, en nog niet bewaard.
      expect(find.text('Tussen tien '), findsOneWidget);
      expect(find.text('De coach denkt na…'), findsNothing);
      expect(await db.chatDao.newestThread(), isNotNull);
      final thread = (await db.chatDao.newestThread())!;
      expect(await db.chatDao.messages(thread.id), hasLength(1));

      pieces.add(
        utf8.encode('data: ${jsonEncode(says('en twintig sets.'))}\n\n'),
      );
      await pieces.close();
      await tester.pumpAndSettle();

      // Eén keer: het bewaarde antwoord neemt de plaats in van het
      // geschreven, zonder dat het er twee keer staat.
      expect(find.text('Tussen tien en twintig sets.'), findsOneWidget);
      expect(await db.chatDao.messages(thread.id), hasLength(2));
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

    testWidgets('een nieuw gesprek toont het laatste antwoord niet meer', (
      tester,
    ) async {
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
      expect(find.text('Tussen 10 en 20 sets per week.'), findsOneWidget);

      await tester.tap(find.byTooltip('Nieuw gesprek'));
      await tester.pumpAndSettle();

      // The answer was held on screen until it was stored, and an empty
      // conversation never stores it: it stayed under nothing.
      expect(find.text('Tussen 10 en 20 sets per week.'), findsNothing);
      expect(find.text('Vraag je coach'), findsOneWidget);
    });

    testWidgets('versturen houdt het toetsenbord open, ernaast tikken niet', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying(says('Tussen 10 en 20 sets per week.')),
      );
      // The question field; the messages are selectable text of their own.
      bool typing() => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byType(TextField),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;

      await tester.enterText(
        find.byType(TextField),
        'Hoeveel sets voor borst?',
      );
      // A frame, as on the phone: the field only knows it has the focus
      // once it has been drawn with it.
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      // The next question follows the answer, as in any chat.
      expect(find.text('Tussen 10 en 20 sets per week.'), findsOneWidget);
      expect(typing(), isTrue);

      await tester.tap(find.byType(AppBar));
      await tester.pumpAndSettle();
      expect(typing(), isFalse);
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

    testWidgets('een opgebruikte daglimiet zegt wanneer het weer kan', (
      tester,
    ) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNtest');
      await pump(
        tester,
        const CoachScreen(),
        api: apiSaying({
          'error': {
            'code': 429,
            'details': [
              {
                '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                'violations': [
                  {'quotaId': 'GenerateRequestsPerDayPerProjectPerModel'},
                ],
              },
            ],
          },
        }, status: 429),
      );

      await tester.enterText(find.byType(TextField), 'Hoi');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Je gratis daglimiet bij Google is op. Vanaf '),
        findsOneWidget,
      );
      expect(find.textContaining('kan het weer.'), findsOneWidget);
      // Geen kapotte sleutel: niets te plakken.
      expect(find.text('Sleutel opnieuw plakken'), findsNothing);
    });

    testWidgets('een geweigerde sleutel wijst naar plakken', (tester) async {
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
      expect(find.text('Sleutel opnieuw plakken'), findsOneWidget);
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

  group('een antwoord melden', () {
    Future<void> conversation(WidgetTester tester, {LinkOpener? opener}) async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      await db.chatDao.createThread('t-1', 'Pijn');
      await db.chatDao.addMessage(
        id: 'm-1',
        threadId: 't-1',
        role: 'user',
        content: 'Mag ik squatten met pijn in mijn knie?',
      );
      await db.chatDao.addMessage(
        id: 'm-2',
        threadId: 't-1',
        role: 'assistant',
        content: 'Train gewoon door de pijn heen.',
        inputTokens: 900,
        outputTokens: 30,
      );
      // Phone width: the button sits next to the token count.
      await pump(
        tester,
        const CoachScreen(),
        thread: 't-1',
        api: apiSaying(says('ok')),
        opener: opener,
        size: const Size(360, 800),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('kan onder het antwoord van de coach, niet onder je vraag', (
      tester,
    ) async {
      await conversation(tester);

      expect(find.text('Melden'), findsOneWidget);
      expect(find.byTooltip('Meld dit antwoord'), findsOneWidget);
      expect(find.text('900 in · 30 uit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vraagt eerst waarom, en stelt dan een e-mail op met alles '
        'erin', (tester) async {
      final opener = _Opener();
      await conversation(tester, opener: opener);

      await tester.tap(find.text('Melden'));
      await tester.pumpAndSettle();
      expect(find.text('Dit antwoord melden'), findsOneWidget);
      expect(find.textContaining(kReportAddress), findsOneWidget);

      final compose = find.widgetWithText(FilledButton, 'E-mail opstellen');
      expect(tester.widget<FilledButton>(compose).onPressed, isNull);

      await tester.tap(find.text('Gevaarlijk of schadelijk advies'));
      await tester.enterText(find.byType(TextField).last, 'Mijn knie.');
      await tester.pumpAndSettle();
      await tester.ensureVisible(compose);
      await tester.tap(compose);
      await tester.pumpAndSettle();

      final mail = Uri.parse(opener.opened.single);
      expect(mail.scheme, 'mailto');
      expect(mail.path, kReportAddress);
      final body = mail.queryParameters['body']!;
      expect(body, contains('Reden: Gevaarlijk of schadelijk advies'));
      expect(body, contains('Toelichting: Mijn knie.'));
      expect(body, contains('Mag ik squatten met pijn in mijn knie?'));
      expect(body, contains('Train gewoon door de pijn heen.'));
      expect(find.text('Dit antwoord melden'), findsNothing);
    });

    testWidgets('zonder mail-app staat het op het klembord, en zegt hij dat', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      await conversation(tester, opener: _Opener(works: false));

      await tester.tap(find.text('Melden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Klopt niet'));
      await tester.pumpAndSettle();
      final compose = find.widgetWithText(FilledButton, 'E-mail opstellen');
      await tester.ensureVisible(compose);
      await tester.tap(compose);
      await tester.pumpAndSettle();

      expect(copied, contains('Reden: Klopt niet'));
      expect(copied, contains('Train gewoon door de pijn heen.'));
      expect(find.textContaining('klembord'), findsOneWidget);
    });
  });
}

/// Android's way to another app, as far as these tests go: it remembers.
class _Opener implements LinkOpener {
  _Opener({this.works = true});

  /// False for a phone with nothing that opens the address.
  final bool works;
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return works;
  }

  @override
  Future<bool> openOver(String url) async {
    opened.add(url);
    return true;
  }
}

/// Questions that are always these.
class _Suggests implements CoachSuggester {
  const _Suggests(this.questions);

  final List<CoachSuggestion> questions;

  @override
  Future<List<CoachSuggestion>> suggest() async => questions;
}
