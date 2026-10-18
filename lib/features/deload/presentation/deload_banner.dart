import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/deload.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import 'deload_providers.dart';
import 'deload_start_sheet.dart';

/// On Start and Trainen while a deload is going or planned: which day of it,
/// until when, and the way out.
class DeloadBanner extends ConsumerWidget {
  const DeloadBanner({super.key, this.margin});

  /// Around the card; the Start tab's when null.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deload = ref.watch(currentDeloadProvider).value;
    if (deload == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final going = deload.isOnAt(now);
    final theme = Theme.of(context);

    return Card(
      margin:
          margin ??
          const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.battery_charging_full, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deload', style: theme.textTheme.titleSmall),
                  Text(
                    going
                        ? 'Dag ${deload.dayAt(now)} van ${deload.days} · tot en '
                              'met ${Formatters.weekdayDayMonthShort(deload.lastDay)}'
                        : 'Vanaf ${Formatters.weekdayDayMonthShort(deload.from)} · '
                              '${deload.days} ${deload.days == 1 ? 'dag' : 'dagen'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _stop(context, ref, deload, going: going),
              child: Text(going ? 'Stoppen' : 'Annuleren'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stop(
    BuildContext context,
    WidgetRef ref,
    DeloadWeekRow deload, {
    required bool going,
  }) async {
    final sure = await confirm(
      context,
      title: going ? 'Deload stoppen?' : 'Deload annuleren?',
      message: going
          ? 'Je volgende training is weer een gewone.'
          : 'De geplande deload verdwijnt.',
      confirmLabel: going ? 'Stoppen' : 'Annuleren',
      cancelLabel: 'Terug',
    );
    if (!sure) return;
    await ref.read(databaseProvider).deloadDao.stop(deload.id);
  }
}

/// `Je traint al 7 weken zonder pauze, en 2 oefeningen staan stil: Bench
/// Press en Back Squat.` - the reasons that were reached.
String deloadReasonText(
  DeloadReason reason, {
  required int weeksLimit,
  required int stalledLimit,
}) {
  final weeks = weeksLimit > 0 && reason.weeks >= weeksLimit;
  final stalled = stalledLimit > 0 && reason.stalled.length >= stalledLimit;
  final names = reason.stalled.length <= 1
      ? reason.stalled.join()
      : '${reason.stalled.sublist(0, reason.stalled.length - 1).join(', ')} '
            'en ${reason.stalled.last}';
  final standing = reason.stalled.length == 1
      ? '1 oefening staat stil: $names'
      : '${reason.stalled.length} oefeningen staan stil: $names';
  if (weeks && stalled) {
    return 'Je traint al ${reason.weeks} weken zonder pauze, en '
        '${standing[0].toLowerCase()}${standing.substring(1)}.';
  }
  if (weeks) return 'Je traint al ${reason.weeks} weken zonder pauze.';
  return '$standing.';
}

/// The proposal on Start: why it is time, and Starten, Later or the bell to
/// mute it - on one line, as high as each other.
class DeloadSuggestionCard extends ConsumerWidget {
  const DeloadSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(deloadSuggestionProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (reason == null || settings == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final db = ref.read(databaseProvider);
    // Android's smallest tap target, for all three alike.
    const height = 48.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.record),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.battery_2_bar, color: AppColors.record),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tijd voor een deloadweek?',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        deloadReasonText(
                          reason,
                          weeksLimit: settings.deloadSuggestWeeks,
                          stalledLimit: settings.deloadSuggestStalled,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                // Two halves and the bell: on one line, as high as each
                // other, also with large text on a narrow phone.
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, height),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed: () =>
                        showDeloadStartSheet(context, source: 'suggestion'),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Starten'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, height),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed: () async {
                      await snoozeDeloadSuggestion(db);
                      if (!context.mounted) return;
                      showSnack(
                        context,
                        'Over ${settings.deloadLaterDays} '
                        '${settings.deloadLaterDays == 1 ? 'dag' : 'dagen'} '
                        'vraagt FitLog het opnieuw.',
                      );
                    },
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Later'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.outlined(
                  tooltip: 'Melding dempen',
                  constraints: const BoxConstraints.tightFor(
                    width: height,
                    height: height,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await muteDeloadSuggestion(db);
                    if (!context.mounted) return;
                    showSnack(
                      context,
                      'Voorstellen staan uit. Weer aanzetten: Instellingen → '
                      'Training → Deload.',
                    );
                  },
                  icon: const Icon(Icons.notifications_paused_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
