import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';

/// The settings hub.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: ListView(
        children: [
          const SectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Workout-voorkeuren'),
            subtitle: const Text(
              'Rusttimer, geluiden, eenheden, stang en schijven',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settingsWorkout),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Beveiliging'),
            subtitle: const Text(
              'Pincode, biometrie, auto-vergrendelen, herstelzin',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settingsSecurity),
          ),
          const SectionHeader('Gegevens'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Back-up en export'),
            subtitle: const Text('Versleutelde back-up, CSV, herstellen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settingsBackup),
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: AppColors.danger,
            ),
            title: const Text(
              'Alle gegevens wissen',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () => _wipe(context, ref),
          ),
          const SectionHeader('Over'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Over FitLog'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settingsAbout),
          ),
        ],
      ),
    );
  }

  /// Two confirmations and typing the word, because there is no undo and no
  /// copy anywhere else.
  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final first = await confirm(
      context,
      title: 'Alle gegevens wissen?',
      message:
          'Je routines, workouts, records, metingen en foto\'s worden van dit '
          'toestel verwijderd. Er is geen kopie elders.',
      confirmLabel: 'Doorgaan',
      destructive: true,
    );
    if (!first || !context.mounted) return;

    final second = await confirmByTyping(
      context,
      title: 'Zeker weten?',
      message: 'Typ WISSEN om te bevestigen. Dit kan niet ongedaan gemaakt.',
      word: 'WISSEN',
    );
    if (!second) return;

    await ref.read(appControllerProvider.notifier).wipeEverything();
  }
}

/// Small helper shared by the security screens: does this device have a PIN?
Future<bool> hasPin(WidgetRef ref) async {
  final status = await ref.read(keyManagerProvider).status();
  return status.mode == LockMode.pin;
}
