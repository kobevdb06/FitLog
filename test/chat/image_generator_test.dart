import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/db/models.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import '../widget/helpers.dart';

/// Drawing an illustration for an exercise.
///
/// The rule this is built around: no token, no picture - ever. And with a
/// token, only where an exercise is being made, because every drawing spends
/// someone's credit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory home;
  late AppPaths paths;
  ProviderContainer? container;

  /// Every request the fake service was sent.
  late List<http.Request> sent;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    home = await Directory.systemTemp.createTemp('fitlog_draw');
    paths = AppPaths(home);
    sent = [];
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
    if (await home.exists()) await home.delete(recursive: true);
  });

  /// A small but real JPEG, as the service would return it.
  String drawnImage() =>
      base64Encode(img.encodeJpg(img.Image(width: 64, height: 64)));

  ProviderContainer containerThatDraws({
    int status = 200,
    Object? body,
    bool cloudflare = false,
  }) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWith((ref) => paths),
      imageGeneratorFactoryProvider.overrideWithValue(
        (apiKey, {provider = DrawingService.huggingFace, accountId}) =>
            ImageGenerator(
              apiKey: apiKey,
              provider: provider,
              accountId: accountId,
              client: MockClient((request) async {
                sent.add(request);
                return http.Response(
                  jsonEncode(
                    body ??
                        (cloudflare
                            ? {
                                'success': true,
                                'result': {'image': drawnImage()},
                              }
                            : {
                                'data': [
                                  {'b64_json': drawnImage()},
                                ],
                              }),
                  ),
                  status,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
      ),
    ],
  );

  group('zonder token', () {
    test('wordt er nooit iets getekend', () async {
      container = containerThatDraws();

      expect(container!.read(canDrawImagesProvider), isFalse);

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true);

      expect(file, isNull);
      // En er is niets verstuurd.
      expect(sent, isEmpty);
    });
  });

  group('met token', () {
    setUp(() async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
    });

    test('gaat er één verzoek uit, naar één adres', () async {
      container = containerThatDraws();

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true, equipment: 'slee');

      expect(file, isNotNull);
      expect(sent, hasLength(1));
      expect(sent.single.url.toString(), ImageGenerator.endpoint);
      expect(sent.single.headers['authorization'], 'Bearer hf_test');
      // Staand, in de verhouding van het fotovak: anders wordt er een
      // vierkant getekend waar de kop of de voeten afgesneden worden.
      expect(sent.single.body, contains('768x1024'));
      // De sleutel staat in de header, niet in wat verstuurd wordt.
      expect(sent.single.body, isNot(contains('hf_test')));
    });

    test('en de tekening staat bij de andere foto\'s', () async {
      container = containerThatDraws();

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true);

      expect(await PhotoStore(paths).exists(file!), isTrue);
    });

    test('een lange beschrijving wordt teruggebracht tot één gedachte', () {
      // Gemeten, niet bedacht: hetzelfde model tekende iets bruikbaars van
      // één zin en iets onbruikbaars van een opsomming.
      final prompt = ImageGenerator.stylise(
        'A person seated at a chest-supported row machine, torso upright '
        'against the pad, both arms pulled back with the handles at the ribs, '
        'shoulder blades squeezed together, seen from a high three-quarter '
        'angle behind the shoulder',
      );

      final own = prompt.substring(
        0,
        prompt.length - ImageGenerator.style.length,
      );
      expect(own.length, lessThanOrEqualTo(ImageGenerator.maxPromptLength + 1));
      // Vooraan staat wat er getekend moet worden, en er staat geen half
      // woord op het einde.
      expect(own, startsWith('A person seated at a chest-supported row'));
      expect(own, isNot(contains('three-qua.')));
      expect(prompt, contains(ImageGenerator.style));
    });

    test('en een zin met gewrichten erin past nu wel', () {
      // De zin die in de test wel klopte - de beweging bij naam, dan hoe de
      // gewrichten staan - is zo'n 140 tekens. Die mag niet sneuvelen aan een
      // grens die uit twee metingen kwam.
      const written =
          'Side view of a person doing a standing overhead triceps extension, '
          'elbows pointing up beside the ears, forearms folded back behind '
          'the head, feet shoulder width apart';

      final prompt = ImageGenerator.stylise(written);

      expect(prompt, startsWith(written));
      expect(written.length, greaterThan(160));
    });

    test('en een korte blijft heel', () {
      final prompt = ImageGenerator.stylise(
        'A man seated at a rowing machine pulls two handles back to his ribs, '
        'elbows behind his body',
      );

      expect(prompt, contains('elbows behind his body.'));
    });

    test('de vraag gaat over een mens in een houding', () {
      // Zonder mens kan je geen begin- en eindpositie tonen; dat paar is
      // precies waarvoor die twee plaatjes bestaan.
      final start = ImageGenerator.promptFor(
        name: 'Sledepush',
        equipment: 'slee',
        start: true,
      );
      final end = ImageGenerator.promptFor(
        name: 'Sledepush',
        equipment: 'slee',
        start: false,
      );

      expect(start, contains('a person doing'));
      expect(start, contains('Sledepush'));
      expect(start, contains('slee'));
      expect(start, contains('at the start'));
      expect(end, contains('at the end'));
      // En kort, want daar wordt de tekening beter van.
      expect(
        start.length - ImageGenerator.style.length,
        lessThanOrEqualTo(ImageGenerator.maxPromptLength),
      );
      // De beweging staat er met haar naam in, en van opzij: naast elkaar
      // gezet tekende de naam de juiste houding en een beschrijving van
      // boven- en onderarm iemand die zijn biceps spande.
      expect(start, startsWith('Side view of'));
      // En allebei dezelfde stijl, anders is het geen paar.
      expect(start, contains(ImageGenerator.style));
      expect(end, contains(ImageGenerator.style));
    });

    test('en de stijl legt de camera niet vast', () {
      // Bij een zittende machine is de zijkant net de hoek waar de machine de
      // persoon verbergt. Welke hoek de beweging toont verschilt per oefening,
      // dus kiest wie de prompt schrijft hem, niet de staart.
      expect(ImageGenerator.style, isNot(contains('side view')));

      final prompt = ImageGenerator.stylise(
        'A person seated at a chest-supported row machine, seen from a high '
        'three-quarter angle',
      );

      expect(prompt, contains('three-quarter angle'));
    });

    test(
      'en een beschrijving van de coach leidt, met dezelfde stijl erachter',
      () {
        final prompt = ImageGenerator.stylise(
          'A person standing upright holding a barbell at hip height',
        );

        expect(prompt, startsWith('A person standing upright'));
        expect(prompt, contains(ImageGenerator.style));
        // Eén punt, niet twee.
        expect(prompt, isNot(contains('..')));
      },
    );

    test('de tekening volgt de beschrijving van de coach', () async {
      container = containerThatDraws();

      await container!
          .read(exerciseEditorProvider)
          .drawFrame(
            name: 'Sledepush',
            start: false,
            prompt: 'A person leaning into a loaded sled, arms extended',
          );

      expect(sent.single.body, contains('leaning into a loaded sled'));
      // Het sjabloon van de app is dan niet gebruikt.
      expect(sent.single.body, isNot(contains('Side view of a person')));
    });

    test('en wat de gebruiker te zien krijgt draagt de stijl niet', () {
      // Die staart is van de app; in het vakje waar je zelf in typt heeft ze
      // niets te zoeken.
      final shown = ImageGenerator.describe(
        name: 'Sledepush',
        equipment: 'slee',
        start: true,
      );

      expect(shown, isNot(contains(ImageGenerator.style)));
      expect(
        ImageGenerator.promptFor(
          name: 'Sledepush',
          equipment: 'slee',
          start: true,
        ),
        ImageGenerator.stylise(shown),
      );
    });

    test('een leeg tegoed zegt dat er niets getekend is', () async {
      container = containerThatDraws(
        status: 402,
        body: {'error': 'no credits'},
      );

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', start: true),
        throwsA(
          isA<CoachException>()
              .having((e) => e.message, 'message', contains('tegoed'))
              .having((e) => e.message, 'message', contains('niets getekend')),
        ),
      );
    });

    test('een opgebruikte dagportie is geen geweigerd token', () async {
      // Zo stond het er eerst wel, en dan zoek je in je instellingen naar een
      // fout die er niet is terwijl je gewoon moet wachten.
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(
          imageProvider: Value('cloudflare'),
          imageAccountId: Value('acc-123'),
        ),
      );
      container = containerThatDraws(
        cloudflare: true,
        status: 429,
        body: {
          'success': false,
          'errors': [
            {'code': 3036, 'message': 'Account limited'},
          ],
        },
      );

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', start: true),
        throwsA(
          isA<CoachException>()
              .having((e) => e.badKey, 'badKey', isFalse)
              .having((e) => e.message, 'message', contains('middernacht'))
              // En wat de dienst zelf zei, met het nummer erbij: dat nummer
              // scheidt "wacht tot morgen" van "probeer zo opnieuw".
              .having((e) => e.message, 'message', contains('Account limited'))
              .having((e) => e.message, 'message', contains('3036')),
        ),
      );
    });

    test('en de boodschap van de dienst wordt leesbaar doorgegeven', () async {
      // Zoals ze er echt uitkomt: het label tweemaal en een tracenummer dat
      // alleen iets zegt tegen wie de dienst schreef.
      container = containerThatDraws(
        cloudflare: true,
        status: 429,
        body: {
          'success': false,
          'errors': [
            {
              'code': 4006,
              'message':
                  'AiError: AiError: you have used up your daily free '
                  'allocation of 10,000 neurons, please upgrade. '
                  '(fe5d7715-d06b-49c2-93d6-75c21dbbc197)',
            },
          ],
        },
      );
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(
          imageProvider: Value('cloudflare'),
          imageAccountId: Value('acc-123'),
        ),
      );

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', start: true),
        throwsA(
          isA<CoachException>()
              .having((e) => e.message, 'message', contains('daily free'))
              .having((e) => e.message, 'message', contains('(4006)'))
              .having((e) => e.message, 'message', isNot(contains('AiError')))
              .having((e) => e.message, 'message', isNot(contains('fe5d7715'))),
        ),
      );
    });

    test('een geweigerd token ook', () async {
      container = containerThatDraws(status: 401, body: {'error': 'nope'});

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', start: true),
        throwsA(
          isA<CoachException>().having((e) => e.badKey, 'badKey', isTrue),
        ),
      );
    });

    test('en een antwoord zonder afbeelding is een nette fout', () async {
      container = containerThatDraws(body: {'data': <Object?>[]});

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', start: true),
        throwsA(isA<CoachException>()),
      );
    });
  });

  group('bij Cloudflare', () {
    setUp(() async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(
          imageApiKey: Value('cf_test'),
          imageProvider: Value('cloudflare'),
          imageAccountId: Value('acc-123'),
        ),
      );
    });

    test('gaat de vraag naar het account van de gebruiker', () async {
      container = containerThatDraws(cloudflare: true);

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true, seed: 7);

      expect(file, isNotNull);
      expect(sent, hasLength(1));
      expect(
        sent.single.url.toString(),
        'https://api.cloudflare.com/client/v4/accounts/acc-123/ai/run/'
        '@cf/black-forest-labs/flux-2-klein-9b',
      );
      expect(sent.single.headers['authorization'], 'Bearer cf_test');
    });

    test('als formuliervelden, want JSON wordt daar geweigerd', () async {
      container = containerThatDraws(cloudflare: true);

      await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true, seed: 7);

      final type = sent.single.headers['content-type'] ?? '';
      expect(type, contains('multipart/form-data'));
      final body = sent.single.body;
      expect(body, contains('name="prompt"'));
      expect(body, contains('Side view of a person doing Sledepush'));
      // De vorm van het vak en het zaad van het paar gaan mee.
      expect(body, contains('name="width"'));
      expect(body, contains('768'));
      expect(body, contains('name="seed"'));
      // En de sleutel staat in de kop, niet in wat verstuurd wordt.
      expect(body, isNot(contains('cf_test')));
    });

    test('en het antwoord zit ergens anders in verpakt', () async {
      // Hugging Face zegt data[0].b64_json, Cloudflare zegt result.image.
      container = containerThatDraws(
        cloudflare: true,
        body: {
          'success': true,
          'result': {'image': drawnImage()},
        },
      );

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true);

      expect(await PhotoStore(paths).exists(file!), isTrue);
    });

    test('zonder account-ID wordt er niets getekend', () async {
      // Half ingevuld is niet ingevuld: een token zonder account weet niet
      // wiens dagportie het opmaakt.
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageAccountId: Value(null)),
      );
      container = containerThatDraws(cloudflare: true);

      expect(container!.read(canDrawImagesProvider), isFalse);

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', start: true);

      expect(file, isNull);
      expect(sent, isEmpty);
    });
  });

  group('materiaal in de tekening', () {
    setUp(() async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );
    });

    test('mag standaard geprobeerd worden', () async {
      container = containerThatDraws();

      await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', equipment: 'slee', start: true);

      expect(sent.single.body, contains('slee'));
      expect(sent.single.body, isNot(contains('No gym equipment')));
    });

    test('en staat de schakelaar uit, dan blijft het eruit', () async {
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageEquipment: Value(false)),
      );
      container = containerThatDraws();

      await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', equipment: 'slee', start: true);

      expect(sent.single.body, isNot(contains('slee')));
      // En er staat uitdrukkelijk dat er geen is: zwijgen is niet genoeg,
      // dan pakt het model er zelf een.
      expect(sent.single.body, contains('No gym equipment'));
      expect(sent.single.body, contains('empty hands'));
    });

    test('ook in een zin die de coach schreef', () async {
      // Die zin is niet van ons, maar de staart wel - en die beslist.
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageEquipment: Value(false)),
      );
      container = containerThatDraws();

      await container!
          .read(exerciseEditorProvider)
          .drawFrame(
            name: 'Sledepush',
            start: true,
            prompt: 'A person leaning forward, arms extended',
          );

      expect(sent.single.body, contains('leaning forward'));
      expect(sent.single.body, contains('No gym equipment'));
    });

    test('en de beschrijving zelf noemt het dan ook niet', () {
      final shown = ImageGenerator.describe(
        name: 'Sledepush',
        equipment: 'slee',
        start: true,
      );

      expect(shown, contains('slee'));
      expect(
        ImageGenerator.promptFor(
          name: 'Sledepush',
          equipment: 'slee',
          start: true,
          withEquipment: false,
        ),
        isNot(contains('slee')),
      );
    });
  });

  group('wat er bewaard wordt', () {
    test('een getekende oefening draagt dat bij zich', () async {
      container = containerThatDraws();
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(imageApiKey: Value('hf_test')),
      );

      final editor = container!.read(exerciseEditorProvider);
      final file = await editor.drawFrame(name: 'Sledepush', start: true);
      final id = await editor.create(
        name: 'Sledepush',
        primaryMuscle: 'benen',
        secondaryMuscles: const [],
        category: const CategoryChoice(ExerciseCategory.duration),
        startImageFile: file,
        imagesGenerated: true,
      );

      final made = (await db.exercisesDao.getById(id))!;
      expect(made.startImageFile, file);
      expect(made.imagesGenerated, isTrue);
    });

    test('en een gewone oefening niet', () async {
      container = containerThatDraws();

      final id = await container!
          .read(exerciseEditorProvider)
          .create(
            name: 'Eigen curl',
            primaryMuscle: 'biceps',
            secondaryMuscles: const [],
            category: const CategoryChoice(ExerciseCategory.dumbbell),
          );

      expect((await db.exercisesDao.getById(id))!.imagesGenerated, isFalse);
    });
  });
}
