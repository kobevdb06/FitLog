import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../../core/db/database.dart';
import 'backup_folder.dart';

/// How often a backup is made on its own.
const Duration kAutoBackupEvery = Duration(days: 7);

/// How long after an unlock the weekly backup waits before it starts.
const Duration kAutoBackupDelay = Duration(seconds: 20);

/// How many automatic backups stay in the folder: a few weeks back, without
/// filling the phone with copies of every photo.
const int kAutoBackupsKept = 3;

/// What an automatic backup is called, so it is told apart from anything
/// else in the folder - your own backups included, which it never touches.
const String kAutoBackupPrefix = 'FitLog-auto-';

/// Whether a week has gone by since the last backup, of any kind.
bool autoBackupDue({required int? lastBackupAt, required DateTime now}) =>
    lastBackupAt == null ||
    now.difference(DateTime.fromMillisecondsSinceEpoch(lastBackupAt)) >=
        kAutoBackupEvery;

/// `FitLog-auto-2026-10-07.fitlog`: sorts by date as text.
String autoBackupName(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '$kAutoBackupPrefix${at.year}-${two(at.month)}-${two(at.day)}.fitlog';
}

/// The automatic backups past the newest [kAutoBackupsKept], oldest last.
List<String> autoBackupsToDelete(Iterable<FolderFile> files) {
  final automatic = [
    for (final file in files)
      if (file.name.startsWith(kAutoBackupPrefix) &&
          file.name.endsWith('.fitlog'))
        file.name,
  ]..sort((a, b) => b.compareTo(a));
  return automatic.skip(kAutoBackupsKept).toList();
}

enum AutoBackupOutcome {
  /// No folder picked: automatic backups are off.
  off,

  /// The last backup is less than a week old.
  notDue,

  /// Written to the folder, and the oldest ones beyond the few kept removed.
  made,

  /// The folder could not be written to: gone, or the permission taken back.
  failed,
}

/// Makes the weekly backup in the folder you picked, when one is due.
///
/// Runs when the app is opened and unlocked, with the key at hand - never in
/// the background, where a PIN would keep the database shut.
class AutoBackup {
  AutoBackup({
    required this.db,
    required this.folder,
    required this.createBackup,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final BackupFolder folder;

  /// An encrypted backup in the app's own export folder; stamps the time.
  final Future<File> Function() createBackup;

  final DateTime Function() _clock;

  Future<AutoBackupOutcome> runIfDue() async {
    final settings = await db.settingsDao.getSettings();
    final uri = settings.autoBackupFolder;
    if (uri == null) return AutoBackupOutcome.off;
    final now = _clock();
    if (!autoBackupDue(lastBackupAt: settings.lastBackupAt, now: now)) {
      return AutoBackupOutcome.notDue;
    }
    return _make(uri, now, previousStamp: settings.lastBackupAt);
  }

  /// Makes one now, due or not: the first one, right after you pick a folder.
  Future<AutoBackupOutcome> runNow() async {
    final settings = await db.settingsDao.getSettings();
    final uri = settings.autoBackupFolder;
    if (uri == null) return AutoBackupOutcome.off;
    return _make(uri, _clock(), previousStamp: settings.lastBackupAt);
  }

  Future<AutoBackupOutcome> _make(
    String uri,
    DateTime now, {
    required int? previousStamp,
  }) async {
    final file = await createBackup();
    try {
      await folder.write(uri, autoBackupName(now), file.path);
    } on Object {
      // Not in the folder, so not a backup: the reminder must not go quiet.
      await db.settingsDao.updateSettings(
        AppSettingsTableCompanion(lastBackupAt: Value(previousStamp)),
      );
      return AutoBackupOutcome.failed;
    } finally {
      if (await file.exists()) await file.delete();
    }

    try {
      for (final name in autoBackupsToDelete(await folder.list(uri))) {
        await folder.delete(uri, name);
      }
    } on Object {
      // The backup is there; an old one left behind is no reason to say it
      // failed.
    }
    return AutoBackupOutcome.made;
  }
}
