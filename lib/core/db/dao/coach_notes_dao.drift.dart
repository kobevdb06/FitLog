// dart format width=80
// ignore_for_file: type=lint
part of 'coach_notes_dao.dart';

mixin _$CoachNotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CoachNotesTableTable get coachNotesTable => attachedDatabase.coachNotesTable;
  CoachNotesDaoManager get managers => CoachNotesDaoManager(this);
}

class CoachNotesDaoManager {
  final _$CoachNotesDaoMixin _db;
  CoachNotesDaoManager(this._db);
  $$CoachNotesTableTableTableManager get coachNotesTable =>
      $$CoachNotesTableTableTableManager(
        _db.attachedDatabase,
        _db.coachNotesTable,
      );
}
