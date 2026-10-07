import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../dashboard/presentation/today_providers.dart';
import '../../health/presentation/health_providers.dart';

/// The settings hub.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: ListView(
        children: [
          // Grouped by what you are doing when you go looking: training,
          // recovering, or setting up the app itself.
          const SectionHeader('Trainen'),
          _Entry(
            icon: Icons.fitness_center,
            title: 'Training',
            subtitle:
                'Rusttijd, opwarmen, RPE, hints, PR-pogingen, stang en '
                'schijven',
            route: Routes.settingsTraining,
          ),
          _Entry(
            icon: Icons.category_outlined,
            title: 'Eigen keuzelijsten',
            subtitle: 'Spiergroepen, materiaal en categorieën toevoegen',
            route: Routes.settingsCatalogue,
          ),
          const SectionHeader('Herstel'),
          _Entry(
            icon: Icons.bedtime_outlined,
            title: 'Herstel',
            subtitle: 'Slaapfasen en alcohol bijhouden',
            route: Routes.settingsRecovery,
          ),
          _Entry(
            icon: Icons.favorite_outline,
            title: 'Health Connect',
            subtitle: ref.watch(healthConnectEnabledProvider)
                ? 'Verbonden. Slaap, HRV, gewicht en cardio van je horloge'
                : 'Slaap, HRV, gewicht en cardio van je horloge ophalen',
            route: Routes.healthConnect,
          ),
          const SectionHeader('App'),
          _Entry(
            icon: Icons.notifications_outlined,
            title: 'Meldingen',
            subtitle: 'Rusttimer, records, ochtendrapport en weekoverzicht',
            route: Routes.settingsNotifications,
          ),
          _Entry(
            icon: Icons.palette_outlined,
            title: 'Weergave en eenheden',
            subtitle: 'Thema, kg of lb, cm of inch, km of mi',
            route: Routes.settingsDisplay,
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Startscherm'),
            subtitle: const Text(
              'Opent het Start-tabblad om je blokken te schikken',
            ),
            trailing: const Icon(Icons.chevron_right),
            // You arrange the Start tab on the Start tab: a list of words
            // here could never show what the screen would look like, and it
            // could not offer the sizes at all.
            onTap: () {
              ref.read(homeArrangeRequestProvider.notifier).ask();
              context.go(Routes.dashboard);
            },
          ),
          _Entry(
            icon: Icons.smart_toy_outlined,
            title: 'AI-coach',
            subtitle: ref.watch(coachEnabledProvider)
                ? 'Aan. Het enige deel van de app dat internet gebruikt'
                : 'Uit. Werkt alleen met een API-sleutel van jezelf',
            route: Routes.settingsCoach,
          ),
          _Entry(
            icon: Icons.lock_outline,
            title: 'Beveiliging',
            subtitle: 'Pincode, biometrie, auto-vergrendelen, herstelzin',
            route: Routes.settingsSecurity,
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

/// One way into a part of the settings.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}

/// Small helper shared by the security screens: does this device have a PIN?
Future<bool> hasPin(WidgetRef ref) async {
  final status = await ref.read(keyManagerProvider).status();
  return status.mode == LockMode.pin;
}
