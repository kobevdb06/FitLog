/// Whether it is time to remind the user to make a backup.
///
/// Everything this app knows lives in one encrypted file on one phone. Losing
/// the phone loses the lot, and the app would never say a word about it, so it
/// keeps an eye on the clock instead.
library;

/// After this long without a backup, the dashboard says so.
const Duration kBackupReminderAge = Duration(days: 30);

enum BackupReminder {
  /// Nothing to say.
  none,

  /// There is history worth keeping and no backup has ever been made.
  never,

  /// The last backup is older than [kBackupReminderAge].
  stale,
}

/// [workoutCount] is what stops a fresh install from nagging: with nothing
/// logged there is nothing to lose yet.
BackupReminder backupReminderFor({
  required DateTime? lastBackupAt,
  required int workoutCount,
  DateTime? now,
}) {
  if (workoutCount <= 0) return BackupReminder.none;
  if (lastBackupAt == null) return BackupReminder.never;

  final age = (now ?? DateTime.now()).difference(lastBackupAt);
  return age > kBackupReminderAge ? BackupReminder.stale : BackupReminder.none;
}
