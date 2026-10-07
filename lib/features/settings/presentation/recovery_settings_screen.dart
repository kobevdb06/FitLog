import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';

/// What the recovery screen asks you about, beyond your training.
class RecoverySettingsScreen extends ConsumerWidget {
  const RecoverySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> update(AppSettingsTableCompanion changes) =>
        ref.read(databaseProvider).settingsDao.updateSettings(changes);

    return Scaffold(
      appBar: AppBar(title: const Text('Herstel')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          SwitchListTile(
            title: const Text('Slaapfasen invullen'),
            subtitle: const Text(
              'Bij een nacht ook lichte, REM- en diepe slaap, als je die van '
              'je horloge weet. Ze worden bewaard en getoond; de schatting '
              'kijkt naar hoe lang je sliep.',
            ),
            value: settings.trackSleepStages,
            onChanged: (value) => update(
              AppSettingsTableCompanion(trackSleepStages: Value(value)),
            ),
          ),
          SwitchListTile(
            title: const Text('Alcohol bijhouden'),
            subtitle: const Text(
              'Op het herstelscherm: hoeveel glazen vandaag en gisteren. Pas '
              'vanaf een paar glazen op een trainingsdag rekt het je herstel.',
            ),
            value: settings.trackAlcohol,
            onChanged: (value) =>
                update(AppSettingsTableCompanion(trackAlcohol: Value(value))),
          ),
        ],
      ),
    );
  }
}
