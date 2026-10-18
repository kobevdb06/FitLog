import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/deload.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../data/deload_standing.dart';
import 'deload_providers.dart';

/// Plans a deload: when it begins, how many days, and how much lighter -
/// from the settings, changed here for this one time. [plan], [days] and
/// [from] come from the coach's proposal when it opens this.
///
/// [source] is who started it: `user`, `suggestion` or `coach`. Comes back
/// with the deload's id, or null when it was not started.
Future<String?> showDeloadStartSheet(
  BuildContext context, {
  required String source,
  DeloadPlan? plan,
  int? days,
  DateTime? from,
}) => showAppSheet<String>(
  context: context,
  title: 'Deload starten',
  builder: (context) =>
      _DeloadStartSheet(source: source, plan: plan, days: days, from: from),
);

/// The days the chips offer, from [today]: today, tomorrow and the next
/// Monday - not twice when tomorrow is that Monday.
List<(String, DateTime)> deloadStartChoices(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final tomorrow = DateTime(day.year, day.month, day.day + 1);
  final monday = nextMonday(day);
  return [
    ('Vandaag', day),
    ('Morgen', tomorrow),
    if (monday != tomorrow) ('Maandag', monday),
  ];
}

class _DeloadStartSheet extends ConsumerStatefulWidget {
  const _DeloadStartSheet({
    required this.source,
    this.plan,
    this.days,
    this.from,
  });

  final String source;
  final DeloadPlan? plan;
  final int? days;
  final DateTime? from;

  @override
  ConsumerState<_DeloadStartSheet> createState() => _DeloadStartSheetState();
}

class _DeloadStartSheetState extends ConsumerState<_DeloadStartSheet> {
  late DateTime _from;
  late int _days;
  late int _sets;
  late int _weight;
  late int _reps;
  late bool _dropHard;
  late bool _prAttempts;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    final plan =
        widget.plan ??
        (settings == null ? const DeloadPlan() : deloadPlanOf(settings));
    final today = DateTime.now();
    final choices = deloadStartChoices(today);
    final first = choices.first.$2;
    _from =
        widget.from ??
        (settings?.deloadStart == 'monday' ? choices.last.$2 : first);
    // A proposal from a while ago: not in the past, where the calendar
    // cannot go either.
    if (_from.isBefore(first)) _from = first;
    _days = (widget.days ?? settings?.deloadDays ?? 7).clamp(
      kDeloadMinDays,
      kDeloadMaxDays,
    );
    _sets = plan.setsPercent;
    _weight = plan.weightPercent;
    _reps = plan.repsPercent;
    _dropHard = plan.dropHardSets;
    _prAttempts = plan.prAttempts;
  }

  DeloadPlan get _plan => DeloadPlan(
    setsPercent: _sets,
    weightPercent: _weight,
    repsPercent: _reps,
    dropHardSets: _dropHard,
    prAttempts: _prAttempts,
  );

  Future<void> _pickDay() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day + 90),
      helpText: 'Begin van de deload',
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final id = await ref
        .read(databaseProvider)
        .deloadDao
        .start(from: _from, days: _days, plan: _plan, source: widget.source);
    if (!mounted) return;
    Navigator.of(context).pop(id);
    showSnack(context, deloadStartedText(_from, _days, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final choices = deloadStartChoices(DateTime.now());
    final chosen = choices.any((c) => c.$2 == _from);
    final last = DateTime(_from.year, _from.month, _from.day + _days - 1);
    final example = ref.watch(deloadExampleProvider).value;
    final format = ref.watch(formattersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Begin', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (label, day) in choices)
                ChoiceChip(
                  label: Text(
                    '$label · ${Formatters.weekdayDayMonthShort(day)}',
                  ),
                  selected: _from == day,
                  onSelected: (_) => setState(() => _from = day),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  chosen
                      ? 'Andere dag'
                      : Formatters.weekdayDayMonthShort(_from),
                ),
                selected: !chosen,
                onSelected: (_) => _pickDay(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: Text('Duur', style: theme.textTheme.titleSmall)),
              DeloadStepper(
                value: _days,
                min: kDeloadMinDays,
                max: kDeloadMaxDays,
                label: '$_days ${_days == 1 ? 'dag' : 'dagen'}',
                less: 'Een dag korter',
                more: 'Een dag langer',
                onChanged: (days) => setState(() => _days = days),
              ),
            ],
          ),
          Text(
            'Van ${Formatters.weekdayDayMonthShort(_from)} tot en met '
            '${Formatters.weekdayDayMonthShort(last)}.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('Hoe licht', style: theme.textTheme.titleSmall),
            subtitle: Text(deloadPlanSummary(_plan), style: muted),
            children: [
              DeloadPercentSlider(
                label: 'Minder werksets',
                value: _sets,
                range: kDeloadSets,
                onChanged: (v) => setState(() => _sets = v),
              ),
              DeloadPercentSlider(
                label: 'Lichter gewicht',
                value: _weight,
                range: kDeloadWeight,
                onChanged: (v) => setState(() => _weight = v),
              ),
              DeloadPercentSlider(
                label: 'Minder herhalingen',
                value: _reps,
                range: kDeloadReps,
                onChanged: (v) => setState(() => _reps = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dropsets en sets tot falen weglaten'),
                value: _dropHard,
                onChanged: (v) => setState(() => _dropHard = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordpogingen toestaan'),
                value: _prAttempts,
                onChanged: (v) => setState(() => _prAttempts = v),
              ),
            ],
          ),
          if (example != null)
            Card(
              margin: const EdgeInsets.only(top: AppSpacing.xs),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zo wordt een training', style: muted),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      deloadExampleText(example, _plan, format),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _starting ? null : _start,
            child: const Text('Deload starten'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// What is said once a deload is started on [from]: begun, when that is
/// today, or planned.
String deloadStartedText(DateTime from, int days, DateTime now) =>
    DateTime(now.year, now.month, now.day) == from
    ? 'Deload gestart, $days ${days == 1 ? 'dag' : 'dagen'}.'
    : 'Deload gepland vanaf ${Formatters.weekdayDayMonthShort(from)}.';

/// `Werksets −50% · gewicht −10% · herhalingen gelijk`.
String deloadPlanSummary(DeloadPlan plan) => [
  plan.setsPercent == 0 ? 'werksets gelijk' : 'werksets −${plan.setsPercent}%',
  plan.weightPercent == 0
      ? 'gewicht gelijk'
      : 'gewicht −${plan.weightPercent}%',
  plan.repsPercent == 0
      ? 'herhalingen gelijk'
      : 'herhalingen −${plan.repsPercent}%',
  if (plan.dropHardSets) 'zonder dropsets',
].join(' · ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

/// `Bench Press: 4 × 80 kg × 8 → 2 × 72,5 kg × 8`.
String deloadExampleText(
  DeloadExample example,
  DeloadPlan plan,
  Formatters format,
) {
  final weight = plan.weight(example.weightKg, example.stepKg)!;
  final reps = plan.reps(example.reps)!;
  return '${example.name}: ${example.sets} × '
      '${format.weight(example.weightKg)} × ${example.reps} → '
      '${plan.keptSets(example.sets)} × ${format.weight(weight)} × $reps';
}

/// A number with a minus and a plus, for days and weeks.
class DeloadStepper extends StatelessWidget {
  const DeloadStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.less,
    required this.more,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String label;
  final String less;
  final String more;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: less,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        IconButton(
          tooltip: more,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// A percentage from nothing to the most of its [range], with its label and
/// what it is.
class DeloadPercentSlider extends StatelessWidget {
  const DeloadPercentSlider({
    super.key,
    required this.label,
    required this.value,
    required this.range,
    required this.onChanged,
  });

  final String label;
  final int value;
  final DeloadRange range;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              value == 0 ? 'gelijk' : '−$value%',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        Slider(
          value: range.snap(value).toDouble(),
          max: range.max.toDouble(),
          divisions: range.divisions,
          label: '$value%',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
