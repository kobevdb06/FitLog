import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/milestones.dart';
import '../../../core/calc/streak.dart';
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
import '../../measurements/presentation/measurements_screen.dart';
import '../../history/presentation/history_providers.dart';
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
                          // Nothing yet is a dash, like the busiest day
                          // beside it - not "0 s".
                          value: (stats?.durationSeconds ?? 0) == 0
                              ? '-'
                              : Formatters.durationWords(
                                  stats!.durationSeconds,
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
          const SectionHeader('Mijlpalen'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _Milestones(stats: stats),
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
            subtitle: Text(
              Sex.fromWire(profile?.sex)?.label ?? 'Niet ingevuld',
            ),
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
          const _WeightTile(),
          const _GymTile(),
          // What else is yours. The settings are the gear at the top; a
          // second way to them was all this section used to hold.
          const SectionHeader('Meer van jou'),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Persoonlijke records'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.records),
          ),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Lichaamsmetingen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.measurements),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text("Voortgangsfoto's"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.photos),
          ),
        ],
      ),
    );
  }
}

/// What you have reached, and how far the next step is.
///
/// Badges that were simply there or not said nothing about the road to the
/// next one, and the one for weeks in a row counted the streak running now:
/// it went again the week a streak ended. A milestone counts the longest
/// streak you ever had, and keeps what you reached.
class _Milestones extends ConsumerWidget {
  const _Milestones({required this.stats});

  final LifetimeStats? stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(finishedWorkoutDatesProvider).value ?? const [];
    final records = ref.watch(allRecordsProvider()).value?.length ?? 0;
    final formatters = ref.watch(formattersProvider);
    final milestones = milestonesFor(
      workouts: stats?.workouts ?? 0,
      longestStreakWeeks: longestStreakWeeks(dates),
      volumeKg: stats?.volumeKg ?? 0,
      records: records,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          for (final (i, milestone) in milestones.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            _MilestoneRow(milestone: milestone, formatters: formatters),
          ],
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone, required this.formatters});

  final Milestone milestone;
  final Formatters formatters;

  /// A value of this milestone in words: `50 workouts`, `12 weken`, `100 t`.
  String amount(double value) => switch (milestone.kind) {
    MilestoneKind.workouts => Formatters.amount(
      value.round(),
      'workout',
      'workouts',
    ),
    MilestoneKind.streak => Formatters.amount(value.round(), 'week', 'weken'),
    MilestoneKind.volume => formatters.volume(value),
    MilestoneKind.records => Formatters.amount(
      value.round(),
      'record',
      'records',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final earned = milestone.reached > 0;
    final left = milestone.kind == MilestoneKind.volume
        ? formatters.volume(milestone.remaining)
        : '${milestone.remaining.round()}';
    final (title, icon) = switch (milestone.kind) {
      MilestoneKind.workouts => ('Workouts', Icons.flag_outlined),
      MilestoneKind.streak => (
        'Langste reeks',
        Icons.local_fire_department_outlined,
      ),
      MilestoneKind.volume => ('Getild', Icons.fitness_center),
      MilestoneKind.records => ('Records', Icons.emoji_events_outlined),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: earned ? AppColors.record : muted),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    '${milestone.reached} van ${milestone.steps.length}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: milestone.progress,
                  minHeight: 6,
                  color: AppColors.record,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(switch (milestone.next) {
                null => 'Alles behaald: ${amount(milestone.value)}',
                final next when milestone.value == 0 =>
                  'Eerste stap: ${amount(next)}',
                final next =>
                  '${amount(milestone.value)} · nog $left tot ${amount(next)}',
              }, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Your body weight as you last measured it, and the way to a new one.
///
/// A measurement like any other - this is the latest of them, not a second
/// place where a weight is kept.
class _WeightTile extends ConsumerWidget {
  const _WeightTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref
        .watch(latestMeasurementsProvider)
        .value?[MeasurementType.weight];
    final formatters = ref.watch(formattersProvider);

    return ListTile(
      title: const Text('Lichaamsgewicht'),
      subtitle: Text(
        latest == null
            ? 'Nog geen meting'
            : '${formatters.measurement(MeasurementType.weight, latest.value)}'
                  ' · ${Formatters.relativeDay(DateTime.fromMillisecondsSinceEpoch(latest.measuredAt)).toLowerCase()}',
      ),
      trailing: const Icon(Icons.add),
      onTap: () =>
          showAddMeasurementSheet(context, ref, type: MeasurementType.weight),
    );
  }
}

/// Where you train, in your own words: what is there and what is not.
///
/// Part of who you are as a lifter, so it lives here; the coach reads it when
/// it picks exercises, if you share your profile with it.
class _GymTile extends ConsumerWidget {
  const _GymTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(settingsProvider).value?.coachGym;
    final gym = stored == null || stored.trim().isEmpty ? null : stored.trim();

    return ListTile(
      title: const Text('Waar je traint'),
      subtitle: Text(gym ?? 'Nog niet beschreven'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final text = await promptForText(
          context,
          title: 'Waar train je?',
          initialValue: gym,
          hintText:
              'bijvoorbeeld Basic-Fit Gent, geen smith machine, dumbbells '
              'tot 40 kg',
          maxLines: 4,
          maxLength: 300,
        );
        if (text == null) return;
        await ref
            .read(databaseProvider)
            .settingsDao
            .updateSettings(
              AppSettingsTableCompanion(
                coachGym: Value(text.trim().isEmpty ? null : text.trim()),
              ),
            );
      },
    );
  }
}
