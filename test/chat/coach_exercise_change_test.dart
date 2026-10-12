import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:fitlog/features/photos/data/photo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../widget/helpers.dart';

/// The coach changing one of your own exercises - its words, its photos - and
/// only once you tap Toepassen. The catalogue's exercises it leaves alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory home;
  late AppPaths paths;
  late PhotoStore store;
  ProviderContainer? container;

  /// Two photos the user sent in the chat, and the two frames the exercise
  /// had before: all real files in the photo directory.
  late String sentFirst;
  late String sentSecond;
  late String oldStart;
  late String oldEnd;

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  Future<String> aFile() =>
      store.importBytes(img.encodeJpg(img.Image(width: 32, height: 32)));

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    home = await Directory.systemTemp.createTemp('fitlog_change');
    paths = AppPaths(home);
    store = PhotoStore(paths);
    sentFirst = await aFile();
    sentSecond = await aFile();
    oldStart = await aFile();
    oldEnd = await aFile();

    await db
        .into(db.exercisesTable)
        .insert(
          ExercisesTableCompanion.insert(
            id: 'ex-own',
            name: 'Sledepush',
            primaryMuscle: 'benen',
            category: 'duration',
            isCustom: const Value(true),
            startImageFile: Value(oldStart),
            endImageFile: Value(oldEnd),
            imagesGenerated: const Value(true),
            createdAt: 0,
          ),
        );
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
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
    if (await home.exists()) await home.delete(recursive: true);
  });

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWith((ref) => AppPaths(home)),
    ],
  );

  Future<ChatMessageRow> answerWith(CoachProposal proposal) async {
    await db.chatDao.createThread('t-1', 'Vraag');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Zo zou ik het doen.',
      proposals: encodeProposals([proposal]),
    );
    return (await db.chatDao.messages('t-1')).single;
  }

  group('de coach stelt een wijziging voor', () {
    test('aan een eigen oefening: een kaart, en verder niets', () async {
      final tools = CoachTools(db, photos: [sentFirst, sentSecond]);

      final lookup = await tools.run('propose_exercise_change', {
        'exercise': 'sledepush',
        'instructions': 'Duw laag, met gestrekte armen.',
        'start_photo': 2,
        'end_photo': 1,
        'reason': "De foto's die je stuurde, en een betere uitleg.",
      });

      expect(decode(lookup)['ok'], isTrue);
      final change = lookup.proposal!.exerciseChange!;
      expect(lookup.proposal!.kind, ProposalKind.exerciseChange);
      expect(change.exerciseId, 'ex-own');
      expect(change.exerciseName, 'Sledepush');
      expect(change.instructions, 'Duw laag, met gestrekte armen.');
      // Foto 2 is de start, foto 1 het eind: zoals de coach het zei.
      expect(change.startPhoto, sentSecond);
      expect(change.endPhoto, sentFirst);
      expect(change.name, isNull, reason: 'only what changes');

      final row = (await db.exercisesDao.getById('ex-own'))!;
      expect(row.instructions, isNull);
      expect(row.startImageFile, oldStart);
    });

    test('een ingebouwde oefening niet', () async {
      final lookup = await CoachTools(db).run('propose_exercise_change', {
        'exercise': 'Bench Press',
        'instructions': 'Anders.',
      });

      expect(decode(lookup)['ok'], isFalse);
      expect(decode(lookup)['error'], contains('ingebouwde'));
      expect(lookup.proposal, isNull);
    });

    test('een foto die er niet is, zegt hoeveel er wel zijn', () async {
      final lookup = await CoachTools(db, photos: [sentFirst, sentSecond]).run(
        'propose_exercise_change',
        {'exercise': 'Sledepush', 'start_photo': 3},
      );

      expect(decode(lookup)['ok'], isFalse);
      expect(decode(lookup)['error'], contains('er zijn er 2'));
      expect(lookup.proposal, isNull);

      final none = await CoachTools(db).run('propose_exercise_change', {
        'exercise': 'Sledepush',
        'end_photo': 1,
      });
      expect(decode(none)['error'], contains('geen foto'));
    });

    test('een naam die al bestaat, wordt geen tweede', () async {
      final lookup = await CoachTools(db).run('propose_exercise_change', {
        'exercise': 'Sledepush',
        'name': 'bench press',
      });

      expect(decode(lookup)['ok'], isFalse);
      expect(lookup.proposal, isNull);
    });

    test('niets veranderen is geen voorstel', () async {
      final lookup = await CoachTools(db)
          .run('propose_exercise_change', {'exercise': 'Sledepush'});

      expect(decode(lookup)['ok'], isFalse);
      expect(lookup.proposal, isNull);
    });

    test('de kaart overleeft opschrijven en teruglezen', () {
      final read = parseProposals(
        encodeProposals([
          CoachProposal.ofExerciseChange(
            const ExerciseChangeProposal(
              exerciseId: 'ex-own',
              exerciseName: 'Sledepush',
              secondaryMuscles: ['bilspieren'],
              startPhoto: 'a.jpg',
              reason: 'Waarom',
            ),
          ),
        ]),
      ).single;

      expect(read.kind, ProposalKind.exerciseChange);
      expect(read.title, 'Sledepush');
      expect(read.exerciseChange!.secondaryMuscles, ['bilspieren']);
      expect(read.exerciseChange!.startPhoto, 'a.jpg');
      expect(read.exerciseChange!.endPhoto, isNull);
      expect(read.exerciseChange!.reason, 'Waarom');
    });
  });

  group('Toepassen', () {
    test("zet de uitleg en de foto's erop, als kopie, en ruimt op", () async {
      container = newContainer();
      final message = await answerWith(
        CoachProposal.ofExerciseChange(
          ExerciseChangeProposal(
            exerciseId: 'ex-own',
            exerciseName: 'Sledepush',
            instructions: 'Duw laag.',
            startPhoto: sentSecond,
            endPhoto: sentFirst,
          ),
        ),
      );
      final coach = container!.read(coachControllerProvider.notifier);

      final id = await coach.accept(message: message, index: 0);

      expect(id, 'ex-own');
      final row = (await db.exercisesDao.getById('ex-own'))!;
      expect(row.instructions, 'Duw laag.');
      expect(row.name, 'Sledepush', reason: 'what was not proposed stays');
      // Een kopie: het gesprek en de oefening houden elk hun eigen bestand.
      expect(row.startImageFile, isNot(anyOf(sentFirst, sentSecond)));
      expect(row.endImageFile, isNot(anyOf(sentFirst, sentSecond)));
      expect(await store.exists(row.startImageFile!), isTrue);
      expect(await store.exists(row.endImageFile!), isTrue);
      expect(await store.exists(sentFirst), isTrue);
      expect(await store.exists(sentSecond), isTrue);
      // De oude tekeningen zijn van niemand meer, en hun regel gaat mee.
      expect(await store.exists(oldStart), isFalse);
      expect(await store.exists(oldEnd), isFalse);
      expect(row.imagesGenerated, isFalse);

      // En de kaart weet dat ze toegepast is.
      final again = (await db.chatDao.messages('t-1')).single;
      expect(parseProposals(again.proposals).single.appliedId, 'ex-own');
      expect(await coach.accept(message: again, index: 0), 'ex-own');
    });

    test('één foto: de getekende andere houdt haar regel', () async {
      container = newContainer();
      final message = await answerWith(
        CoachProposal.ofExerciseChange(
          ExerciseChangeProposal(
            exerciseId: 'ex-own',
            exerciseName: 'Sledepush',
            startPhoto: sentFirst,
          ),
        ),
      );

      await container!
          .read(coachControllerProvider.notifier)
          .accept(message: message, index: 0);

      final row = (await db.exercisesDao.getById('ex-own'))!;
      expect(row.endImageFile, oldEnd);
      expect(row.imagesGenerated, isTrue);
      expect(await store.exists(oldStart), isFalse);
    });

    test('een oefening die intussen weg is, zegt dat', () async {
      container = newContainer();
      await (db.update(db.exercisesTable)..where((t) => t.id.equals('ex-own')))
          .write(const ExercisesTableCompanion(isArchived: Value(true)));
      final message = await answerWith(
        CoachProposal.ofExerciseChange(
          const ExerciseChangeProposal(
            exerciseId: 'ex-own',
            exerciseName: 'Sledepush',
            instructions: 'Duw laag.',
          ),
        ),
      );

      await expectLater(
        container!
            .read(coachControllerProvider.notifier)
            .accept(message: message, index: 0),
        throwsA(isA<CoachException>()),
      );
      expect((await db.exercisesDao.getById('ex-own'))!.instructions, isNull);
    });
  });

  test("een nieuwe oefening met de foto's die je stuurde", () async {
    final lookup = await CoachTools(db, photos: [sentFirst, sentSecond]).run(
      'propose_exercise',
      {
        'name': 'Landmine Press',
        'primary_muscle': 'schouders',
        'start_photo': 1,
        'end_photo': 2,
      },
    );
    expect(lookup.proposal!.exercise!.startPhoto, sentFirst);
    expect(lookup.proposal!.exercise!.hasPhotos, isTrue);

    container = newContainer();
    final message = await answerWith(lookup.proposal!);
    final id = await container!
        .read(coachControllerProvider.notifier)
        .accept(message: message, index: 0);

    final row = (await db.exercisesDao.getById(id!))!;
    expect(row.isCustom, isTrue);
    expect(await store.exists(row.startImageFile!), isTrue);
    expect(await store.exists(row.endImageFile!), isTrue);
    expect(row.startImageFile, isNot(sentFirst));
    expect(row.imagesGenerated, isFalse, reason: 'photos, not drawings');
  });
}
