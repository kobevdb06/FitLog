import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fitlog_mark.dart';
import '../data/app_icon.dart';
import 'app_icon_providers.dart';
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
          const _AppIconChoice(),
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

/// The icon on the home screen, chosen apart from the theme.
///
/// Not tied to the theme: Android has one launcher icon for day and night,
/// and a switch can take the icon off the home screen. Once, when you choose
/// it, is a price; every change of theme would be a nuisance.
class _AppIconChoice extends ConsumerWidget {
  const _AppIconChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switcher = ref.watch(appIconSwitcherProvider);
    final current = ref.watch(currentAppIconProvider).value;
    if (switcher == null || current == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    Future<void> choose(AppIcon icon) async {
      if (icon == current) return;
      final sure = await confirm(
        context,
        title: 'App-icoon wisselen?',
        message:
            'FitLog start daarbij opnieuw op. Op sommige telefoons verdwijnt '
            'het icoon even van je beginscherm; de app staat dan nog in je '
            'app-lijst, en van daaruit zet je hem er weer op.',
        confirmLabel: 'Wisselen',
      );
      if (!sure) return;
      await switcher.use(icon);
      // On Android this window closes a moment later, and the app opens again
      // through the new icon; until then it shows the new choice.
      if (context.mounted) ref.invalidate(currentAppIconProvider);
    }

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
          Text('App-icoon', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            'Op je beginscherm, los van het thema.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final icon in AppIcon.values) ...[
                if (icon != AppIcon.values.first)
                  const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _IconOption(
                    icon: icon,
                    selected: icon == current,
                    onTap: () => choose(icon),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One icon to choose, drawn the way the launcher will show it.
class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: 'App-icoon ${icon.label.toLowerCase()}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 56,
                  child: CustomPaint(
                    painter: switch (icon) {
                      AppIcon.dark => const FitLogMarkPainter(
                        tile: FitLogMarkPainter.iconBackground,
                      ),
                      AppIcon.light => const FitLogMarkPainter.light(
                        tile: FitLogMarkPainter.lightIconBackground,
                      ),
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  icon.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? theme.colorScheme.primary : null,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
