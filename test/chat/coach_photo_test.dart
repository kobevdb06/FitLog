import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/photos/data/photo_library.dart';
import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import '../widget/helpers.dart';

/// A photo sent along with a question.
///
/// The picture is the most expensive thing that can leave the device and the
/// most personal, so what matters here is that it goes exactly once, that it
/// is stored where the rest of the photos live, and that it is not resent with
/// every later question.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory home;
  late AppPaths paths;
  ProviderContainer? container;

  /// Every request body the fake service was sent.
  late List<String> sent;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
    home = await Directory.systemTemp.createTemp('fitlog_coach_photo');
    paths = AppPaths(home);
    sent = [];
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
    if (await home.exists()) await home.delete(recursive: true);
  });

  ProviderContainer containerSaying(String text) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => paths),
        coachClientFactoryProvider.overrideWithValue(
          (apiKey, provider) => AiClient(
            apiKey: apiKey,
            provider: provider,
            client: MockClient((request) async {
              sent.add(request.body);
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': text},
                        ],
                      },
                    },
                  ],
                  'usageMetadata': {
                    'promptTokenCount': 1200,
                    'candidatesTokenCount': 40,
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );
  }

  /// A real, tiny JPEG on disk, standing in for something picked.
  Future<File> aPhoto() async {
    final file = File('${home.path}/gekozen.jpg');
    await file.writeAsBytes(
      img.encodeJpg(img.Image(width: 40, height: 40)),
      flush: true,
    );
    return file;
  }

  test('wordt bewaard bij de andere foto\'s, en kleiner', () async {
    container = containerSaying('ok');
    final coach = container!.read(coachControllerProvider.notifier);

    final stored = await coach.importPhoto(await aPhoto());

    expect(stored, isNotNull);
    expect(await PhotoStore(paths).exists(stored!), isTrue);
    // Kleiner dan een voortgangsfoto: dit wordt per token betaald.
    expect(CoachController.photoLongEdge, lessThan(PhotoStore.maxLongEdge));
  });

  test('gaat mee met de vraag, één keer', () async {
    container = containerSaying('Dat is een lat pulldown.');
    final coach = container!.read(coachControllerProvider.notifier);

    final stored = await coach.importPhoto(await aPhoto());
    final thread = await coach.startThread('Wat is dit?');
    await coach.ask(
      threadId: thread,
      question: 'Wat is dit voor toestel?',
      imageFiles: [stored!],
    );

    expect(sent, hasLength(1));
    expect('inlineData'.allMatches(sent.single).length, 1);

    final messages = await db.chatDao.messages(thread);
    expect(decodeImageFiles(messages.first.imageFiles), [stored]);
    // En het antwoord zegt dat de foto is meegegaan.
    expect(messages.last.lookups, contains('de foto die je meestuurde'));
  });

  test('en een vervolgvraag stuurt ze nog één keer, niet elke keer', () async {
    container = containerSaying('Ja.');
    final coach = container!.read(coachControllerProvider.notifier);

    final stored = await coach.importPhoto(await aPhoto());
    final thread = await coach.startThread('Wat is dit?');
    await coach.ask(
      threadId: thread,
      question: 'Wat is dit voor toestel?',
      imageFiles: [stored!],
    );
    await coach.ask(threadId: thread, question: 'En voor mijn rug?');
    await coach.ask(threadId: thread, question: 'Hoeveel sets dan?');

    expect(sent, hasLength(3));
    // De eerste vraag draagt de foto, de vervolgvraag draagt ze nog een keer
    // omdat ze erover gaat, en daarna niet meer dan dat: één foto per bericht.
    for (final body in sent) {
      expect('inlineData'.allMatches(body).length, lessThanOrEqualTo(1));
    }
  });

  test("tot vier foto's gaan mee, elk één keer", () async {
    container = containerSaying('Begin en eind.');
    final coach = container!.read(coachControllerProvider.notifier);

    final stored = [
      for (var i = 0; i < 5; i++) (await coach.importPhoto(await aPhoto()))!,
    ];
    final thread = await coach.startThread('Mijn oefening');
    await coach.ask(
      threadId: thread,
      question: 'Zet deze op mijn oefening',
      imageFiles: stored,
    );
    await coach.ask(threadId: thread, question: 'En welke is het begin?');

    // Vier en niet vijf: meer gaat er niet mee met één vraag.
    expect('inlineData'.allMatches(sent.first).length, 4);
    // De vervolgvraag gaat over dezelfde foto's, en draagt ze nog een keer.
    expect('inlineData'.allMatches(sent.last).length, 4);

    final messages = await db.chatDao.messages(thread);
    expect(decodeImageFiles(messages.first.imageFiles), stored.take(4));
    expect(messages[1].lookups, contains("de 4 foto's die je meestuurde"));
  });

  test("de coach kan de foto's die je stuurde op je oefening zetten", () async {
    // Twee rondes: eerst vraagt het model de wijziging, dan antwoordt het.
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
    var round = 0;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWith((ref) => paths),
        coachClientFactoryProvider.overrideWithValue(
          (apiKey, provider) => AiClient(
            apiKey: apiKey,
            provider: provider,
            client: MockClient((request) async {
              sent.add(request.body);
              final parts = round++ == 0
                  ? [
                      {
                        'functionCall': {
                          'name': 'propose_exercise_change',
                          'args': {
                            'exercise': 'Sledepush',
                            'start_photo': 2,
                            'end_photo': 1,
                          },
                        },
                      },
                    ]
                  : [
                      {'text': 'Foto 2 is de start, foto 1 het eind.'},
                    ];
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {'parts': parts},
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );
    final coach = container!.read(coachControllerProvider.notifier);
    final first = (await coach.importPhoto(await aPhoto()))!;
    final second = (await coach.importPhoto(await aPhoto()))!;
    final thread = await coach.startThread("Mijn foto's");

    await coach.ask(
      threadId: thread,
      question: 'Zet deze op mijn sledepush',
      imageFiles: [first, second],
    );

    final answer = (await db.chatDao.messages(thread)).last;
    final change = parseProposals(answer.proposals).single.exerciseChange!;
    expect(change.startPhoto, second);
    expect(change.endPhoto, first);
  });

  test('een vraag zonder foto stuurt er ook geen', () async {
    container = containerSaying('Tussen 10 en 20 sets.');
    final coach = container!.read(coachControllerProvider.notifier);

    final thread = await coach.startThread('Hoeveel sets?');
    await coach.ask(threadId: thread, question: 'Hoeveel sets voor borst?');

    expect(sent.single, isNot(contains('inlineData')));
    final messages = await db.chatDao.messages(thread);
    expect(decodeImageFiles(messages.first.imageFiles), isEmpty);
    expect(messages.last.lookups, isNull);
  });

  test('en de opruiming laat een foto uit een gesprek staan', () async {
    // De opruiming bij het opstarten gooit bestanden weg waar niets naar
    // wijst. Een foto die je aan de coach stuurde is er daar een van, tot ze
    // van dit gesprek weet.
    container = containerSaying('ok');
    final coach = container!.read(coachControllerProvider.notifier);

    final stored = (await coach.importPhoto(await aPhoto()))!;
    final thread = await coach.startThread('Wat is dit?');
    await coach.ask(
      threadId: thread,
      question: 'Wat is dit?',
      imageFiles: [stored],
    );

    await PhotoLibrary(db: db, store: PhotoStore(paths)).cleanup();

    expect(await PhotoStore(paths).exists(stored), isTrue);
  });
}
