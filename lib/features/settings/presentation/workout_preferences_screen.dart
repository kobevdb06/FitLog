import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plates.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';

/// Rest timer, feedback, units, bar and plates.
class WorkoutPreferencesScreen extends ConsumerWidget {
  const WorkoutPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final formatters = ref.watch(formattersProvider);

    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> update(AppSettingsTableCompanion changes) =>
        ref.read(databaseProvider).settingsDao.updateSettings(changes);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout-voorkeuren')),
      body: ListView(
        children: [
          const SectionHeader('Rusttimer'),
          ListTile(
            title: const Text('Standaard rusttijd'),
            subtitle: Text('${settings.defaultRestSeconds} seconden'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await showKeypadSheet(
                context: context,
                kind: KeypadFieldKind.duration,
                initialValue: KeypadValue.fromNumber(
                  settings.defaultRestSeconds,
                  decimals: 0,
                ),
                unitLabel: 'sec',
                title: 'Standaard rusttijd',
              );
              final seconds = result?.intValue;
              if (seconds == null) return;
              await update(
                AppSettingsTableCompanion(defaultRestSeconds: Value(seconds)),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Geluid bij einde rust'),
            subtitle: const Text(
              'De melding gebruikt het systeemgeluid van je toestel.',
            ),
            value: settings.restSoundEnabled,
            onChanged: (value) =>
                update(AppSettingsTableCompanion(restSoundEnabled: Value(value))),
          ),
          const SectionHeader('Feedback'),
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
          const SectionHeader('Eenheden'),
          ListTile(
            title: const Text('Gewicht'),
            trailing: SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: {WeightUnit.fromWire(settings.unitWeight)},
              onSelectionChanged: (s) => update(
                AppSettingsTableCompanion(unitWeight: Value(s.first.wire)),
              ),
            ),
          ),
          ListTile(
            title: const Text('Lengte'),
            trailing: SegmentedButton<LengthUnit>(
              segments: const [
                ButtonSegment(value: LengthUnit.cm, label: Text('cm')),
                ButtonSegment(value: LengthUnit.inch, label: Text('in')),
              ],
              selected: {LengthUnit.fromWire(settings.unitLength)},
              onSelectionChanged: (s) => update(
                AppSettingsTableCompanion(unitLength: Value(s.first.wire)),
              ),
            ),
          ),
          ListTile(
            title: const Text('Afstand'),
            trailing: SegmentedButton<DistanceUnit>(
              segments: const [
                ButtonSegment(value: DistanceUnit.km, label: Text('km')),
                ButtonSegment(value: DistanceUnit.mi, label: Text('mi')),
              ],
              selected: {DistanceUnit.fromWire(settings.unitDistance)},
              onSelectionChanged: (s) => update(
                AppSettingsTableCompanion(unitDistance: Value(s.first.wire)),
              ),
            ),
          ),
          const SectionHeader('Stang en schijven'),
          ListTile(
            title: const Text('Gewicht van de stang'),
            subtitle: Text(formatters.weight(settings.barWeightKg)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await showKeypadSheet(
                context: context,
                kind: KeypadFieldKind.weight,
                initialValue: KeypadValue.fromNumber(
                  formatters.toDisplayWeight(settings.barWeightKg),
                ),
                unitLabel: formatters.weightUnitLabel,
                title: 'Gewicht van de stang',
              );
              final value = result?.number;
              if (value == null) return;
              await update(
                AppSettingsTableCompanion(
                  barWeightKg: Value(formatters.fromDisplayWeight(value)),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: _PlateEditor(
              plates: decodePlates(settings.availablePlatesKg),
              formatters: formatters,
              onChanged: (plates) => update(
                AppSettingsTableCompanion(
                  availablePlatesKg: Value(encodePlates(plates)),
                ),
              ),
            ),
          ),
          const SectionHeader('Weergave'),
          ListTile(
            title: const Text('Thema'),
            subtitle: Text(
              switch (settings.themeMode) {
                'light' => 'Licht',
                'system' => 'Volgt het systeem',
                _ => 'Donker',
              },
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final mode = await showAppSheet<String>(
                context: context,
                title: 'Thema',
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in const [
                      ('dark', 'Donker'),
                      ('light', 'Licht'),
                      ('system', 'Volgt het systeem'),
                    ])
                      ListTile(
                        title: Text(option.$2),
                        selected: settings.themeMode == option.$1,
                        onTap: () => Navigator.of(context).pop(option.$1),
                      ),
                  ],
                ),
              );
              if (mode != null) {
                await update(AppSettingsTableCompanion(themeMode: Value(mode)));
              }
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _PlateEditor extends StatelessWidget {
  const _PlateEditor({
    required this.plates,
    required this.formatters,
    required this.onChanged,
  });

  final List<double> plates;
  final Formatters formatters;
  final ValueChanged<List<double>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Beschikbare schijven per zijde',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final plate in kDefaultPlatesKg)
              FilterChip(
                label: Text(formatters.weight(plate)),
                selected: plates.contains(plate),
                onSelected: (selected) {
                  final next = [...plates];
                  selected ? next.add(plate) : next.remove(plate);
                  if (next.isEmpty) return;
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
