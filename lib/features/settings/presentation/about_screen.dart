import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';

/// Version, licences, sources, and the promise that nothing leaves the device.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Kept in step with `version:` in pubspec.yaml.
  static const String appVersion = '1.11.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Over FitLog')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Center(child: FitLogLogo(size: 64)),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'Versie $appVersion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const InfoBanner(
            icon: Icons.wifi_off,
            message:
                'FitLog verzendt geen gegevens. De app heeft geen account, '
                'geen server, geen analytics en geen internettoegang: op '
                'Android staat de INTERNET-permissie bewust niet in het '
                'manifest, en de release-build haalt hem weg als een '
                'onderdeel er alsnog om vraagt.',
          ),
          const SizedBox(height: AppSpacing.md),
          const InfoBanner(
            icon: Icons.qr_code_scanner,
            message:
                'De QR-scanner werkt op het toestel zelf; het model zit in de '
                'app en wordt niet opgehaald. Hij brengt wel twee permissies '
                'mee: CAMERA om te scannen, en ACCESS_NETWORK_STATE, waarmee '
                'alleen te zien is óf er een verbinding is. Zonder INTERNET '
                'kan er niets over.',
          ),
          const SectionHeader(
            'Waar je gegevens staan',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
          ),
          Text(
            'Alles staat in een SQLCipher-database op dit toestel. De sleutel '
            'wordt bewaard in de Keystore (Android) of de Keychain (iOS) en '
            'is versleuteld met een sleutel die met Argon2id uit je pincode '
            'wordt afgeleid. Foto\'s staan in de privémap van de app, niet in '
            'je camerarol.',
            style: theme.textTheme.bodyMedium,
          ),
          const SectionHeader(
            'Oefeningen',
            padding: EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
          ),
          Text(
            'De catalogus komt uit free-exercise-db '
            '(github.com/yuhonas/free-exercise-db), vrijgegeven onder de '
            'Unlicense en dus publiek domein. De oefeningsnamen zijn in het '
            'Engels gelaten omdat die in de zaal ingeburgerd zijn; de '
            'spiergroepen en materiaalnamen zijn vertaald.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ook de illustraties komen uit die dataset: per oefening de start- '
            'en eindpositie, hier verkleind en samengevoegd tot een animatie '
            'van twee beelden. Ze zitten in de app zelf, dus er wordt niets '
            'opgehaald terwijl je traint.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'FitLog',
              applicationVersion: appVersion,
              applicationLegalese:
                  'Oefeningen: free-exercise-db (Unlicense).',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Licenties van gebruikte pakketten'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
