import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../chat/data/links.dart';
import '../../chat/domain/answer_report.dart' show kReportAddress;
import '../../chat/presentation/chat_providers.dart';
import '../../dashboard/presentation/today_providers.dart';
import '../../health/presentation/health_providers.dart';
import '../data/feedback_mail.dart';
import 'about_screen.dart';
import 'feedback_providers.dart';

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
                'Rusttijd, opwarmen, RPE, hints, deload, PR-pogingen, stang '
                'en schijven',
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
            subtitle: const Text(
              'Versleutelde back-up, CSV, terugzetten, alles wissen',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settingsBackup),
          ),
          const SectionHeader('Over'),
          // What someone trying FitLog needs: a way to tell the maker, and a
          // way to find a newer version. Neither makes a connection: one
          // hands an e-mail to the mail app, the other the download page to
          // the browser.
          if (ref.watch(linkOpenerProvider) case final opener?) ...[
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Iets melden'),
              subtitle: const Text(
                'Een e-mail aan de maker, met je versie en je gsm erin',
              ),
              onTap: () => _report(context, ref, opener),
            ),
            ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Nieuwe versie zoeken'),
              subtitle: const Text(
                'Je hebt ${AboutScreen.appVersion}. Opent de downloadpagina.',
              ),
              // In the browser, not over the app: that is where the download
              // lands and the installer starts.
              onTap: () => opener.open(kSiteUrl),
            ),
          ],
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
}

/// Hands the mail app an e-mail to the maker, or puts it on the clipboard
/// when there is no mail app to take it.
Future<void> _report(
  BuildContext context,
  WidgetRef ref,
  LinkOpener opener,
) async {
  final mail = FeedbackMail(
    version: AboutScreen.appVersion,
    phone: await ref.read(phoneDescriptionProvider.future),
  );
  if (await opener.open(mail.mailto)) return;
  await Clipboard.setData(
    ClipboardData(text: '${mail.subject}\n\n${mail.body}'),
  );
  if (!context.mounted) return;
  showSnack(
    context,
    'Geen mail-app gevonden. De tekst staat op je klembord; stuur hem naar '
    '$kReportAddress.',
  );
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
