import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';

part 'routine_providers.g.dart';

@riverpod
Stream<List<RoutineFolderRow>> routineFolders(Ref ref) =>
    ref.watch(databaseProvider).routinesDao.watchFolders();

@riverpod
Stream<List<RoutineSummary>> routineSummaries(Ref ref) =>
    ref.watch(databaseProvider).routinesDao.watchRoutines();

@riverpod
Stream<RoutineDetail?> routineDetail(Ref ref, String routineId) =>
    ref.watch(databaseProvider).routinesDao.watchRoutineDetail(routineId);

/// The routine the dashboard offers to start.
@riverpod
Future<RoutineRow?> suggestedRoutine(Ref ref) =>
    ref.watch(databaseProvider).routinesDao.suggestedRoutine();

// Kept alive on purpose. These objects hold a `Ref` and every one of their
// callers uses them across an async gap: a confirmation dialog, the photo
// picker, the PR configuration screen. An auto-disposing provider is torn down
// while that gap is open, and the next call throws on a dead `Ref`.
@Riverpod(keepAlive: true)
RoutineActions routineActions(Ref ref) => RoutineActions(ref);

/// Every write the routine screens perform.
class RoutineActions {
  const RoutineActions(this.ref);

  final Ref ref;

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> createFolder(String name) =>
      _db.routinesDao.createFolder(name.trim());

  Future<void> renameFolder(String id, String name) =>
      _db.routinesDao.renameFolder(id, name.trim());

  /// The routines inside move to the top level; nothing is lost.
  Future<void> deleteFolder(String id) => _db.routinesDao.deleteFolder(id);

  Future<String> create(RoutineDraft draft) =>
      _db.routinesDao.createRoutine(draft);

  Future<void> update(String routineId, RoutineDraft draft) =>
      _db.routinesDao.updateRoutine(routineId, draft);

  Future<void> delete(String routineId) =>
      _db.routinesDao.deleteRoutine(routineId);

  Future<String> duplicate(String routineId) =>
      _db.routinesDao.duplicateRoutine(routineId);

  Future<void> moveToFolder(String routineId, String? folderId) =>
      _db.routinesDao.setRoutineFolder(routineId, folderId);

  Future<void> reorder(List<String> orderedIds) =>
      _db.routinesDao.reorderRoutines(orderedIds);
}
