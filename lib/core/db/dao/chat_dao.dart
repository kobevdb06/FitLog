import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';

part 'chat_dao.drift.dart';

/// The conversations with the coach.
///
/// Nothing here is read unless the user has entered an API key: without one
/// the coach does not exist, and these tables stay empty for the whole life of
/// the app.
@DriftAccessor(
  tables: [
    ChatThreadsTable,
    ChatMessagesTable,
    MorningReportsTable,
    WeekReviewsTable,
  ],
)
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

  /// [workoutId] makes it the conversation of that workout.
  Future<void> createThread(
    String id,
    String title, {
    String? workoutId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(chatThreadsTable).insert(
      ChatThreadsTableCompanion.insert(
        id: id,
        title: _shorten(title),
        createdAt: now,
        updatedAt: now,
        workoutId: Value(workoutId),
      ),
    );
  }

  Future<bool> threadExists(String id) async =>
      await (select(
        chatThreadsTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull() !=
      null;

  /// The conversation of a workout - the newest, should there be two.
  Future<ChatThreadRow?> threadForWorkout(String workoutId) =>
      (select(chatThreadsTable)
            ..where((t) => t.workoutId.equals(workoutId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// The conversation of a workout, made as [id] with [title] when it has
  /// none yet - in one go, so the island and the Chat tab asking at once
  /// still end up in one conversation.
  Future<String> workoutThread({
    required String workoutId,
    required String id,
    required String title,
  }) => transaction(() async {
    final existing = await threadForWorkout(workoutId);
    if (existing != null) return existing.id;
    await createThread(id, title, workoutId: workoutId);
    return id;
  });

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
    List<String> imageFiles = const [],
    String? proposals,
    int? requests,
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
          imageFiles: Value(jsonEncode(imageFiles)),
          proposals: Value(proposals),
          requests: Value(requests),
          inputTokens: Value(inputTokens),
          outputTokens: Value(outputTokens),
          createdAt: now,
        ),
      );
      await (update(chatThreadsTable)..where((t) => t.id.equals(threadId)))
          .write(ChatThreadsTableCompanion(updatedAt: Value(now)));
    });
  }

  /// Rewrites the proposals of one message, which is how a card remembers
  /// that you already tapped it.
  Future<void> setProposals(String messageId, String json) async {
    await (update(chatMessagesTable)..where((t) => t.id.equals(messageId)))
        .write(ChatMessagesTableCompanion(proposals: Value(json)));
  }

  /// Adds what a side call cost to the answer that caused it.
  ///
  /// The daily bar counts what leaves the app, and a request that was made
  /// because of this answer belongs on this answer - otherwise the number in
  /// the settings is quietly lower than the truth.
  Future<void> addUsage(
    String messageId, {
    int requests = 1,
    int inputTokens = 0,
    int outputTokens = 0,
  }) async {
    await customUpdate(
      'UPDATE chat_messages SET requests = COALESCE(requests, 1) + ?, '
      'input_tokens = COALESCE(input_tokens, 0) + ?, '
      'output_tokens = COALESCE(output_tokens, 0) + ? WHERE id = ?',
      variables: [
        Variable.withInt(requests),
        Variable.withInt(inputTokens),
        Variable.withInt(outputTokens),
        Variable.withString(messageId),
      ],
      updates: {chatMessagesTable},
    );
  }

  /// A name you chose. Kept as typed, only trimmed; nothing empty.
  Future<void> renameThread(String id, String title) async {
    final clean = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return;
    await (update(chatThreadsTable)..where((t) => t.id.equals(id))).write(
      ChatThreadsTableCompanion(
        title: Value(
          clean.length > titleLength ? clean.substring(0, titleLength) : clean,
        ),
      ),
    );
  }

  /// The conversations whose name or messages hold [query], the newest
  /// first.
  Future<List<ChatThreadRow>> searchThreads(String query) async {
    final words = query.trim();
    if (words.isEmpty) return const [];
    // What is typed is looked for as it is: % and _ are no wildcards here.
    final pattern =
        '%${words.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await customSelect(
      'SELECT t.* FROM chat_threads t '
      r"WHERE t.title LIKE ?1 ESCAPE '\' "
      'OR EXISTS (SELECT 1 FROM chat_messages m WHERE m.thread_id = t.id '
      r"AND m.content LIKE ?1 ESCAPE '\') "
      'ORDER BY t.updated_at DESC LIMIT 40',
      variables: [Variable.withString(pattern)],
      readsFrom: {chatThreadsTable, chatMessagesTable},
    ).get();
    return [for (final row in rows) chatThreadsTable.map(row.data)];
  }

  Future<void> deleteThread(String id) async {
    await (delete(chatThreadsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Everything, for the button in the settings that means everything.
  Future<void> deleteAllThreads() async {
    await delete(chatMessagesTable).go();
    await delete(chatThreadsTable).go();
  }

  /// Every answer since a moment, from the chat and from the morning
  /// reports alike: a report the coach wrote is a request on the same key,
  /// and the daily bar has to count it.
  static const String _usageSql =
      'SELECT COUNT(*) AS answers, '
      'COALESCE(SUM(requests), 0) AS requests, '
      'COALESCE(SUM(input_tokens), 0) AS input_tokens, '
      'COALESCE(SUM(output_tokens), 0) AS output_tokens FROM ('
      'SELECT COALESCE(requests, 1) AS requests, '
      'COALESCE(input_tokens, 0) AS input_tokens, '
      'COALESCE(output_tokens, 0) AS output_tokens '
      "FROM chat_messages WHERE role = 'assistant' AND created_at >= ? "
      'UNION ALL '
      'SELECT requests, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0) '
      'FROM morning_reports WHERE requests IS NOT NULL AND created_at >= ? '
      'UNION ALL '
      'SELECT requests, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0) '
      'FROM week_reviews WHERE requests IS NOT NULL AND created_at >= ?'
      ')';

  /// What was spent since [since]: calls, answers and tokens.
  ///
  /// An answer from before the app counted calls has no number; it is read as
  /// one, which is the least it can have been.
  Future<({int requests, int answers, int inputTokens, int outputTokens})>
  usageSince(DateTime since) async {
    final row = await customSelect(
      _usageSql,
      variables: [
        Variable.withInt(since.millisecondsSinceEpoch),
        Variable.withInt(since.millisecondsSinceEpoch),
        Variable.withInt(since.millisecondsSinceEpoch),
      ],
      readsFrom: {chatMessagesTable, morningReportsTable, weekReviewsTable},
    ).getSingle();

    return (
      requests: row.read<int>('requests'),
      answers: row.read<int>('answers'),
      inputTokens: row.read<int>('input_tokens'),
      outputTokens: row.read<int>('output_tokens'),
    );
  }

  /// The same, as a stream, so the settings screen follows a conversation
  /// happening in the other tab.
  Stream<({int requests, int answers, int inputTokens, int outputTokens})>
  watchUsageSince(DateTime since) =>
      customSelect(
        _usageSql,
        variables: [
          Variable.withInt(since.millisecondsSinceEpoch),
          Variable.withInt(since.millisecondsSinceEpoch),
          Variable.withInt(since.millisecondsSinceEpoch),
        ],
        readsFrom: {chatMessagesTable, morningReportsTable, weekReviewsTable},
      ).watchSingle().map(
        (row) => (
          requests: row.read<int>('requests'),
          answers: row.read<int>('answers'),
          inputTokens: row.read<int>('input_tokens'),
          outputTokens: row.read<int>('output_tokens'),
        ),
      );

  /// Every photo a conversation points at, so the startup reconcile does not
  /// take them for orphans and delete them.
  Future<Set<String>> imageFileNames() async {
    final rows = await customSelect(
      'SELECT image_file AS one, image_files AS more FROM chat_messages '
      "WHERE image_file IS NOT NULL OR image_files != '[]'",
      readsFrom: {chatMessagesTable},
    ).get();
    return {
      for (final row in rows) ...[
        ?row.readNullable<String>('one'),
        ...decodeImageFiles(row.read<String>('more')),
      ],
    };
  }

  Future<int> countThreads() async {
    final count = chatThreadsTable.id.count();
    final row = await (selectOnly(
      chatThreadsTable,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}

/// The photos sent with a message, in the order they were picked: the one
/// a question from before v49 kept in its own column, or the list of a newer
/// one.
extension ChatMessagePhotos on ChatMessageRow {
  List<String> get photos => [?imageFile, ...decodeImageFiles(imageFiles)];
}

/// The photos of a message, from the JSON its row stores them as.
///
/// Damaged JSON is no photos rather than an error: a picture that cannot be
/// found back should cost the picture, not the conversation.
List<String> decodeImageFiles(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final name in decoded)
        if (name is String && name.isNotEmpty) name,
    ];
  } on FormatException {
    return const [];
  }
}
