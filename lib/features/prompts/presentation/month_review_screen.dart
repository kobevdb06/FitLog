import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../data/moment_facts.dart';
import '../domain/coach_moments.dart';
import 'moment_answer_card.dart';

/// The numbers of the month from [start], next to the month before.
final monthNumbersProvider = FutureProvider.autoDispose
    .family<({MonthNumbers month, MonthNumbers previous}), DateTime>((
      ref,
      start,
    ) async {
      final db = ref.watch(databaseProvider);
      final end = DateTime(start.year, start.month + 1);
      final before = DateTime(start.year, start.month - 1);
      return (
        month: await monthNumbers(db, start, end, health: true),
        previous: await monthNumbers(db, before, start, health: true),
      );
    });

/// When the coach may write about the month from [start]: on its first
/// morning after it, at [kMonthHour].
bool monthReadyForCoach(DateTime start, DateTime now) =>
    !now.isBefore(DateTime(start.year, start.month + 1, 1, kMonthHour));

/// The list has its own margin: a heading needs none of its own.
const EdgeInsets _header = EdgeInsets.only(
  top: AppSpacing.xl,
  bottom: AppSpacing.sm,
);

/// Voortgang → Maandoverzicht: a month at a time, the numbers next to the
/// month before, and what the coach says once it is over.
class MonthReviewScreen extends ConsumerStatefulWidget {
  const MonthReviewScreen({super.key, this.initial});

  /// A day in the month to open on; the month that last ended otherwise.
  final DateTime? initial;

  @override
  ConsumerState<MonthReviewScreen> createState() => _MonthReviewScreenState();
}

class _MonthReviewScreenState extends ConsumerState<MonthReviewScreen> {
  late DateTime _start = _open();

  DateTime _open() {
    if (widget.initial case final day?) return DateTime(day.year, day.month);
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1);
  }

  void _move(int months) =>
      setState(() => _start = DateTime(_start.year, _start.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final numbers = ref.watch(monthNumbersProvider(_start)).value;
    final formatters = ref.watch(formattersProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ready = monthReadyForCoach(_start, now);
    final subject = MomentSubject.month(_start);

    String compared(num now, num before, String Function(num) show) =>
        before == 0 ? show(now) : '${show(now)} (was ${show(before)})';

    return Scaffold(
      appBar: AppBar(title: const Text('Maandoverzicht')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorige maand',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  Formatters.monthYear(_start),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Volgende maand',
                onPressed: _start.isBefore(current) ? () => _move(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (numbers == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: AppSpacing.md),
            StatRow(
              children: [
                StatTile(value: '${numbers.month.workouts}', label: 'Workouts'),
                StatTile(value: '${numbers.month.sets}', label: 'Sets'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            StatRow(
              children: [
                StatTile(
                  value: formatters.volume(numbers.month.volumeKg),
                  label: 'Volume',
                ),
                StatTile(value: '${numbers.month.records}', label: 'Records'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              numbers.previous.workouts == 0
                  ? 'Geen trainingen de maand ervoor.'
                  : 'De maand ervoor: '
                        '${Formatters.amount(numbers.previous.workouts, 'workout', 'workouts')}, '
                        '${numbers.previous.sets} sets.',
              style: muted,
            ),
            if (numbers.month.workouts > 0 || ready)
              MomentAnswerCard(
                moment: CoachMoment.month,
                subject: subject,
                askNow: ready && numbers.month.workouts > 0,
                onlyAnswered: !ready,
                title: 'De coach over je maand',
                about: 'mijn maand ${Formatters.monthYear(_start)}',
                padding: const EdgeInsets.only(top: AppSpacing.lg),
              ),
            if (numbers.month.muscles.isNotEmpty) ...[
              const SectionHeader('Sets per spiergroep', padding: _header),
              for (final MapEntry(key: muscle, value: sets)
                  in numbers.month.muscles.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(Formatters.muscle(muscle))),
                      Text(
                        compared(
                          sets,
                          numbers.previous.muscles[muscle] ?? 0,
                          (v) => '$v',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (numbers.month.weightFirst case final first?) ...[
              const SectionHeader('Gewicht', padding: _header),
              Text(
                numbers.month.weightLast == first
                    ? formatters.weight(first)
                    : '${formatters.weight(first)} → '
                          '${formatters.weight(numbers.month.weightLast!)}',
              ),
            ],
            if (numbers.month.sleepMinutes case final minutes?) ...[
              const SectionHeader('Slaap', padding: _header),
              Text(
                '${minutes ~/ 60} u ${minutes % 60} per nacht'
                '${numbers.previous.sleepMinutes == null ? '' : ' (was ${numbers.previous.sleepMinutes! ~/ 60} u ${numbers.previous.sleepMinutes! % 60})'}',
              ),
            ],
          ],
        ],
      ),
    );
  }
}
