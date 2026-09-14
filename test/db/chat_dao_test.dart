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

    await db.chatDao.deleteAllThreads();

    expect(await db.chatDao.countThreads(), 0);
    expect(await db.chatDao.messages('t-1'), isEmpty);
    expect(await db.chatDao.messages('t-2'), isEmpty);
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
