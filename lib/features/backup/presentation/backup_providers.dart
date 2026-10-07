import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/providers/core_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../data/auto_backup.dart';
import '../data/backup_folder.dart';
import '../data/backup_service.dart';
import '../domain/backup_reminder.dart';

part 'backup_providers.g.dart';

/// When the last backup was written, or null if there has never been one.
@riverpod
DateTime? lastBackupAt(Ref ref) {
  final stamp = ref.watch(settingsProvider).value?.lastBackupAt;
  return stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp);
}

/// Whether the dashboard should say something about backups.
@riverpod
BackupReminder backupReminder(Ref ref) {
  final stats = ref.watch(lifetimeStatsProvider).value;
  if (stats == null) return BackupReminder.none;

  return backupReminderFor(
    lastBackupAt: ref.watch(lastBackupAtProvider),
    workoutCount: stats.workouts,
  );
}

/// Makes an encrypted backup in the app's own export folder, with the key of
/// the open database and the recovery phrase it is wrapped with. The one way
/// a backup is made, by hand or every week.
///
/// Kept alive: the backup is made long after it is asked for - the weekly
/// one waits for the app to settle - and by then nobody is watching. An
/// auto-disposed provider was gone at that moment, and its ref with it.
@Riverpod(keepAlive: true)
Future<File> Function() backupMaker(Ref ref) => () async {
  final controller = ref.read(appControllerProvider.notifier);
  final manager = ref.read(keyManagerProvider);
  final dek = controller.currentDek ?? await manager.readDirectKey();
  final db = controller.databaseOrNull;
  if (dek == null || db == null) {
    throw StateError('De database is niet open.');
  }

  final phrase = await manager.readRecoveryPhrase(dek);
  if (phrase == null) {
    throw StateError(
      'Er is geen herstelzin op dit toestel, dus de back-up kan niet '
      'versleuteld worden.',
    );
  }

  final paths = await ref.read(appPathsProvider.future);
  return BackupService(
    db: db,
    paths: paths,
  ).createBackup(recoveryPhrase: phrase, dek: dek);
};

/// The folder you picked for the weekly backup, on Android's terms.
@Riverpod(keepAlive: true)
BackupFolder backupFolder(Ref ref) => const AndroidBackupFolder();

/// The weekly backup into that folder. Kept alive, for the same reason.
@Riverpod(keepAlive: true)
AutoBackup autoBackup(Ref ref) => AutoBackup(
  db: ref.watch(databaseProvider),
  folder: ref.watch(backupFolderProvider),
  createBackup: ref.watch(backupMakerProvider),
);

/// What the folder is called, or null when it is gone or no longer ours.
@riverpod
Future<String?> autoBackupFolderName(Ref ref, String uri) =>
    ref.watch(backupFolderProvider).nameOf(uri);

