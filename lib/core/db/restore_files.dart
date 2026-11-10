import 'dart:io';

import '../util/paths.dart';
import 'connection.dart';

/// The files a restore moves around, and how a restore that stopped halfway
/// is put right (DECISIONS 242).
///
/// Next to `fitlog.db` and `photos` stand, during a restore, the backup's
/// (`.restore-tmp`) and the ones it replaces (`.pre-restore`). Which of the
/// three databases the key there is opens decides which is kept.
class RestoreFiles {
  RestoreFiles(this.paths);

  final AppPaths paths;

  File get live => paths.databaseFile;
  File get stagedDatabase => File('${live.path}.restore-tmp');
  File get previousDatabase => File('${live.path}.pre-restore');
  Directory get stagedPhotos =>
      Directory('${paths.photosDirectory.path}.restore-tmp');
  Directory get previousPhotos =>
      Directory('${paths.photosDirectory.path}.pre-restore');

  /// What SQLite keeps next to a database: its journal, or its log and
  /// shared memory. A journal left beside a file it does not belong to is
  /// played back into that file, so they move with their database.
  static const List<String> sidecars = ['-journal', '-wal', '-shm'];

  /// The backup's files put where the app's were; the app's kept beside.
  Future<void> swap() async {
    await _deleteDatabase(previousDatabase);
    await _deleteDirectory(previousPhotos);
    await _moveDatabase(live, previousDatabase);
    if (await paths.photosDirectory.exists()) {
      await paths.photosDirectory.rename(previousPhotos.path);
    }
    await _moveDatabase(stagedDatabase, live);
    if (await stagedPhotos.exists()) {
      await stagedPhotos.rename(paths.photosDirectory.path);
    }
  }

  Future<void> discardStaged() async {
    await _deleteDatabase(stagedDatabase);
    await _deleteDirectory(stagedPhotos);
  }

  /// Whether anything of a restore is still around.
  Future<bool> get pending async =>
      await stagedDatabase.exists() ||
      await previousDatabase.exists() ||
      await stagedPhotos.exists() ||
      await previousPhotos.exists();

  /// Before the database is opened with [keyHex]: a restore that stopped
  /// halfway is finished, or undone, by which database that key opens.
  ///
  /// - The app's own: whatever is beside it goes - a restore that finished,
  ///   or one that never got as far as the keys.
  /// - The one it replaced: the restore stopped before the keys changed, and
  ///   is undone.
  /// - The backup's, still beside: the keys changed but the files did not
  ///   move yet, and it is finished.
  ///
  /// When the key opens none of them, nothing is touched.
  Future<void> settle(
    String keyHex, {
    bool Function(File file, String keyHex) opens = keyOpensDatabase,
  }) async {
    if (!await pending) return;
    bool opensWithKey(File file) =>
        file.existsSync() && _tryOpens(opens, file, keyHex);

    if (opensWithKey(live)) {
      await discardStaged();
      await _deleteDatabase(previousDatabase);
      await _deleteDirectory(previousPhotos);
    } else if (opensWithKey(previousDatabase)) {
      await _deleteDatabase(live);
      await _moveDatabase(previousDatabase, live);
      if (await previousPhotos.exists()) {
        await _deleteDirectory(paths.photosDirectory);
        await previousPhotos.rename(paths.photosDirectory.path);
      }
      await discardStaged();
    } else if (opensWithKey(stagedDatabase)) {
      await _deleteDatabase(live);
      await _moveDatabase(stagedDatabase, live);
      if (await stagedPhotos.exists()) {
        await _deleteDirectory(paths.photosDirectory);
        await stagedPhotos.rename(paths.photosDirectory.path);
      }
      await _deleteDatabase(previousDatabase);
      await _deleteDirectory(previousPhotos);
    }
  }

  static bool _tryOpens(
    bool Function(File file, String keyHex) opens,
    File file,
    String keyHex,
  ) {
    try {
      return opens(file, keyHex);
    } on Object {
      return false;
    }
  }

  static Future<void> _moveDatabase(File from, File to) async {
    if (!await from.exists()) return;
    await from.rename(to.path);
    for (final suffix in sidecars) {
      final side = File('${from.path}$suffix');
      if (await side.exists()) await side.rename('${to.path}$suffix');
    }
  }

  static Future<void> _deleteDatabase(File file) async {
    for (final suffix in ['', ...sidecars]) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  static Future<void> _deleteDirectory(Directory dir) async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
