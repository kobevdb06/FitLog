import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import 'deload_start_sheet.dart';

/// Instellingen → Training → Deload: everything a deload does, and when the
/// app proposes one.
class DeloadSettingsScreen extends ConsumerWidget {
  const DeloadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final theme = Theme.of(context);
    Future<void> update(AppSettingsTableCompanion change) =>
        ref.read(databaseProvider).settingsDao.updateSettings(change);

    return Scaffold(
      appBar: AppBar(title: const Text('Deload')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Text(
                    'Een deload is een periode lichter trainen, zodat je '
                    'lichaam bijkomt. Wat hier staat, stelt het startblad '
                    'voor; daar pas je het aan voor één keer.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        showDeloadStartSheet(context, source: 'user'),
                    icon: const Icon(Icons.battery_charging_full),
                    label: const Text('Deload plannen'),
                  ),
                ),
                const SectionHeader('Hoe licht'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      DeloadPercentSlider(
                        label: 'Minder werksets',
                        value: settings.deloadSetsPercent,
                        max: 80,
                        divisions: 8,
                        onChanged: (v) => update(
                          AppSettingsTableCompanion(
                            deloadSetsPercent: Value(v),
                          ),
                        ),
                      ),
                      DeloadPercentSlider(
                        label: 'Lichter gewicht',
                        value: settings.deloadWeightPercent,
                        max: 40,
                        divisions: 8,
                        onChanged: (v) => update(
                          AppSettingsTableCompanion(
                            deloadWeightPercent: Value(v),
                          ),
                        ),
                      ),
                      DeloadPercentSlider(
                        label: 'Minder herhalingen',
                        value: settings.deloadRepsPercent,
                        max: 50,
                        divisions: 5,
                        onChanged: (v) => update(
                          AppSettingsTableCompanion(
                            deloadRepsPercent: Value(v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Dropsets en sets tot falen weglaten'),
                  subtitle: const Text(
                    'In een deload ga je niet tot het uiterste.',
                  ),
                  value: settings.deloadDropHardSets,
                  onChanged: (v) => update(
                    AppSettingsTableCompanion(deloadDropHardSets: Value(v)),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Recordpogingen toestaan'),
                  value: settings.deloadPrAttempts,
                  onChanged: (v) => update(
                    AppSettingsTableCompanion(deloadPrAttempts: Value(v)),
                  ),
                ),
                const SectionHeader('Duur en start'),
                _StepperTile(
                  title: 'Standaardduur',
                  value: settings.deloadDays,
                  min: kDeloadMinDays,
                  max: kDeloadMaxDays,
                  label: (v) => '$v ${v == 1 ? 'dag' : 'dagen'}',
                  onChanged: (v) =>
                      update(AppSettingsTableCompanion(deloadDays: Value(v))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Standaard starten',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'today', label: Text('Vandaag')),
                          ButtonSegment(
                            value: 'monday',
                            label: Text('Maandag'),
                          ),
                        ],
                        selected: {settings.deloadStart},
                        onSelectionChanged: (choice) => update(
                          AppSettingsTableCompanion(
                            deloadStart: Value(choice.single),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Voorstellen'),
                SwitchListTile(
                  title: const Text('Deload voorstellen'),
                  subtitle: Text(
                    settings.deloadSuggest
                        ? 'Een kaart op Start als het tijd is.'
                        : 'Uit. Er komen geen voorstellen tot je dit weer '
                              'aanzet.',
                  ),
                  value: settings.deloadSuggest,
                  onChanged: (v) => update(
                    AppSettingsTableCompanion(
                      deloadSuggest: Value(v),
                      // Switched on again: not still put away by Later.
                      deloadSnoozedUntil: v
                          ? const Value(null)
                          : const Value.absent(),
                    ),
                  ),
                ),
                _StepperTile(
                  title: 'Na zoveel weken zonder pauze',
                  value: settings.deloadSuggestWeeks,
                  min: 2,
                  max: 16,
                  label: (v) => '$v weken',
                  enabled: settings.deloadSuggest,
                  onChanged: (v) => update(
                    AppSettingsTableCompanion(deloadSuggestWeeks: Value(v)),
                  ),
                ),
                _StepperTile(
                  title: 'Of als zoveel oefeningen stilstaan',
                  value: settings.deloadSuggestStalled,
                  min: 1,
                  max: 10,
                  label: (v) => '$v',
                  enabled: settings.deloadSuggest,
                  onChanged: (v) => update(
                    AppSettingsTableCompanion(deloadSuggestStalled: Value(v)),
                  ),
                ),
                _StepperTile(
                  title: 'Later vraagt opnieuw na',
                  value: settings.deloadLaterDays,
                  min: 1,
                  max: 14,
                  label: (v) => '$v ${v == 1 ? 'dag' : 'dagen'}',
                  enabled: settings.deloadSuggest,
                  onChanged: (v) => update(
                    AppSettingsTableCompanion(deloadLaterDays: Value(v)),
                  ),
                ),
              ],
            ),
    );
  }
}

/// A setting that is a number: its name, and the number with a minus and a
/// plus. The title gets the room it needs; the number moves under it when
/// both do not fit.
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final String Function(int value) label;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: enabled ? null : theme.disabledColor,
            ),
          ),
          DeloadStepper(
            value: value,
            min: enabled ? min : value,
            max: enabled ? max : value,
            label: label(value),
            less: '$title: minder',
            more: '$title: meer',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
