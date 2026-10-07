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
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';
import 'settings_tiles.dart';

/// How a session goes: rest, warm-ups, what is logged and hinted, PR
/// attempts, and the bar and plates in your gym.
class TrainingSettingsScreen extends ConsumerWidget {
  const TrainingSettingsScreen({super.key});

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
      appBar: AppBar(title: const Text('Training')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const SectionHeader('Rusttimer'),
          const NotificationsOffBanner(),
          ListTile(
            title: const Text('Standaard rusttijd'),
            subtitle: Text(
              Formatters.minutesSeconds(settings.defaultRestSeconds),
            ),
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
          const SectionHeader('Tijdens een training'),
          ChoiceRow<int>(
            title: 'Warming-up sets bij een nieuwe oefening',
            subtitle: settings.defaultWarmupSets == 0
                ? 'Geen; je voegt ze zelf toe'
                : '${settings.defaultWarmupSets} bovenaan elke nieuwe '
                      'oefening',
            values: const [0, 1, 2, 3, 4, 5],
            label: (v) => '$v',
            selected: settings.defaultWarmupSets,
            onChanged: (value) => update(
              AppSettingsTableCompanion(defaultWarmupSets: Value(value)),
            ),
          ),
          SwitchListTile(
            title: const Text('RPE bijhouden'),
            subtitle: const Text(
              'Een extra kolom per set: hoe zwaar die aanvoelde, van 1 tot 10. '
              'De herstelschatting luistert ernaar.',
            ),
            value: settings.trackRpe,
            onChanged: (value) =>
                update(AppSettingsTableCompanion(trackRpe: Value(value))),
          ),
          SwitchListTile(
            title: const Text('Hint per oefening'),
            subtitle: const Text(
              'Bij elke oefening wat je vandaag probeert: zwaarder als je '
              'vorige keer alle herhalingen haalde, anders hetzelfde gewicht '
              'met meer herhalingen.',
            ),
            value: settings.progressionHints,
            onChanged: (value) => update(
              AppSettingsTableCompanion(progressionHints: Value(value)),
            ),
          ),
          const SectionHeader('PR-pogingen'),
          ChoiceRow<int>(
            title: 'Opwarmsets in de ladder',
            subtitle:
                '${settings.prDefaultWarmupSets} sets tussen 40% en 90% van '
                'je doel',
            values: const [2, 4, 6, 8],
            label: (v) => '$v',
            selected: const [2, 4, 6, 8].contains(settings.prDefaultWarmupSets)
                ? settings.prDefaultWarmupSets
                : 4,
            onChanged: (value) => update(
              AppSettingsTableCompanion(prDefaultWarmupSets: Value(value)),
            ),
          ),
          ChoiceRow<int>(
            title: 'Extra pogingen bij succes',
            subtitle: 'Aanbod na een geslaagde poging',
            values: const [0, 1, 2, 3],
            label: (v) => '$v',
            selected: settings.prDefaultExtraAttempts.clamp(0, 3),
            onChanged: (value) => update(
              AppSettingsTableCompanion(prDefaultExtraAttempts: Value(value)),
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
        ],
      ),
    );
  }
}

/// The plates in your gym: the standard set for your unit, and any of your
/// own on top - microplates, a 0.5 kg disc, kilo plates in a pound gym.
class _PlateEditor extends StatelessWidget {
  const _PlateEditor({
    required this.plates,
    required this.formatters,
    required this.onChanged,
  });

  /// Kilograms, as stored.
  final List<double> plates;
  final Formatters formatters;
  final ValueChanged<List<double>> onChanged;

  bool get _pounds => formatters.weightUnit == WeightUnit.lb;

  bool _has(double plate) => plates.any((p) => samePlate(p, plate));

  /// Leaves at least one plate: a bar with nothing to load is no setting.
  void _without(double plate) {
    final next = [
      for (final p in plates)
        if (!samePlate(p, plate)) p,
    ];
    if (next.isNotEmpty) onChanged(next);
  }

  Future<void> _add(BuildContext context) async {
    final result = await showKeypadSheet(
      context: context,
      kind: KeypadFieldKind.weight,
      initialValue: const KeypadValue.empty(),
      unitLabel: formatters.weightUnitLabel,
      title: 'Schijf toevoegen',
    );
    final value = result?.number;
    if (value == null || value <= 0) return;
    final plate = formatters.fromDisplayWeight(value);
    if (_has(plate)) return;
    onChanged([...plates, plate]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standard = standardPlatesKg(pounds: _pounds);
    final own = [
      for (final p in plates)
        if (!standard.any((s) => samePlate(s, p))) p,
    ]..sort((a, b) => b.compareTo(a));
    final isStandard =
        own.isEmpty && standard.every(_has) && plates.length == standard.length;

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
            for (final plate in standard)
              FilterChip(
                label: Text(formatters.weight(plate)),
                selected: _has(plate),
                onSelected: (selected) =>
                    selected ? onChanged([...plates, plate]) : _without(plate),
              ),
            // Your own: always there, until you take them away.
            for (final plate in own)
              InputChip(
                label: Text(formatters.weight(plate)),
                selected: true,
                onSelected: (_) {},
                deleteButtonTooltipMessage: 'Weghalen',
                onDeleted: () => _without(plate),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Schijf toevoegen'),
              onPressed: () => _add(context),
            ),
          ],
        ),
        if (!isStandard)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: TextButton(
              onPressed: () => onChanged(standard),
              child: Text(
                'Standaardset in ${_pounds ? 'lb' : 'kg'} terugzetten',
              ),
            ),
          ),
      ],
    );
  }
}
