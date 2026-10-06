import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Monday at midnight of the week [day] falls in. Weeks run Monday to
/// Sunday, as calendars do in Belgium.
///
/// From the calendar, not by subtracting days of 24 hours, so the week the
/// clocks change still starts at midnight.
DateTime weekStartOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

/// The Monday after [start]: where the week ends, exclusive.
DateTime weekEndOf(DateTime start) =>
    DateTime(start.year, start.month, start.day + 7);

/// `28/9 – 4/10`.
String weekLabel(DateTime start) {
  final last = DateTime(start.year, start.month, start.day + 6);
  return '${start.day}/${start.month} – ${last.day}/${last.month}';
}

/// One week at a time, with arrows to the one before and after - never past
/// the week of [now].
///
/// Opens on the current week, or on [initial] when given. Used wherever
/// there is a log that keeps growing - nights, reports, sessions - so the
/// screen stays as long as one week, whatever the history.
class WeekPager extends StatefulWidget {
  const WeekPager({super.key, required this.builder, this.now, this.initial});

  /// What is shown for the week from [start] up to [end], exclusive.
  final Widget Function(BuildContext context, DateTime start, DateTime end)
  builder;

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  /// A day in the week to open on. Never past the current week.
  final DateTime? initial;

  @override
  State<WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<WeekPager> {
  late DateTime _start = () {
    final current = weekStartOf(widget.now ?? DateTime.now());
    final asked = widget.initial;
    if (asked == null) return current;
    final week = weekStartOf(asked);
    return week.isAfter(current) ? current : week;
  }();

  DateTime get _current => weekStartOf(widget.now ?? DateTime.now());

  void _move(int weeks) => setState(
    () => _start = DateTime(_start.year, _start.month, _start.day + 7 * weeks),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = !_start.isBefore(_current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Vorige week',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      weekLabel(_start),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      isCurrent
                          ? 'Deze week'
                          : 'Week van ${_start.day}/'
                                '${_start.month}/${_start.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Volgende week',
                // No weeks from the future: there is nothing in them yet.
                onPressed: isCurrent ? null : () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(child: widget.builder(context, _start, weekEndOf(_start))),
      ],
    );
  }
}
