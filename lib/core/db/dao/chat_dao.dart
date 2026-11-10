import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

part 'chat_dao.drift.dart';

const _uuid = Uuid();

/// The conversations with the coach.
///
/// Nothing here is read unless the user has entered an API key: without one
/// the coach does not exist, and these tables stay empty for the whole life of
/// the app.
@DriftAccessor(
  tables: [
    ChatThreadsTable,
    ChatMessagesTable,
    ChatFoldersTable,
    MorningReportsTable,
    WeekReviewsTable,
    WorkoutAnswersTable,
    MomentAnswersTable,
    CoachRequestsTable,
  ],
)
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  /// How much of a first question becomes the name of a thread.
  static const int titleLength = 60;

  /// How long the name of a folder can be: it has to fit in the panel.
  static const int folderNameLength = 40;

  Stream<List<ChatThreadRow>> watchThreads() => (select(
    chatThreadsTable,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<ChatThreadRow?> newestThread() =>
      (select(chatThreadsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// [workoutId] makes it the conversation of that workout, [planId] the
  /// one of that schema.
  Future<void> createThread(
    String id,
    String title, {
    String? workoutId,
    String? planId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(chatThreadsTable).insert(
      ChatThreadsTableCompanion.insert(
        id: id,
        title: _shorten(title),
        createdAt: now,
        updatedAt: now,
        workoutId: Value(workoutId),
        planId: Value(planId),
      ),
    );
  }

  /// The conversation of a schema: where it was made and is talked over.
  Future<ChatThreadRow?> threadForPlan(String planId) =>
      (select(chatThreadsTable)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// The conversations of the schema's, the last added to first.
  Stream<List<ChatThreadRow>> watchPlanThreads() =>
      (select(chatThreadsTable)
            ..where((t) => t.planId.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// Every message in the conversation of a schema, the oldest first.
  Stream<List<ChatMessageRow>> watchPlanMessages(String planId) =>
      customSelect(
        'SELECT m.* FROM chat_messages m '
        'JOIN chat_threads t ON t.id = m.thread_id '
        'WHERE t.plan_id = ? ORDER BY m.created_at',
        variables: [Variable.withString(planId)],
        readsFrom: {chatMessagesTable, chatThreadsTable},
      ).watch().map(
        (rows) => [for (final row in rows) chatMessagesTable.map(row.data)],
      );

  /// The conversation of a schema is called what the schema is.
  Future<void> renamePlanThread(String planId, String title) async {
    final clean = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return;
    await (update(chatThreadsTable)..where((t) => t.planId.equals(planId)))
        .write(ChatThreadsTableCompanion(title: Value(_shorten(clean))));
  }

  Future<ChatThreadRow?> thread(String id) => (select(
    chatThreadsTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

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

  /// Everything, for the button in the settings that means everything: the
  /// folders too, which were only there to keep conversations in.
  Future<void> deleteAllThreads() async {
    await delete(chatMessagesTable).go();
    await delete(chatThreadsTable).go();
    await delete(chatFoldersTable).go();
  }

  /// Pinned at the top of the panel, or not any more. The order of the rest
  /// does not change: that is the last time something was said.
  Future<void> setPinned(String threadId, bool pinned) async {
    await (update(chatThreadsTable)..where((t) => t.id.equals(threadId))).write(
      ChatThreadsTableCompanion(pinned: Value(pinned)),
    );
  }

  /// Into the folder [folderId], or out of the one it is in with null.
  Future<void> moveToFolder(String threadId, String? folderId) async {
    await (update(chatThreadsTable)..where((t) => t.id.equals(threadId))).write(
      ChatThreadsTableCompanion(folderId: Value(folderId)),
    );
  }

  /// The folders, in the order they were made.
  Stream<List<ChatFolderRow>> watchFolders() => (select(
    chatFoldersTable,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Future<List<ChatFolderRow>> folders() => (select(
    chatFoldersTable,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  /// The folder called [name], made now when there is none: two folders by
  /// one name would only be confusing. Null for a name that is nothing.
  Future<String?> folderNamed(String name) => transaction(() async {
    final clean = _folderName(name);
    if (clean == null) return null;
    for (final folder in await folders()) {
      if (folder.name.toLowerCase() == clean.toLowerCase()) return folder.id;
    }
    final id = _uuid.v4();
    final max = chatFoldersTable.sortOrder.max();
    final row = await (selectOnly(
      chatFoldersTable,
    )..addColumns([max])).getSingle();
    await into(chatFoldersTable).insert(
      ChatFoldersTableCompanion.insert(
        id: id,
        name: clean,
        sortOrder: (row.read(max) ?? -1) + 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return id;
  });

  /// A name you chose, trimmed; nothing empty.
  Future<void> renameFolder(String id, String name) async {
    final clean = _folderName(name);
    if (clean == null) return;
    await (update(chatFoldersTable)..where((t) => t.id.equals(id))).write(
      ChatFoldersTableCompanion(name: Value(clean)),
    );
  }

  Future<void> setFolderCollapsed(String id, bool collapsed) async {
    await (update(chatFoldersTable)..where((t) => t.id.equals(id))).write(
      ChatFoldersTableCompanion(isCollapsed: Value(collapsed)),
    );
  }

  /// The folder goes; the conversations in it stay, in none.
  Future<void> deleteFolder(String id) => transaction(() async {
    await (update(chatThreadsTable)..where((t) => t.folderId.equals(id))).write(
      const ChatThreadsTableCompanion(folderId: Value(null)),
    );
    await (delete(chatFoldersTable)..where((t) => t.id.equals(id))).go();
  });

  static String? _folderName(String name) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return null;
    return clean.length > folderNameLength
        ? clean.substring(0, folderNameLength)
        : clean;
  }

  /// Every answer since a moment, from the chat, the morning reports, the
  /// weeks and the workouts alike: a report the coach wrote is a request on
  /// the same key, and the daily bar has to count it.
  ///
  /// The requests are the higher of what the answers say and what was
  /// counted as it was sent: a request that failed, or a conversation
  /// deleted since, is in the second (DECISIONS 249).
  static const String _usageSql =
      'SELECT COUNT(*) AS answers, '
      'MAX(COALESCE(SUM(requests), 0), '
      '(SELECT COUNT(*) FROM coach_requests WHERE at >= ?)) AS requests, '
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
      'FROM week_reviews WHERE requests IS NOT NULL AND created_at >= ? '
      'UNION ALL '
      'SELECT requests, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0) '
      'FROM workout_answers WHERE requests IS NOT NULL AND created_at >= ? '
      'UNION ALL '
      'SELECT requests, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0) '
      'FROM moment_answers WHERE requests IS NOT NULL AND created_at >= ?'
      ')';

  /// One [since] for each part of [_usageSql].
  static List<Variable<int>> _usageVariables(DateTime since) => [
    for (var i = 0; i < 6; i++) Variable.withInt(since.millisecondsSinceEpoch),
  ];

  /// How long a counted request is kept: a day limit needs no more than the
  /// day, wherever the service's day begins.
  static const Duration _requestsKept = Duration(days: 3);

  /// One request to the coach's service, counted as it is sent.
  Future<void> noteRequest(DateTime at) => transaction(() async {
    await into(
      coachRequestsTable,
    ).insert(CoachRequestsTableCompanion.insert(at: at.millisecondsSinceEpoch));
    await (delete(coachRequestsTable)..where(
          (t) => t.at.isSmallerThanValue(
            at.subtract(_requestsKept).millisecondsSinceEpoch,
          ),
        ))
        .go();
  });

  Set<TableInfo> get _usageTables => {
    coachRequestsTable,
    chatMessagesTable,
    morningReportsTable,
    weekReviewsTable,
    workoutAnswersTable,
    momentAnswersTable,
  };

  /// What was spent since [since]: calls, answers and tokens.
  ///
  /// An answer from before the app counted calls has no number; it is read as
  /// one, which is the least it can have been.
  Future<({int requests, int answers, int inputTokens, int outputTokens})>
  usageSince(DateTime since) async {
    final row = await customSelect(
      _usageSql,
      variables: _usageVariables(since),
      readsFrom: _usageTables,
    ).getSingle();

    return (
      requests: row.read<int>('requests'),
      answers: row.read<int>('answers'),
      inputTokens: row.read<int>('input_tokens'),
      outputTokens: row.read<int>('output_tokens'),
    );
  }

  /// What the answers in one conversation cost: calls, answers and tokens.
  /// An answer from before the app counted calls is read as one, as above.
  Future<({int requests, int answers, int inputTokens, int outputTokens})>
  threadUsage(String threadId) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS answers, '
      'COALESCE(SUM(COALESCE(requests, 1)), 0) AS requests, '
      'COALESCE(SUM(COALESCE(input_tokens, 0)), 0) AS input_tokens, '
      'COALESCE(SUM(COALESCE(output_tokens, 0)), 0) AS output_tokens '
      "FROM chat_messages WHERE thread_id = ? AND role = 'assistant'",
      variables: [Variable.withString(threadId)],
      readsFrom: {chatMessagesTable},
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
        variables: _usageVariables(since),
        readsFrom: _usageTables,
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
