import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/week_navigator.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../health/presentation/steps_week_screen.dart';
import '../../progress/presentation/sleep_section.dart';
import '../data/week_reviewer.dart';
import '../domain/week_facts.dart';
import 'review_providers.dart';

/// Your week on one screen: what you planned and did, the sets per muscle
/// against the weeks before, the records, what stalled or moved again, and
/// how you slept and recovered. A week at a time, like the other week
/// screens.
class WeekReviewScreen extends StatelessWidget {
  const WeekReviewScreen({super.key, this.initial, this.now});

  /// The week to open on; the current one otherwise.
  final DateTime? initial;

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekoverzicht')),
      body: WeekPager(
        now: now,
        initial: initial,
        builder: (context, start, end) =>
            _Week(start: start, now: now ?? DateTime.now()),
      ),
    );
  }
}

const _weekdays = [
  'maandag',
  'dinsdag',
  'woensdag',
  'donderdag',
  'vrijdag',
  'zaterdag',
  'zondag',
];

/// `Leg day van vrijdag niet gedaan`, or `Push 1× niet gedaan`.
String missedLine(MissedRoutine missed) {
  if (missed.weekdays.isEmpty) {
    return '${missed.name} ${missed.times}× niet gedaan';
  }
  final days = [for (final d in missed.weekdays) _weekdays[d - 1]];
  final list = days.length == 1
      ? days.single
      : '${days.sublist(0, days.length - 1).join(', ')} en ${days.last}';
  return '${missed.name} van $list niet gedaan';
}

/// What a record of the week says, in its own unit.
String recordValue(WeekRecord record, Formatters formatters) =>
    switch (record.type) {
      'est_1rm' => '1RM ${formatters.weight(record.value)}',
      'max_weight' => formatters.weight(record.value),
      'max_reps' => '${record.value.round()} herhalingen',
      'max_set_volume' => formatters.volume(record.value),
      'max_duration' => Formatters.duration(record.value.round()),
      'max_distance' => formatters.distance(record.value),
      _ => formatters.decimal(record.value),
    };

class _Week extends ConsumerWidget {
  const _Week({required this.start, required this.now});

  final DateTime start;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(weekFactsProvider(start));
    final formatters = ref.watch(formattersProvider);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return facts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (week) {
        final quiet =
            week.workouts == 0 &&
            week.sleepMinutes == null &&
            week.steps == null &&
            week.missed.isEmpty;
        if (quiet) {
          return const EmptyState(
            icon: Icons.calendar_view_week_outlined,
            title: 'Een lege week',
            message: 'Geen trainingen, nachten of stappen in deze week.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            StatRow(
              children: [
                StatTile(
                  value: week.planned == null
                      ? '${week.workouts}'
                      : '${week.plannedDone}/${week.planned}',
                  label: 'Trainingen',
                ),
                StatTile(value: '${week.sets}', label: 'Sets'),
                StatTile(
                  value: formatters.volume(week.volumeKg),
                  label: 'Volume',
                ),
                StatTile(
                  value: '${week.records.length}',
                  label: 'Records',
                  emphasis: week.records.isNotEmpty,
                ),
              ],
            ),
            if (week.missed.isNotEmpty ||
                (week.planned != null && week.extra > 0))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in week.missed)
                      Text(missedLine(m), style: muted),
                    if (week.planned != null && week.extra > 0)
                      Text(
                        week.extra == 1
                            ? 'Plus 1 training buiten je planning'
                            : 'Plus ${week.extra} trainingen buiten je planning',
                        style: muted,
                      ),
                  ],
                ),
              ),
            _CoachCard(start: start, now: now),
            if (week.muscles.isNotEmpty) ...[
              const SectionHeader(
                'Sets per spiergroep',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.sm,
                ),
              ),
              _MuscleBars(muscles: week.muscles),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Het streepje is je gemiddelde van de 4 weken ervoor.',
                style: muted,
              ),
            ],
            if (week.records.isNotEmpty) ...[
              const SectionHeader(
                'Records',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xs,
                ),
              ),
              for (final record in week.records)
                _Line(
                  icon: Icons.emoji_events_outlined,
                  colour: AppColors.record,
                  label: record.exercise,
                  value: recordValue(record, formatters),
                ),
            ],
            if (week.stalled.isNotEmpty || week.movingAgain.isNotEmpty) ...[
              const SectionHeader(
                'Stilstand',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xs,
                ),
              ),
              for (final name in week.movingAgain)
                _Line(
                  icon: Icons.trending_up,
                  colour: AppColors.success,
                  label: name,
                  value: 'weer vooruit',
                ),
              for (final s in week.stalled)
                _Line(
                  icon: Icons.trending_flat,
                  colour: theme.colorScheme.onSurfaceVariant,
                  label: s.exercise,
                  value: '${s.weeks} weken',
                ),
            ],
            if (_hasRecovery(week)) ...[
              const SectionHeader(
                'Herstel',
                padding: EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.sm,
                ),
              ),
              _Recovery(week: week),
            ],
          ],
        );
      },
    );
  }

  bool _hasRecovery(WeekFacts w) =>
      w.sleepMinutes != null ||
      w.hrvMs != null ||
      w.restingHr != null ||
      w.steps != null;
}

/// One line of a list: an icon, what, and how much.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.colour,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color colour;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colour),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar per muscle: this week's sets, with a mark where the usual is. A
/// muscle clearly short of its usual is coloured.
class _MuscleBars extends StatelessWidget {
  const _MuscleBars({required this.muscles});

  final List<MuscleWeek> muscles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = muscles
        .expand((m) => [m.sets.toDouble(), m.usual])
        .fold<double>(1, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final m in muscles)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    m.muscle[0].toUpperCase() + m.muscle.substring(1),
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final colour = m.lagging
                          ? AppColors.record
                          : theme.colorScheme.primary;
                      return SizedBox(
                        height: 14,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              width: box.maxWidth * m.sets / scale,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colour,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            if (m.usual > 0)
                              Positioned(
                                left: (box.maxWidth * m.usual / scale - 1)
                                    .clamp(0, box.maxWidth - 2),
                                child: Container(
                                  width: 2,
                                  height: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${m.sets}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: m.lagging ? AppColors.record : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The nights and the watch, against your usual where there is one.
class _Recovery extends ConsumerWidget {
  const _Recovery({required this.week});

  final WeekFacts week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    String usual(String? value) => value == null ? '' : ', gewoon $value';

    final tiles = <Widget>[
      if (week.sleepMinutes case final minutes?)
        StatTile(
          value: nightLength(Duration(minutes: minutes)),
          label:
              'Slaap per nacht${usual(switch (week.usualSleepMinutes) {
                final u? => nightLength(Duration(minutes: u)),
                null => null,
              })}',
        ),
      if (week.sleepScore case final score?)
        StatTile(value: '$score', label: 'Slaapscore'),
      if (week.hrvMs case final hrv?)
        StatTile(
          value: '${formatters.decimal(hrv.roundToDouble())} ms',
          label:
              'HRV${usual(switch (week.usualHrvMs) {
                final u? => formatters.decimal(u.roundToDouble()),
                null => null,
              })}',
        ),
      if (week.restingHr case final hr?)
        StatTile(
          value: '${hr.round()} bpm',
          label:
              'Rusthartslag${usual(switch (week.usualRestingHr) {
                final u? => '${u.round()}',
                null => null,
              })}',
        ),
      if (week.steps case final steps?)
        StatTile(value: formatSteps(steps), label: 'Stappen per dag'),
    ];

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: StatRow(
              children: [
                tiles[i],
                if (i + 1 < tiles.length) tiles[i + 1] else const SizedBox(),
              ],
            ),
          ),
      ],
    );
  }
}

/// When the coach may write about the week from [start]: once it is over,
/// or from eight on its Sunday evening.
bool weekReadyForCoach(DateTime start, DateTime now) =>
    !now.isBefore(DateTime(start.year, start.month, start.day + 6, 20));

/// What the coach wrote about the week, the way to have it written, and the
/// way to hand its suggestion to the coach in the chat.
///
/// Nothing at all without a coach: the numbers are the review then.
class _CoachCard extends ConsumerWidget {
  const _CoachCard({required this.start, required this.now});

  final DateTime start;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(coachEnabledProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final review = ref.watch(weekReviewProvider(start)).value;
    final state = ref.watch(weekReviewControllerProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Future<void> write() =>
        ref.read(weekReviewControllerProvider.notifier).write(start, now: now);

    final Widget body;
    if (state.busy) {
      body = const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('De coach schrijft over je week')),
        ],
      );
    } else if (review?.coachText case final text?) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Geschreven '
            '${Formatters.relativeDayTime(review!.createdAt).toLowerCase()}',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _handToCoach(context, ref, review),
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text('Laat de coach het aanpassen'),
              ),
              TextButton(
                onPressed: write,
                child: const Text('Opnieuw laten schrijven'),
              ),
            ],
          ),
        ],
      );
    } else if (!weekReadyForCoach(start, now)) {
      final sunday =
          ref.watch(settingsProvider).value?.weekReviewNotify ?? true;
      body = Text(
        sunday
            ? 'De coach schrijft zondag om 20:00 over deze week.'
            : 'De coach schrijft over deze week zodra ze voorbij is.',
        style: muted,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((state.error ?? review?.coachError) case final error?) ...[
            Text(error, style: muted),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton.tonalIcon(
            onPressed: write,
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: const Text('Laat de coach erover schrijven'),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'De coach over je week',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        ),
      ),
    );
  }

  /// Puts the suggestion ready in a new conversation. Changing a routine is
  /// for the coach in the chat to do, and sending the question for the user.
  void _handToCoach(BuildContext context, WidgetRef ref, WeekReview review) {
    ref
        .read(coachDraftProvider.notifier)
        .put(
          'In mijn weekoverzicht van ${weekLabel(start)} schreef je: '
          '"${review.suggestion}" Pas mijn routines in de map Coach daarop '
          'aan.',
        );
    context.go(Routes.chat);
  }
}
