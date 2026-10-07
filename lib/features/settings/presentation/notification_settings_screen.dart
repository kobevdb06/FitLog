import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../morning/presentation/morning_settings.dart';
import '../../review/presentation/review_providers.dart';
import 'settings_tiles.dart';

/// Everything that sounds or notifies, in one place: during a session, in
/// the morning, and on Sunday evening.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> update(AppSettingsTableCompanion changes) =>
        ref.read(databaseProvider).settingsDao.updateSettings(changes);

    return Scaffold(
      appBar: AppBar(title: const Text('Meldingen')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.sm),
          const NotificationsOffBanner(),
          const SectionHeader('Tijdens een training'),
          SwitchListTile(
            title: const Text('Geluid bij einde rust'),
            subtitle: const Text(
              'De melding gebruikt het systeemgeluid van je toestel.',
            ),
            value: settings.restSoundEnabled,
            onChanged: (value) => update(
              AppSettingsTableCompanion(restSoundEnabled: Value(value)),
            ),
          ),
          SwitchListTile(
            title: const Text('Klik bij het afvinken van een set'),
            value: settings.setCheckSoundEnabled,
            onChanged: (value) => update(
              AppSettingsTableCompanion(setCheckSoundEnabled: Value(value)),
            ),
          ),
          SwitchListTile(
            title: const Text('Melding bij een nieuw record'),
            value: settings.prAlertEnabled,
            onChanged: (value) =>
                update(AppSettingsTableCompanion(prAlertEnabled: Value(value))),
          ),
          const SectionHeader('Ochtendrapport'),
          const MorningReportSettings(),
          const SectionHeader('Weekoverzicht'),
          SwitchListTile(
            title: const Text('Melding op zondagavond'),
            subtitle: const Text(
              'Om 20:00, met je week op een rij. Het overzicht zelf staat '
              'altijd onder Voortgang.',
            ),
            value: settings.weekReviewNotify,
            onChanged: (value) => value
                ? ref.read(weekNotifyProvider).enable()
                : ref.read(weekNotifyProvider).disable(),
          ),
        ],
      ),
    );
  }
}
