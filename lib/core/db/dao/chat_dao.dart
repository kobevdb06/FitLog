import 'package:drift/drift.dart';

import '../database.dart';

part 'chat_dao.drift.dart';

/// The conversations with the coach.
///
/// Nothing here is read unless the user has entered an API key: without one
/// the coach does not exist, and these tables stay empty for the whole life of
/// the app.
@DriftAccessor(tables: [ChatThreadsTable, ChatMessagesTable])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  /// How much of a first question becomes the name of a thread.
  static const int titleLength = 60;

  Stream<List<ChatThreadRow>> watchThreads() => (select(
    chatThreadsTable,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<ChatThreadRow?> newestThread() =>
      (select(chatThreadsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> createThread(String id, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(chatThreadsTable).insert(
      ChatThreadsTableCompanion.insert(
        id: id,
        title: _shorten(title),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// The name of a thread is the question that started it, cut at a word.
  static String _shorten(String title) {
    final clean = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= titleLength) {
      return clean.isEmpty ? 'Nieuw gesprek' : clean;
    }
    final cut = clean.lastIndexOf(' ', titleLength);
    return '${clean.substring(0, cut < 20 ? titleLength : cut)}…';
  }

  Stream<List<ChatMessageRow>> watchMessages(String threadId) =>
      (select(chatMessagesTable)
            ..where((t) => t.threadId.equals(threadId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<List<ChatMessageRow>> messages(String threadId) =>
      (select(chatMessagesTable)
            ..where((t) => t.threadId.equals(threadId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> addMessage({
    required String id,
    required String threadId,
    required String role,
    required String content,
    String? lookups,
    String? imageFile,
    int? inputTokens,
    int? outputTokens,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await into(chatMessagesTable).insert(
        ChatMessagesTableCompanion.insert(
          id: id,
          threadId: threadId,
          role: role,
          content: content,
          lookups: Value(lookups),
          imageFile: Value(imageFile),
          inputTokens: Value(inputTokens),
          outputTokens: Value(outputTokens),
          createdAt: now,
        ),
      );
      await (update(chatThreadsTable)..where((t) => t.id.equals(threadId)))
          .write(ChatThreadsTableCompanion(updatedAt: Value(now)));
    });
  }

  Future<void> deleteThread(String id) async {
    await (delete(chatThreadsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Everything, for the button in the settings that means everything.
  Future<void> deleteAllThreads() async {
    await delete(chatMessagesTable).go();
    await delete(chatThreadsTable).go();
  }

  /// Every photo a conversation points at, so the startup reconcile does not
  /// take them for orphans and delete them.
  Future<Set<String>> imageFileNames() async {
    final rows = await customSelect(
      'SELECT image_file AS f FROM chat_messages WHERE image_file IS NOT NULL',
      readsFrom: {chatMessagesTable},
    ).get();
    return {for (final row in rows) row.read<String>('f')};
  }

  Future<int> countThreads() async {
    final count = chatThreadsTable.id.count();
    final row = await (selectOnly(
      chatThreadsTable,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}
