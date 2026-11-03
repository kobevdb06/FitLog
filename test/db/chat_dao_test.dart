import 'package:fitlog/core/db/dao/chat_dao.dart';
import 'package:fitlog/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/helpers.dart';

/// Where the conversations with the coach are kept.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.settingsDao.ensureInitialized();
  });

  tearDown(() async {
    await db.close();
  });

  test('an app that was never given a key has no key', () async {
    expect(await db.settingsDao.apiKey(), isNull);
  });

  test('a key is kept, and blanking it is clearing it', () async {
    await db.settingsDao.setApiKey('  sk-ant-test  ');
    expect(await db.settingsDao.apiKey(), 'sk-ant-test');

    await db.settingsDao.setApiKey('   ');
    expect(await db.settingsDao.apiKey(), isNull);

    await db.settingsDao.setApiKey('sk-ant-test');
    await db.settingsDao.setApiKey(null);
    expect(await db.settingsDao.apiKey(), isNull);
  });

  test('a thread is named after the question that started it', () async {
    await db.chatDao.createThread('t-1', '  Hoeveel   sets  voor borst?  ');

    final thread = (await db.chatDao.newestThread())!;
    expect(thread.title, 'Hoeveel sets voor borst?');
  });

  test('and a long question is cut at a word, not mid-syllable', () async {
    await db.chatDao.createThread(
      't-1',
      'Ik wil weten of het verstandig is om mijn bankdrukken deze week te '
          'verzwaren terwijl mijn schouder nog wat zeurt',
    );

    final thread = (await db.chatDao.newestThread())!;
    expect(thread.title.length, lessThanOrEqualTo(ChatDao.titleLength + 1));
    expect(thread.title, endsWith('…'));
    expect(thread.title, isNot(contains('  ')));
  });

  test('messages come back in the order they were said', () async {
    await db.chatDao.createThread('t-1', 'Vraag');
    for (final (id, role, text) in [
      ('m-1', 'user', 'Hoeveel sets?'),
      ('m-2', 'assistant', 'Tussen 10 en 20 per week.'),
      ('m-3', 'user', 'En voor rug?'),
    ]) {
      await db.chatDao.addMessage(
        id: id,
        threadId: 't-1',
        role: role,
        content: text,
      );
    }

    final messages = await db.chatDao.messages('t-1');
    expect(messages.map((m) => m.id), ['m-1', 'm-2', 'm-3']);
    expect(messages.first.role, 'user');
  });

  test('an answer remembers what it looked up and what it cost', () async {
    await db.chatDao.createThread('t-1', 'Vraag');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Je bench staat stil.',
      lookups: '["je laatste 5 sessies","je records voor Bench Press"]',
      inputTokens: 1200,
      outputTokens: 300,
    );

    final message = (await db.chatDao.messages('t-1')).single;
    expect(message.lookups, contains('records'));
    expect(message.inputTokens, 1200);
    expect(message.outputTokens, 300);
  });

  test('deleting a thread takes its messages with it', () async {
    await db.chatDao.createThread('t-1', 'Vraag');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'user',
      content: 'Hoi',
    );

    await db.chatDao.deleteThread('t-1');

    expect(await db.chatDao.countThreads(), 0);
    expect(await db.chatDao.messages('t-1'), isEmpty);
  });

  test('and wissen leaves nothing behind at all', () async {
    for (final id in ['t-1', 't-2']) {
      await db.chatDao.createThread(id, 'Vraag $id');
      await db.chatDao.addMessage(
        id: 'm-$id',
        threadId: id,
        role: 'user',
        content: 'Hoi',
      );
    }

    final folder = (await db.chatDao.folderNamed('Techniek'))!;
    await db.chatDao.moveToFolder('t-1', folder);

    await db.chatDao.deleteAllThreads();

    expect(await db.chatDao.countThreads(), 0);
    expect(await db.chatDao.messages('t-1'), isEmpty);
    expect(await db.chatDao.messages('t-2'), isEmpty);
    expect(await db.chatDao.folders(), isEmpty);
  });

  test('what a conversation cost is what its answers cost', () async {
    await db.chatDao.createThread('t-1', 'Vraag');
    await db.chatDao.createThread('t-2', 'Andere');
    await db.chatDao.addMessage(
      id: 'q-1',
      threadId: 't-1',
      role: 'user',
      content: 'Hoi',
    );
    await db.chatDao.addMessage(
      id: 'a-1',
      threadId: 't-1',
      role: 'assistant',
      content: 'Hallo',
      requests: 3,
      inputTokens: 1000,
      outputTokens: 40,
    );
    // From before calls were counted: one.
    await db.chatDao.addMessage(
      id: 'a-2',
      threadId: 't-1',
      role: 'assistant',
      content: 'Nog eens',
    );
    await db.chatDao.addMessage(
      id: 'a-3',
      threadId: 't-2',
      role: 'assistant',
      content: 'Elders',
      requests: 5,
    );

    final usage = await db.chatDao.threadUsage('t-1');
    expect(usage.answers, 2);
    expect(usage.requests, 4);
    expect(usage.inputTokens, 1000);
    expect(usage.outputTokens, 40);
    expect((await db.chatDao.threadUsage('t-3')).answers, 0);
  });

  group('pinned and in folders', () {
    test('pinning and moving change nothing about when it was last added '
        'to', () async {
      await db.chatDao.createThread('t-1', 'Mijn knie');
      final before = (await db.chatDao.thread('t-1'))!.updatedAt;
      final folder = (await db.chatDao.folderNamed('Techniek'))!;

      await db.chatDao.setPinned('t-1', true);
      await db.chatDao.moveToFolder('t-1', folder);
      var thread = (await db.chatDao.thread('t-1'))!;
      expect(thread.pinned, isTrue);
      expect(thread.folderId, folder);
      expect(thread.updatedAt, before);

      await db.chatDao.setPinned('t-1', false);
      await db.chatDao.moveToFolder('t-1', null);
      thread = (await db.chatDao.thread('t-1'))!;
      expect(thread.pinned, isFalse);
      expect(thread.folderId, isNull);
    });

    test('a folder by a name there is, is that folder', () async {
      final first = await db.chatDao.folderNamed('  Techniek ');
      final again = await db.chatDao.folderNamed('techniek');
      final other = await db.chatDao.folderNamed('Voeding');

      expect(again, first);
      expect(other, isNot(first));
      expect(
        [for (final f in await db.chatDao.folders()) f.name],
        ['Techniek', 'Voeding'],
      );
      expect(await db.chatDao.folderNamed('   '), isNull);
      final long = (await db.chatDao.folderNamed('x' * 80))!;
      final folders = await db.chatDao.folders();
      expect(
        folders.firstWhere((f) => f.id == long).name,
        hasLength(ChatDao.folderNameLength),
      );
    });

    test('renaming keeps a name, and nothing is no name', () async {
      final id = (await db.chatDao.folderNamed('Techniek'))!;
      await db.chatDao.renameFolder(id, '  Squat   en deadlift ');
      await db.chatDao.renameFolder(id, '  ');
      expect((await db.chatDao.folders()).single.name, 'Squat en deadlift');
    });

    test('deleting a folder leaves its conversations, in none', () async {
      await db.chatDao.createThread('t-1', 'Squat diepte');
      await db.chatDao.createThread('t-2', 'Deadlift rug');
      final techniek = (await db.chatDao.folderNamed('Techniek'))!;
      final voeding = (await db.chatDao.folderNamed('Voeding'))!;
      await db.chatDao.moveToFolder('t-1', techniek);
      await db.chatDao.moveToFolder('t-2', voeding);

      await db.chatDao.deleteFolder(techniek);

      expect((await db.chatDao.thread('t-1'))!.folderId, isNull);
      expect((await db.chatDao.thread('t-2'))!.folderId, voeding);
      expect((await db.chatDao.folders()).single.id, voeding);
      expect(await db.chatDao.countThreads(), 2);
    });

    test('a folder remembers it was folded shut', () async {
      final id = (await db.chatDao.folderNamed('Techniek'))!;
      expect((await db.chatDao.folders()).single.isCollapsed, isFalse);
      await db.chatDao.setFolderCollapsed(id, true);
      expect((await db.chatDao.folders()).single.isCollapsed, isTrue);
    });
  });

  test('a newer answer moves its thread to the top', () async {
    await db.chatDao.createThread('t-1', 'Oud');
    await db.chatDao.createThread('t-2', 'Nieuw');
    await db.chatDao.addMessage(
      id: 'm-1',
      threadId: 't-1',
      role: 'user',
      content: 'Nog iets',
    );

    expect((await db.chatDao.newestThread())!.id, 't-1');
  });
}
