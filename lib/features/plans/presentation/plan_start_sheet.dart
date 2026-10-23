import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/plan_weeks.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../data/plan_actions.dart';

/// Start schema: from which Monday, and which schema stops for it.
///
/// A schema runs in calendar weeks. The first is this one until Wednesday
/// and the next one after, but the user may pick either: who starts on a
/// Thursday with a session already planned for Friday knows best.
///
/// True when it started.
Future<bool> showPlanStartSheet(
  BuildContext context,
  WidgetRef ref,
  TrainingPlanRow plan,
) async {
  final dao = ref.read(databaseProvider).plansDao;
  final running = await dao.running();
  final stops = running != null && running.id != plan.id ? running : null;
  final now = DateTime.now();
  final thisMonday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final mondays = [
    thisMonday,
    DateTime(thisMonday.year, thisMonday.month, thisMonday.day + 7),
  ];
  if (!context.mounted) return false;

  final from = await showAppSheet<DateTime>(
    context: context,
    title: 'Schema starten',
    builder: (context) =>
        _StartSheet(plan: plan, mondays: mondays, stops: stops, now: now),
  );
  if (from == null) return false;
  await PlanActions.start(ref.read(databaseProvider), plan.id, from: from);
  return true;
}

class _StartSheet extends StatefulWidget {
  const _StartSheet({
    required this.plan,
    required this.mondays,
    required this.stops,
    required this.now,
  });

  final TrainingPlanRow plan;
  final List<DateTime> mondays;
  final TrainingPlanRow? stops;
  final DateTime now;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  late DateTime _from = firstPlanMonday(widget.now);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final weeks = widget.plan.weeks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.plan.name, style: theme.textTheme.titleMedium),
          if (weeks != null)
            Text(Formatters.amount(weeks, 'week', 'weken'), style: muted),
          const SizedBox(height: AppSpacing.lg),
          Text('Week 1 begint', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (i, monday) in widget.mondays.indexed)
                ChoiceChip(
                  label: Text(
                    '${i == 0 ? 'Deze week' : 'Volgende week'} · '
                    '${Formatters.weekdayDayMonthShort(monday)}',
                  ),
                  selected: _from == monday,
                  onSelected: (_) => setState(() => _from = monday),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'De dagen zijn een richtlijn: een sessie telt in de week dat je '
            'ze doet, op welke dag ook.',
            style: muted,
          ),
          if (widget.stops case final stops?) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '"${stops.name}" stopt: er loopt maar één schema '
                    'tegelijk. Het blijft bij je eerdere schema\'s.',
                    style: muted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_from),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start schema'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nog niet'),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a started schema says, once.
String planStartedText(DateTime from, DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return from.isAfter(monday)
      ? 'Schema gestart. Week 1 begint ${Formatters.weekdayDayMonth(from)}.'
      : 'Schema gestart. Week 1 is deze week.';
}

/// Shows [planStartedText] for the schema as it now stands.
Future<void> sayPlanStarted(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final plan = await ref.read(databaseProvider).plansDao.plan(id);
  final from = plan?.from;
  if (from == null || !context.mounted) return;
  showSnack(context, planStartedText(from, DateTime.now()));
}
