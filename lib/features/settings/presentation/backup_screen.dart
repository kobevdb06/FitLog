import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/security/recovery_phrase.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Backup ---------------------------------------------------------------

  Future<void> _createBackup() => _run(() async {
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
    final file = await BackupService(
      db: db,
      paths: paths,
    ).createBackup(recoveryPhrase: phrase, dek: dek);

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
      setState(() => _message = 'Back-up gemaakt: ${file.uri.pathSegments.last}');
    }
  });

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

      await controller.closeForRestore();
      await BackupService.applyRestore(backup: backup, paths: paths);

      // The restored database is encrypted with the key from the archive, so
      // every wrapped copy on this device is replaced.
      await manager.wipe();
      await manager.setRecoveryPhrase(
        dek: backup.dek,
        phrase: normalizeRecoveryPhrase(phrase),
      );
      await manager.setDirectKey(backup.dek);

      await controller.completeSetupWith(backup.dek);
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
            if (_busy) const LinearProgressIndicator(),
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
