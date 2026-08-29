import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../../routing/routes.dart';
import '../../progress/presentation/progress_providers.dart';

/// The Profiel tab: who you are, what you have lifted, and the way into
/// settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final stats = ref.watch(lifetimeStatsProvider).value;
    final streak = ref.watch(streakProvider).value;
    final formatters = ref.watch(formattersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiel'),
        actions: [
          IconButton(
            tooltip: 'Instellingen',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                  child: Text(
                    (profile?.displayName?.trim().isNotEmpty ?? false)
                        ? profile!.displayName!.trim()[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.displayName?.trim().isNotEmpty ?? false
                            ? profile!.displayName!
                            : 'Naamloos',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (streak != null)
                        Text(
                          streak.isActive
                              ? '${streak.weeks} '
                                    '${streak.weeks == 1 ? 'week' : 'weken'} op rij'
                              : 'Nog geen reeks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Totalen'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${stats?.workouts ?? 0}',
                          label: 'Workouts',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${stats?.sets ?? 0}',
                          label: 'Sets',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: formatters.volume(stats?.volumeKg ?? 0),
                          label: 'Totaal getild',
                          emphasis: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: Formatters.durationWords(
                            stats?.durationSeconds ?? 0,
                          ),
                          label: 'Tijd in de zaal',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: stats?.busiestWeekday == null
                              ? '-'
                              : Formatters.weekdayName(stats!.busiestWeekday!),
                          label: 'Actiefste dag',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Badges'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _Badges(stats: stats, streakWeeks: streak?.weeks ?? 0),
          ),
          const SectionHeader('Gegevens'),
          ListTile(
            title: const Text('Naam'),
            subtitle: Text(profile?.displayName ?? 'Niet ingevuld'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final name = await promptForText(
                context,
                title: 'Naam',
                initialValue: profile?.displayName,
              );
              if (name == null) return;
              await ref
                  .read(databaseProvider)
                  .settingsDao
                  .upsertProfile(
                    displayName: Value(
                      name.trim().isEmpty ? null : name.trim(),
                    ),
                  );
            },
          ),
          ListTile(
            title: const Text('Geboortedatum'),
            subtitle: Text(
              profile?.birthDate == null
                  ? 'Niet ingevuld'
                  : Formatters.fullDate(
                      DateTime.fromMillisecondsSinceEpoch(profile!.birthDate!),
                    ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: profile?.birthDate == null
                    ? DateTime(now.year - 30)
                    : DateTime.fromMillisecondsSinceEpoch(profile!.birthDate!),
                firstDate: DateTime(now.year - 100),
                lastDate: now,
              );
              if (picked == null) return;
              await ref
                  .read(databaseProvider)
                  .settingsDao
                  .upsertProfile(
                    birthDate: Value(picked.millisecondsSinceEpoch),
                  );
            },
          ),
          ListTile(
            title: const Text('Geslacht'),
            subtitle: Text(Sex.fromWire(profile?.sex)?.label ?? 'Niet ingevuld'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final sex = await showAppSheet<Sex>(
                context: context,
                title: 'Geslacht',
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in Sex.values)
                      ListTile(
                        title: Text(s.label),
                        selected: profile?.sex == s.wire,
                        onTap: () => Navigator.of(context).pop(s),
                      ),
                  ],
                ),
              );
              if (sex == null) return;
              await ref
                  .read(databaseProvider)
                  .settingsDao
                  .upsertProfile(sex: Value(sex.wire));
            },
          ),
          ListTile(
            title: const Text('Lengte'),
            subtitle: Text(
              profile?.heightCm == null
                  ? 'Niet ingevuld'
                  : formatters.length(profile!.heightCm),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await showKeypadSheet(
                context: context,
                kind: KeypadFieldKind.distance,
                initialValue: KeypadValue.fromNumber(
                  profile?.heightCm == null
                      ? null
                      : formatters.toDisplayLength(profile!.heightCm!),
                ),
                unitLabel: formatters.lengthUnitLabel,
                title: 'Lengte',
                steps: const [1, 5],
              );
              final value = result?.number;
              if (value == null) return;
              await ref
                  .read(databaseProvider)
                  .settingsDao
                  .upsertProfile(
                    heightCm: Value(formatters.fromDisplayLength(value)),
                  );
            },
          ),
          const SectionHeader('Meer'),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Instellingen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settings),
          ),
        ],
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.stats, required this.streakWeeks});

  final LifetimeStats? stats;
  final int streakWeeks;

  @override
  Widget build(BuildContext context) {
    final workouts = stats?.workouts ?? 0;
    final volume = stats?.volumeKg ?? 0;

    final badges = <({String label, IconData icon, bool earned})>[
      (
        label: 'Eerste workout',
        icon: Icons.flag_outlined,
        earned: workouts >= 1,
      ),
      (label: '10 workouts', icon: Icons.looks_two, earned: workouts >= 10),
      (
        label: '50 workouts',
        icon: Icons.workspace_premium_outlined,
        earned: workouts >= 50,
      ),
      (
        label: '4 weken op rij',
        icon: Icons.local_fire_department_outlined,
        earned: streakWeeks >= 4,
      ),
      (
        label: '100 ton getild',
        icon: Icons.fitness_center,
        earned: volume >= 100000,
      ),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final badge in badges)
          Chip(
            avatar: Icon(
              badge.icon,
              size: 18,
              color: badge.earned
                  ? AppColors.record
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(badge.label),
            backgroundColor: badge.earned
                ? AppColors.record.withValues(alpha: 0.12)
                : null,
          ),
      ],
    );
  }
}
