import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/core_providers.dart';
import '../../progress/presentation/progress_providers.dart';
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
