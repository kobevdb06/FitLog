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

/// Makes an encrypted backup in the app's own export folder, with the key of
/// the open database and the recovery phrase it is wrapped with. The one way
/// a backup is made, by hand or every week.
///
/// Kept alive: the backup is made long after it is asked for - the weekly
/// one waits for the app to settle - and by then nobody is watching. An
/// auto-disposed provider was gone at that moment, and its ref with it.

@ProviderFor(backupMaker)
final backupMakerProvider = BackupMakerProvider._();

/// Makes an encrypted backup in the app's own export folder, with the key of
/// the open database and the recovery phrase it is wrapped with. The one way
/// a backup is made, by hand or every week.
///
/// Kept alive: the backup is made long after it is asked for - the weekly
/// one waits for the app to settle - and by then nobody is watching. An
/// auto-disposed provider was gone at that moment, and its ref with it.

final class BackupMakerProvider
    extends
        $FunctionalProvider<
          Future<File> Function(),
          Future<File> Function(),
          Future<File> Function()
        >
    with $Provider<Future<File> Function()> {
  /// Makes an encrypted backup in the app's own export folder, with the key of
  /// the open database and the recovery phrase it is wrapped with. The one way
  /// a backup is made, by hand or every week.
  ///
  /// Kept alive: the backup is made long after it is asked for - the weekly
  /// one waits for the app to settle - and by then nobody is watching. An
  /// auto-disposed provider was gone at that moment, and its ref with it.
  BackupMakerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupMakerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupMakerHash();

  @$internal
  @override
  $ProviderElement<Future<File> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<File> Function() create(Ref ref) {
    return backupMaker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<File> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<File> Function()>(value),
    );
  }
}

String _$backupMakerHash() => r'710eb423f344983c8f479da0b625f89bbf2900ff';

/// The folder you picked for the weekly backup, on Android's terms.

@ProviderFor(backupFolder)
final backupFolderProvider = BackupFolderProvider._();

/// The folder you picked for the weekly backup, on Android's terms.

final class BackupFolderProvider
    extends $FunctionalProvider<BackupFolder, BackupFolder, BackupFolder>
    with $Provider<BackupFolder> {
  /// The folder you picked for the weekly backup, on Android's terms.
  BackupFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupFolderHash();

  @$internal
  @override
  $ProviderElement<BackupFolder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupFolder create(Ref ref) {
    return backupFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupFolder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupFolder>(value),
    );
  }
}

String _$backupFolderHash() => r'ebfdbdaf4628f7fd623e2de84629757b043bd592';

/// The weekly backup into that folder. Kept alive, for the same reason.

@ProviderFor(autoBackup)
final autoBackupProvider = AutoBackupProvider._();

/// The weekly backup into that folder. Kept alive, for the same reason.

final class AutoBackupProvider
    extends $FunctionalProvider<AutoBackup, AutoBackup, AutoBackup>
    with $Provider<AutoBackup> {
  /// The weekly backup into that folder. Kept alive, for the same reason.
  AutoBackupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoBackupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoBackupHash();

  @$internal
  @override
  $ProviderElement<AutoBackup> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AutoBackup create(Ref ref) {
    return autoBackup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AutoBackup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AutoBackup>(value),
    );
  }
}

String _$autoBackupHash() => r'f4f98d7984aba20c94bf96d5bd708c2ca1d04340';

/// What the folder is called, or null when it is gone or no longer ours.

@ProviderFor(autoBackupFolderName)
final autoBackupFolderNameProvider = AutoBackupFolderNameFamily._();

/// What the folder is called, or null when it is gone or no longer ours.

final class AutoBackupFolderNameProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// What the folder is called, or null when it is gone or no longer ours.
  AutoBackupFolderNameProvider._({
    required AutoBackupFolderNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'autoBackupFolderNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$autoBackupFolderNameHash();

  @override
  String toString() {
    return r'autoBackupFolderNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return autoBackupFolderName(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AutoBackupFolderNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$autoBackupFolderNameHash() =>
    r'155aeb93a2b0e404f646d9a586558205bca2e75e';

/// What the folder is called, or null when it is gone or no longer ours.

final class AutoBackupFolderNameFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  AutoBackupFolderNameFamily._()
    : super(
        retry: null,
        name: r'autoBackupFolderNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the folder is called, or null when it is gone or no longer ours.

  AutoBackupFolderNameProvider call(String uri) =>
      AutoBackupFolderNameProvider._(argument: uri, from: this);

  @override
  String toString() => r'autoBackupFolderNameProvider';
}
