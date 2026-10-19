import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fitlog/core/app/app_controller.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:fitlog/core/util/paths.dart';
import 'package:fitlog/features/chat/data/ai_client.dart';
import 'package:fitlog/features/chat/data/coach_tools.dart';
import 'package:fitlog/features/chat/domain/coach_prompt.dart';
import 'package:fitlog/features/chat/domain/coach_proposal.dart';
import 'package:fitlog/features/chat/presentation/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../widget/helpers.dart';

/// What the coach remembers about you between conversations: written by the
/// coach, seen and wiped by you, sent along while it is on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CoachTools tools;

  Map<String, Object?> decode(CoachLookup lookup) =>
      jsonDecode(lookup.json) as Map<String, Object?>;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
    tools = CoachTools(db, memory: true);
  });

  tearDown(() => db.close());

  group('het notitieboekje', () {
    test(
      'staat standaard aan, en houdt notities kort en op één regel',
      () async {
        expect((await db.settingsDao.getSettings()).coachMemory, isTrue);

        final id = await db.coachNotesDao.add(
          '  Traint   ma, wo\nen vr  ',
          kind: CoachNoteKind.schedule,
        );
        final note = (await db.coachNotesDao.note(id))!;
        expect(note.note, 'Traint ma, wo en vr');
        expect(note.kind, 'schedule');

        await db.coachNotesDao.add('x' * 400);
        expect(
          (await db.coachNotesDao.notes()).last.note.length,
          kCoachNoteLength,
        );
      },
    );

    test('aanpassen, vergeten en alles vergeten', () async {
      final id = await db.coachNotesDao.add('Doel: 90 kg');
      expect(await db.coachNotesDao.change(id, 'Doel: 100 kg'), isTrue);
      expect((await db.coachNotesDao.note(id))!.note, 'Doel: 100 kg');
      expect(await db.coachNotesDao.change(99, 'Niets'), isFalse);

      expect(await db.coachNotesDao.forget(id), isTrue);
      expect(await db.coachNotesDao.forget(id), isFalse);

      await db.coachNotesDao.add('Een');
      await db.coachNotesDao.add('Twee');
      await db.coachNotesDao.forgetAll();
      expect(await db.coachNotesDao.count(), 0);
    });
  });

  group('remember', () {
    test(
      'schrijft een notitie, en de eerste zegt wat het geheugen is',
      () async {
        final lookup = await tools.run('remember', {
          'note': 'Linkerknie doet pijn bij diepe squats: tot parallel.',
          'kind': 'limit',
        });

        final found = decode(lookup);
        expect(found['ok'], isTrue);
        final note = (await db.coachNotesDao.notes()).single;
        expect(found['id'], note.id);
        expect(note.kind, 'limit');
        expect(lookup.proposal!.kind, ProposalKind.note);
        expect(lookup.proposal!.note!.action, NoteAction.made);
        expect(lookup.proposal!.note!.first, isTrue);
        expect(lookup.summary, 'iets onthouden over je');

        final second = await tools.run('remember', {
          'note': 'Traint thuis met dumbbells tot 24 kg.',
          'kind': 'kit',
        });
        expect(second.proposal!.note!.first, isFalse);
      },
    );

    test(
      'met replaces past het een notitie aan in plaats van een tweede',
      () async {
        final id = await db.coachNotesDao.add(
          'Doel: 90 kg bankdrukken',
          kind: CoachNoteKind.goal,
        );

        final lookup = await tools.run('remember', {
          'note': 'Doel: 100 kg bankdrukken tegen juni',
          'kind': 'goal',
          'replaces': id,
        });

        expect(decode(lookup)['ok'], isTrue);
        expect(lookup.proposal!.note!.action, NoteAction.changed);
        final notes = await db.coachNotesDao.notes();
        expect(notes.single.note, 'Doel: 100 kg bankdrukken tegen juni');

        final wrong = await tools.run('remember', {
          'note': 'Iets',
          'kind': 'other',
          'replaces': 99,
        });
        expect(decode(wrong)['error'], contains('geen notitie 99'));
      },
    );

    test('te lang, of het boekje vol: dan zegt het wat te doen', () async {
      final long = await tools.run('remember', {
        'note': 'x' * 151,
        'kind': 'other',
      });
      expect(decode(long)['error'], contains('te lang'));

      for (var i = 0; i < kCoachNoteMax; i++) {
        await db.coachNotesDao.add('Notitie $i');
      }
      final full = await tools.run('remember', {
        'note': 'Nog een',
        'kind': 'other',
      });
      expect(decode(full)['error'], contains('vol'));
      expect(await db.coachNotesDao.count(), kCoachNoteMax);
    });
  });

  test('forget wist een notitie, en het kaartje zegt welke', () async {
    final id = await db.coachNotesDao.add('Traint op zaterdag');

    final lookup = await tools.run('forget', {'id': id});

    expect(decode(lookup)['ok'], isTrue);
    expect(await db.coachNotesDao.notes(), isEmpty);
    expect(lookup.proposal!.note!.action, NoteAction.forgotten);
    expect(lookup.proposal!.note!.text, 'Traint op zaterdag');
  });

  group('als het geheugen uit staat', () {
    test(
      'worden remember en forget niet aangeboden, en doen ze niets',
      () async {
        final off = CoachTools(db);
        final offered = {for (final tool in off.offered) tool['name']};
        expect(offered, isNot(contains('remember')));
        expect(offered, isNot(contains('forget')));
        expect({
          for (final tool in tools.offered) tool['name'],
        }, containsAll(['remember', 'forget']));

        final lookup = await off.run('remember', {
          'note': 'Iets',
          'kind': 'other',
        });
        expect(decode(lookup)['error'], contains('staat uit'));
        expect(await db.coachNotesDao.notes(), isEmpty);
      },
    );
  });

  group('de prompt', () {
    test('noemt elke notitie met haar nummer', () {
      expect(
        describeNotes([
          (id: 3, kind: 'goal', text: 'Doel: 100 kg bankdrukken'),
          (id: 5, kind: 'limit', text: 'Linkerknie: tot parallel'),
        ]),
        'Wat je over de gebruiker onthoudt (aanpassen met remember, wissen '
        'met forget):\n'
        '[3] goal: Doel: 100 kg bankdrukken\n'
        '[5] limit: Linkerknie: tot parallel',
      );
      expect(describeNotes(const []), isNull);
    });
  });

  group('wat meegaat met een vraag', () {
    late Directory home;
    late ProviderContainer container;
    late List<Map<String, Object?>> sent;

    setUp(() async {
      await db.settingsDao.setApiKey('AQ.Ab8RNiZhX2Mkg');
      home = await Directory.systemTemp.createTemp('fitlog_memory');
      sent = [];
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appPathsProvider.overrideWith((ref) => AppPaths(home)),
          coachClientFactoryProvider.overrideWithValue(
            (apiKey, provider) => AiClient(
              apiKey: apiKey,
              provider: provider,
              client: MockClient((request) async {
                sent.add(jsonDecode(request.body) as Map<String, Object?>);
                return http.Response(
                  jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {'text': 'Begrepen.'},
                          ],
                        },
                      },
                    ],
                    'usageMetadata': {
                      'promptTokenCount': 1200,
                      'candidatesTokenCount': 4,
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
    });

    tearDown(() async {
      container.dispose();
      if (await home.exists()) await home.delete(recursive: true);
    });

    Future<void> ask() async {
      final coach = container.read(coachControllerProvider.notifier);
      final thread = await coach.startThread('Wat train ik?');
      await coach.ask(threadId: thread, question: 'Wat train ik?');
    }

    String system() => jsonEncode(sent.single['systemInstruction']);
    Set<Object?> toolNames() => {
      for (final tool
          in ((sent.single['tools']! as List).single
                  as Map)['functionDeclarations']
              as List)
        (tool as Map)['name'],
    };

    test('aan: de notities en de twee tools', () async {
      await db.coachNotesDao.add(
        'Linkerknie: tot parallel',
        kind: CoachNoteKind.limit,
      );

      await ask();

      expect(system(), contains('[1] limit: Linkerknie: tot parallel'));
      expect(toolNames(), containsAll(['remember', 'forget']));
    });

    test('uit: niets ervan, ook niet de bewaarde notities', () async {
      await db.coachNotesDao.add('Linkerknie: tot parallel');
      await db.settingsDao.updateSettings(
        const AppSettingsTableCompanion(coachMemory: Value(false)),
      );

      await ask();

      expect(system(), isNot(contains('Linkerknie')));
      expect(toolNames(), isNot(contains('remember')));
    });
  });

  test('een kaartje overleeft opschrijven en teruglezen', () {
    final read = parseProposals(
      encodeProposals([
        CoachProposal.ofNote(
          const NoteProposal(
            id: 4,
            text: 'Doel: 100 kg',
            kind: 'goal',
            action: NoteAction.changed,
            first: true,
          ),
        ),
      ]),
    ).single;

    expect(read.kind, ProposalKind.note);
    expect(read.appliedId, '4');
    expect(read.note!.text, 'Doel: 100 kg');
    expect(read.note!.action, NoteAction.changed);
    expect(read.note!.first, isTrue);
  });
}
