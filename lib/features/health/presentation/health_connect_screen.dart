import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../data/health_importer.dart';
import '../data/health_source.dart';
import 'health_providers.dart';

/// Connecting Health Connect, and what it brings in.
class HealthConnectScreen extends ConsumerWidget {
  const HealthConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final availability = ref.watch(healthAvailabilityProvider);
    final enabled = ref.watch(healthConnectEnabledProvider);
    final sync = ref.watch(healthSyncProvider);
    final syncedAt = ref.watch(settingsProvider).value?.healthConnectSyncedAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: InfoBanner(
              icon: Icons.phonelink_lock_outlined,
              message:
                  'Health Connect is de plek op je gsm waar apps als Samsung '
                  'Health, Google Health en je horloge hun gegevens delen. '
                  'FitLog leest er alleen uit wat hieronder staat. Alles blijft '
                  'op je gsm: hier gaat niets over het internet.',
            ),
          ),
          const SectionHeader('Wat FitLog leest'),
          for (final (icon, title, why) in _whatWeRead)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(why),
            ),
          const SectionHeader('Verbinding'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: switch (availability) {
              AsyncData(value: HealthAvailability.unavailable) => _Missing(
                message:
                    'Health Connect staat niet op deze gsm. Op Android 14 en '
                    'nieuwer zit het ingebouwd; op oudere toestellen installeer '
                    'je het uit de Play Store.',
                action: 'Health Connect installeren',
                onTap: () => ref.read(healthSourceProvider).openInstall(),
              ),
              AsyncData(value: HealthAvailability.needsUpdate) => _Missing(
                message:
                    'Health Connect is te oud voor wat FitLog vraagt. Werk het '
                    'bij in de Play Store.',
                action: 'Health Connect bijwerken',
                onTap: () => ref.read(healthSourceProvider).openInstall(),
              ),
              AsyncData() when !enabled => _NotConnected(busy: sync.busy),
              AsyncData() => _Connected(
                busy: sync.busy,
                syncedAt: syncedAt == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(syncedAt),
              ),
              AsyncError() => _Missing(
                message: 'FitLog kon niet nagaan of Health Connect er is.',
                action: 'Opnieuw proberen',
                onTap: () => ref.invalidate(healthAvailabilityProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          if (sync.summary case final summary?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                importSummaryText(summary),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (sync.error case final error?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: InfoBanner(
                message: error,
                icon: Icons.error_outline,
                color: theme.colorScheme.error,
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: _OwnWins(),
          ),
        ],
      ),
    );
  }
}

/// What is read, and why - the same list the user sees on Health Connect's
/// own permission screen, in FitLog's words.
const List<(IconData, String, String)> _whatWeRead = [
  (
    Icons.bedtime_outlined,
    'Slaap, met de fasen',
    'Komt vanzelf binnen, in plaats van ze elke ochtend in te typen.',
  ),
  (
    Icons.monitor_heart_outlined,
    'HRV en rusthartslag',
    'Tegenover je eigen gemiddelde: een aanwijzing of je hersteld bent.',
  ),
  (
    Icons.monitor_weight_outlined,
    'Gewicht',
    'Van een slimme weegschaal, voor je grafiek en je lichaamsgewicht.',
  ),
  (
    Icons.directions_run,
    'Loop- en fietssessies',
    'Die tellen mee voor het herstel van je benen.',
  ),
];

/// One line on what an import brought in.
String importSummaryText(ImportSummary summary) {
  if (summary.isEmpty && summary.ownNightsKept == 0) {
    return 'Opgehaald: niets nieuws.';
  }
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final parts = [
    if (summary.nights > 0) count(summary.nights, 'nacht', 'nachten'),
    if (summary.vitalDays > 0)
      '${count(summary.vitalDays, 'dag', 'dagen')} HRV en hartslag',
    if (summary.weights > 0) count(summary.weights, 'gewicht', 'gewichten'),
    if (summary.cardio > 0)
      count(summary.cardio, 'loop of rit', 'lopen of ritten'),
  ];
  final kept = summary.ownNightsKept + summary.ownWeightsKept;
  return [
    if (parts.isNotEmpty) 'Opgehaald: ${parts.join(', ')}.',
    if (kept > 0)
      '${count(kept, 'eigen invoer', 'eigen invoeren')} bleef staan zoals je '
          'ze zelf ingaf.',
  ].join(' ');
}

class _Missing extends StatelessWidget {
  const _Missing({
    required this.message,
    required this.action,
    required this.onTap,
  });

  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _NotConnected extends ConsumerWidget {
  const _NotConnected({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nog niet verbonden. Health Connect vraagt je daarna per gegeven '
          'of FitLog het mag lezen.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => ref.read(healthSyncProvider.notifier).connect(),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link),
          label: const Text('Verbinden'),
        ),
      ],
    );
  }
}

class _Connected extends ConsumerWidget {
  const _Connected({required this.busy, required this.syncedAt});

  final bool busy;
  final DateTime? syncedAt;

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Health Connect ontkoppelen?'),
        content: const Text(
          'FitLog haalt dan niets meer op en geeft zijn toegang terug. Wat al '
          'binnenkwam, kan je houden of wissen. Wat je zelf invulde, blijft '
          'altijd staan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ontkoppelen en wissen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ontkoppelen'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await ref.read(healthSyncProvider.notifier).disconnect(forget: choice);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final last = syncedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                last == null
                    ? 'Verbonden.'
                    : 'Verbonden. Laatst opgehaald '
                          '${Formatters.weekdayDayMonth(last)} om '
                          '${Formatters.time(last)}.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'FitLog haalt vanzelf op als je de app opent.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => ref.read(healthSyncProvider.notifier).sync(force: true),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: const Text('Nu ophalen'),
        ),
        TextButton(
          onPressed: busy ? null : () => _disconnect(context, ref),
          child: const Text('Ontkoppelen'),
        ),
      ],
    );
  }
}

class _OwnWins extends StatelessWidget {
  const _OwnWins();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Wat je zelf in FitLog invult, gaat voor. Een nacht of gewicht dat je '
      'zelf ingaf, wordt nooit overschreven, en een geïmporteerde nacht die je '
      'aanpast, wordt de jouwe.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
