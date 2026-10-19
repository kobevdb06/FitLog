import 'package:drift/drift.dart';

import '../database.dart';

part 'coach_notes_dao.drift.dart';

/// How many notes the coach keeps, and how long each may be: enough to know
/// someone by, little enough to send along with every question.
const int kCoachNoteMax = 20;
const int kCoachNoteLength = 150;

/// What a note is about - also its icon.
enum CoachNoteKind {
  goal('goal'),
  limit('limit'),
  schedule('schedule'),
  kit('kit'),
  style('style'),
  other('other');

  const CoachNoteKind(this.wire);

  final String wire;

  static CoachNoteKind of(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return other;
  }
}

/// The coach's notebook: what it remembers about you between conversations.
@DriftAccessor(tables: [CoachNotesTable])
class CoachNotesDao extends DatabaseAccessor<AppDatabase>
    with _$CoachNotesDaoMixin {
  CoachNotesDao(super.db);

  SimpleSelectStatement<$CoachNotesTableTable, CoachNoteRow> _all() =>
      select(coachNotesTable)..orderBy([(t) => OrderingTerm.asc(t.id)]);

  /// Every note, the oldest first.
  Stream<List<CoachNoteRow>> watchNotes() => _all().watch();

  Future<List<CoachNoteRow>> notes() => _all().get();

  Future<CoachNoteRow?> note(int id) => (select(
    coachNotesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> count() async {
    final count = coachNotesTable.id.count();
    final row = await (selectOnly(
      coachNotesTable,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// A note as it is kept: one line, trimmed, and never longer than
  /// [kCoachNoteLength].
  static String clean(String text) {
    final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return line.length > kCoachNoteLength
        ? line.substring(0, kCoachNoteLength)
        : line;
  }

  /// Adds a note and returns its number. Whether there is room is for the
  /// caller to check: the coach is told, you are not stopped.
  Future<int> add(
    String text, {
    CoachNoteKind kind = CoachNoteKind.other,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return into(coachNotesTable).insert(
      CoachNotesTableCompanion.insert(
        note: clean(text),
        kind: Value(kind.wire),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  /// Rewrites note [id]; false when there is no such note.
  Future<bool> change(
    int id,
    String text, {
    CoachNoteKind? kind,
    DateTime? now,
  }) async {
    final changed =
        await (update(coachNotesTable)..where((t) => t.id.equals(id))).write(
          CoachNotesTableCompanion(
            note: Value(clean(text)),
            kind: kind == null ? const Value.absent() : Value(kind.wire),
            updatedAt: Value((now ?? DateTime.now()).millisecondsSinceEpoch),
          ),
        );
    return changed > 0;
  }

  /// False when there was no such note.
  Future<bool> forget(int id) async =>
      await (delete(coachNotesTable)..where((t) => t.id.equals(id))).go() > 0;

  Future<void> forgetAll() => delete(coachNotesTable).go();
}
