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

  ProviderContainer containerThatDraws({int status = 200, Object? body}) =>
      ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appPathsProvider.overrideWith((ref) => paths),
          imageGeneratorFactoryProvider.overrideWithValue(
            (apiKey) => ImageGenerator(
              apiKey: apiKey,
              client: MockClient((request) async {
                sent.add(request);
                return http.Response(
                  jsonEncode(
                    body ??
                        {
                          'data': [
                            {'b64_json': drawnImage()},
                          ],
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

  group('zonder token', () {
    test('wordt er nooit iets getekend', () async {
      container = containerThatDraws();

      expect(container!.read(canDrawImagesProvider), isFalse);

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', muscle: 'benen');

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
          .drawFrame(name: 'Sledepush', muscle: 'benen', equipment: 'slee');

      expect(file, isNotNull);
      expect(sent, hasLength(1));
      expect(sent.single.url.toString(), ImageGenerator.endpoint);
      expect(sent.single.headers['authorization'], 'Bearer hf_test');
      // De sleutel staat in de header, niet in wat verstuurd wordt.
      expect(sent.single.body, isNot(contains('hf_test')));
    });

    test('en de tekening staat bij de andere foto\'s', () async {
      container = containerThatDraws();

      final file = await container!
          .read(exerciseEditorProvider)
          .drawFrame(name: 'Sledepush', muscle: 'benen');

      expect(await PhotoStore(paths).exists(file!), isTrue);
    });

    test('de vraag beschrijft het materiaal, niet een mens', () {
      // Een model is het meest overtuigend fout over een lichaam dat een
      // beweging uitvoert; een foto van het toestel is wat een bibliotheek
      // nodig heeft.
      final prompt = ImageGenerator.promptFor(
        name: 'Sledepush',
        muscle: 'benen',
        equipment: 'slee',
      );

      expect(prompt, contains('Sledepush'));
      expect(prompt, contains('slee'));
      expect(prompt, contains('no people'));
      expect(prompt, contains('white background'));
    });

    test('een leeg tegoed zegt dat er niets getekend is', () async {
      container = containerThatDraws(
        status: 402,
        body: {'error': 'no credits'},
      );

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', muscle: 'benen'),
        throwsA(
          isA<CoachException>()
              .having((e) => e.message, 'message', contains('tegoed'))
              .having((e) => e.message, 'message', contains('niets getekend')),
        ),
      );
    });

    test('een geweigerd token ook', () async {
      container = containerThatDraws(status: 401, body: {'error': 'nope'});

      await expectLater(
        container!
            .read(exerciseEditorProvider)
            .drawFrame(name: 'Sledepush', muscle: 'benen'),
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
            .drawFrame(name: 'Sledepush', muscle: 'benen'),
        throwsA(isA<CoachException>()),
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
      final file = await editor.drawFrame(name: 'Sledepush', muscle: 'benen');
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
