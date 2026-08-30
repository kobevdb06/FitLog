// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// When the last backup was written, or null if there has never been one.

@ProviderFor(lastBackupAt)
final lastBackupAtProvider = LastBackupAtProvider._();

/// When the last backup was written, or null if there has never been one.

final class LastBackupAtProvider
    extends $FunctionalProvider<DateTime?, DateTime?, DateTime?>
    with $Provider<DateTime?> {
  /// When the last backup was written, or null if there has never been one.
  LastBackupAtProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastBackupAtProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastBackupAtHash();

  @$internal
  @override
  $ProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime? create(Ref ref) {
    return lastBackupAt(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }
}

String _$lastBackupAtHash() => r'e1835c4b3ffd83886ad5653214c64a07ab205ba8';

/// Whether the dashboard should say something about backups.

@ProviderFor(backupReminder)
final backupReminderProvider = BackupReminderProvider._();

/// Whether the dashboard should say something about backups.

final class BackupReminderProvider
    extends $FunctionalProvider<BackupReminder, BackupReminder, BackupReminder>
    with $Provider<BackupReminder> {
  /// Whether the dashboard should say something about backups.
  BackupReminderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupReminderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupReminderHash();

  @$internal
  @override
  $ProviderElement<BackupReminder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupReminder create(Ref ref) {
    return backupReminder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupReminder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupReminder>(value),
    );
  }
}

String _$backupReminderHash() => r'e44e42deb2dc10e4f99bd7a2f3a7ab5079a5530b';
