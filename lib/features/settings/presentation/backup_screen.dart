import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/security/recovery_phrase.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../backup/data/auto_backup.dart';
import '../../backup/data/backup_service.dart';
import '../../backup/presentation/backup_providers.dart';

/// Making a backup, exporting CSV, and restoring from a `.fitlog` file.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _message;

  /// What the app is doing right now, shown under the progress bar.
  ///
  /// Restoring closes the database, replaces it, rewrites the keys and opens
  /// it again. Any of those can take a moment, and a bar that only spins tells
  /// nobody - not the user and not whoever has to work out where it stopped.
  String? _step;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
      _step = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _step = null;
        });
      }
    }
  }

  /// Names the phase, on screen and in the device log.
  void _at(String step) {
    debugPrint('FitLog restore: $step');
    if (mounted) setState(() => _step = step);
  }

  // --- Backup ---------------------------------------------------------------

  Future<void> _createBackup() => _run(() async {
    final file = await ref.read(backupMakerProvider)();

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'FitLog back-up',
        text:
            'Bewaar dit bestand samen met je herstelzin. Zonder die twaalf '
            'woorden is de back-up niet te openen.',
      ),
    );
    if (mounted) {
      setState(
        () => _message = 'Back-up gemaakt: ${file.uri.pathSegments.last}',
      );
    }
  });

  // --- Every week -----------------------------------------------------------

  /// Picks the folder, and makes the first backup in it right away: seeing
  /// it there is how you know it works.
  Future<void> _pickFolder() => _run(() async {
    final folder = ref.read(backupFolderProvider);
    final previous = ref.read(settingsProvider).value?.autoBackupFolder;
    final picked = await folder.pick();
    if (picked == null) return;
    if (previous != null && previous != picked.uri) {
      await folder.release(previous);
    }
    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          AppSettingsTableCompanion(autoBackupFolder: Value(picked.uri)),
        );
    ref.invalidate(autoBackupFolderNameProvider(picked.uri));

    final outcome = await ref.read(autoBackupProvider).runNow();
    if (!mounted) return;
    setState(
      () => _message = switch (outcome) {
        AutoBackupOutcome.made =>
          'De eerste automatische back-up staat in "${picked.name}". Elke '
              'week komt er een bij.',
        _ =>
          'De map is gekozen, maar er kon niets in geschreven worden. Kies '
              'een andere map.',
      },
    );
  });

  Future<void> _stopAutomatic(String uri) => _run(() async {
    await ref.read(backupFolderProvider).release(uri);
    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          const AppSettingsTableCompanion(autoBackupFolder: Value(null)),
        );
  });

  /// Two confirmations and typing the word, because there is no undo and no
  /// copy anywhere else.
  Future<void> _wipe() async {
    final first = await confirm(
      context,
      title: 'Alle gegevens wissen?',
      message:
          'Je routines, workouts, records, metingen en foto\'s worden van dit '
          'toestel verwijderd. Er is geen kopie elders.',
      confirmLabel: 'Doorgaan',
      destructive: true,
    );
    if (!first || !mounted) return;

    final second = await confirmByTyping(
      context,
      title: 'Zeker weten?',
      message: 'Typ WISSEN om te bevestigen. Dit kan niet ongedaan gemaakt.',
      word: 'WISSEN',
    );
    if (!second) return;

    await ref.read(appControllerProvider.notifier).wipeEverything();
  }

  Future<void> _exportCsv() => _run(() async {
    final controller = ref.read(appControllerProvider.notifier);
    final db = controller.databaseOrNull;
    if (db == null) throw StateError('De database is niet open.');

    final paths = await ref.read(appPathsProvider.future);
    final file = await BackupService(
      db: db,
      paths: paths,
    ).exportCsv(formatters: ref.read(formattersProvider));

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'FitLog workouts (CSV)'),
    );
  });

  // --- Restore --------------------------------------------------------------

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Kies een .fitlog back-up',
    );
    final path = picked?.path;
    if (path == null) return;
    final file = File(path);

    if (!mounted) return;
    final phrase = await promptForText(
      context,
      title: 'Herstelzin',
      hintText: 'de twaalf woorden van deze back-up',
      confirmLabel: 'Openen',
      maxLines: 3,
      capitalization: TextCapitalization.none,
    );
    if (phrase == null || !isValidRecoveryPhrase(phrase)) {
      if (mounted && phrase != null) {
        showSnack(
          context,
          'Dat zijn geen twaalf geldige woorden.',
          isError: true,
        );
      }
      return;
    }

    await _run(() async {
      _at('Back-up openen');
      final backup = await BackupService.readBackup(
        file: file,
        recoveryPhrase: normalizeRecoveryPhrase(phrase),
      );

      if (!mounted) return;
      final first = await confirm(
        context,
        title: 'Huidige gegevens overschrijven?',
        message:
            'Alles wat nu op dit toestel staat wordt vervangen door de '
            'inhoud van de back-up. Dit kan niet ongedaan gemaakt worden.',
        confirmLabel: 'Doorgaan',
        destructive: true,
      );
      if (!first || !mounted) return;

      final second = await confirmByTyping(
        context,
        title: 'Bevestigen',
        message: 'Typ HERSTEL om de back-up terug te zetten.',
        word: 'HERSTEL',
      );
      if (!second) return;

      final controller = ref.read(appControllerProvider.notifier);
      final paths = await ref.read(appPathsProvider.future);
      final manager = ref.read(keyManagerProvider);

      _at('Database sluiten');
      await controller.closeForRestore();

      _at('Gegevens terugzetten');
      await BackupService.applyRestore(backup: backup, paths: paths);

      // The restored database is encrypted with the key from the archive, so
      // every wrapped copy on this device is replaced.
      _at('Sleutels wissen');
      await manager.wipe();

      _at('Herstelzin koppelen');
      await manager.setRecoveryPhrase(
        dek: backup.dek,
        phrase: normalizeRecoveryPhrase(phrase),
      );

      _at('Sleutel opbergen');
      await manager.setDirectKey(backup.dek);

      _at('Database openen');
      await controller.completeSetupWith(backup.dek);
      _at('Klaar');
      if (mounted) {
        setState(
          () => _message =
              'Back-up teruggezet. Er staat nu geen pincode meer op dit '
              'toestel; stel er een in bij Beveiliging.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Back-up en export')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(),
              if (_step != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Text(
                    '${_step!}...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SectionHeader('Elke week'),
            _AutomaticTile(onPick: _pickFolder, onStop: _stopAutomatic),
            const SectionHeader('Back-up'),
            const _LastBackupLine(),
            ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: const Text('Versleutelde back-up maken'),
              subtitle: const Text(
                'Database en foto\'s in een .fitlog-bestand, versleuteld met '
                'je herstelzin.',
              ),
              onTap: _createBackup,
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV-export van workouts'),
              subtitle: const Text(
                'Leesbaar bestand met elke workout en elke set.',
              ),
              onTap: _exportCsv,
            ),
            const SectionHeader('Herstellen'),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Back-up terugzetten'),
              subtitle: const Text(
                'Overschrijft alles wat nu op dit toestel staat.',
              ),
              onTap: _restore,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const InfoBanner(
                    icon: Icons.key_outlined,
                    message:
                        'De back-up is alleen te openen met je twaalf woorden. '
                        'Bewaar ze apart van het bestand.',
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoBanner(
                      icon: Icons.info_outline,
                      color: AppColors.accent,
                      message: _message!,
                    ),
                  ],
                ],
              ),
            ),
            // At the very bottom, past everything you come here for: what
            // cannot be undone does not sit between what you use often.
            const SectionHeader('Gevarenzone'),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AppColors.danger,
              ),
              title: const Text(
                'Alle gegevens wissen',
                style: TextStyle(color: AppColors.danger),
              ),
              subtitle: const Text(
                'Alles van dit toestel verwijderen. Maak eerst een back-up '
                'als je iets wil houden.',
              ),
              onTap: _wipe,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// When the last backup was made, or that there has never been one.
class _LastBackupLine extends ConsumerWidget {
  const _LastBackupLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final at = ref.watch(lastBackupAtProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        at == null
            ? 'Nog geen back-up gemaakt.'
            : 'Laatste back-up: ${Formatters.relativeDayTime(at).toLowerCase()}.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The weekly backup: off, on with the folder it goes to, or on with a
/// folder that is no longer there.
class _AutomaticTile extends ConsumerWidget {
  const _AutomaticTile({required this.onPick, required this.onStop});

  final VoidCallback onPick;
  final ValueChanged<String> onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(settingsProvider).value?.autoBackupFolder;
    if (uri == null) {
      return SwitchListTile(
        secondary: const Icon(Icons.event_repeat_outlined),
        title: const Text('Automatische back-up'),
        subtitle: const Text(
          'Elke week een versleutelde back-up in een map die je kiest, '
          'bijvoorbeeld een die je gsm naar de cloud kopieert. De laatste '
          '$kAutoBackupsKept blijven bewaard.',
        ),
        value: false,
        onChanged: (_) => onPick(),
      );
    }

    final name = ref.watch(autoBackupFolderNameProvider(uri));
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.event_repeat_outlined),
          title: const Text('Automatische back-up'),
          subtitle: Text(switch (name) {
            AsyncData(value: final folder?) =>
              'Elke week naar "$folder". De laatste $kAutoBackupsKept '
                  'blijven bewaard.',
            AsyncData() || AsyncError() =>
              'De map is niet meer bereikbaar. Kies ze opnieuw, anders '
                  'komt er geen back-up bij.',
            _ => 'Elke week naar de map die je koos.',
          }),
          value: true,
          onChanged: (_) => onStop(uri),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open_outlined),
          title: const Text('Andere map kiezen'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onPick,
        ),
      ],
    );
  }
}
