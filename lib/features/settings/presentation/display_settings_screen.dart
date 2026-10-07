import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import 'settings_tiles.dart';

/// How the app looks, and the units it counts in.
class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> update(AppSettingsTableCompanion changes) =>
        ref.read(databaseProvider).settingsDao.updateSettings(changes);

    return Scaffold(
      appBar: AppBar(title: const Text('Weergave en eenheden')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const SectionHeader('Weergave'),
          ChoiceRow<String>(
            title: 'Thema',
            subtitle: settings.themeMode == 'system'
                ? 'Licht of donker, zoals je toestel staat'
                : null,
            values: const ['dark', 'light', 'system'],
            label: (mode) => switch (mode) {
              'light' => 'Licht',
              'system' => 'Systeem',
              _ => 'Donker',
            },
            selected: switch (settings.themeMode) {
              'light' || 'system' => settings.themeMode,
              _ => 'dark',
            },
            onChanged: (mode) =>
                update(AppSettingsTableCompanion(themeMode: Value(mode))),
          ),
          const SectionHeader('Eenheden'),
          ChoiceRow<WeightUnit>(
            title: 'Gewicht',
            values: WeightUnit.values,
            label: (unit) => unit.label,
            selected: WeightUnit.fromWire(settings.unitWeight),
            onChanged: (unit) =>
                update(AppSettingsTableCompanion(unitWeight: Value(unit.wire))),
          ),
          ChoiceRow<LengthUnit>(
            title: 'Lengte',
            values: LengthUnit.values,
            label: (unit) => switch (unit) {
              LengthUnit.cm => 'cm',
              LengthUnit.inch => 'inch',
            },
            selected: LengthUnit.fromWire(settings.unitLength),
            onChanged: (unit) =>
                update(AppSettingsTableCompanion(unitLength: Value(unit.wire))),
          ),
          ChoiceRow<DistanceUnit>(
            title: 'Afstand',
            values: DistanceUnit.values,
            label: (unit) => switch (unit) {
              DistanceUnit.km => 'km',
              DistanceUnit.mi => 'mi',
            },
            selected: DistanceUnit.fromWire(settings.unitDistance),
            onChanged: (unit) => update(
              AppSettingsTableCompanion(unitDistance: Value(unit.wire)),
            ),
          ),
        ],
      ),
    );
  }
}
