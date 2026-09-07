import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plates.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/notification_service.dart';
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
          const _NotificationWarning(),
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
            onChanged: (value) => update(
              AppSettingsTableCompanion(restSoundEnabled: Value(value)),
            ),
          ),
          _ChoiceTile<int>(
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
          const SectionHeader('PR-pogingen'),
          _ChoiceTile<int>(
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
          _ChoiceTile<int>(
            title: 'Extra pogingen bij succes',
            subtitle: 'Aanbod na een geslaagde poging',
            values: const [0, 1, 2, 3],
            label: (v) => '$v',
            selected: settings.prDefaultExtraAttempts.clamp(0, 3),
            onChanged: (value) => update(
              AppSettingsTableCompanion(prDefaultExtraAttempts: Value(value)),
            ),
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
            subtitle: Text(switch (settings.themeMode) {
              'light' => 'Licht',
              'system' => 'Volgt het systeem',
              _ => 'Donker',
            }),
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

/// Says so when notifications are switched off for the app.
///
/// Without them the rest timer stays silent when the phone is away and no
/// standing notification appears during a workout - and nothing else in the
/// app would ever mention it, which is how it went unnoticed for a fortnight.
class _NotificationWarning extends StatelessWidget {
  const _NotificationWarning();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NotificationService.instance.isAllowed,
      builder: (context, snapshot) {
        if (snapshot.data != false) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: InfoBanner(
            icon: Icons.notifications_off_outlined,
            message:
                'Meldingen staan uit voor FitLog. De rusttimer laat dan niets '
                'zien als je je telefoon wegleg, en tijdens een workout komt '
                'er geen melding met je oefening en je set. Aan te zetten bij '
                'de app-instellingen van je toestel.',
          ),
        );
      },
    );
  }
}

/// A setting whose choices sit under its name instead of beside it.
///
/// A ListTile hands its trailing widget as much width as it asks for and
/// squeezes the title into whatever is left. Six segments leave so little that
/// the title wrapped to one letter per line - a column of single characters
/// down the screen.
///
/// Putting the choices on their own line means no number of options, no font
/// size and no translation can do that again.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    this.subtitle,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final List<T> values;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Scrollable as a last resort: a narrow phone with a large system
          // font can still run out of room, and a row that scrolls beats a row
          // that overflows.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final value in values)
                  ButtonSegment(value: value, label: Text(label(value))),
              ],
              selected: {selected},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
