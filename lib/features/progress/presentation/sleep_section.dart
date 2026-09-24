import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import 'recovery_providers.dart';

/// Shortest and longest night the app believes. Outside this, a time was
/// almost certainly picked on the wrong side of midnight.
const Duration kShortestNight = Duration(hours: 1);
const Duration kLongestNight = Duration(hours: 16);

/// Turns two clock times into the night they describe, ending on [wakeDay].
///
/// A person knows "half twelve" and "ten past seven", not which date each
/// belongs to. Falling asleep later in the day than waking up means it was the
/// evening before; earlier means it was already past midnight.
({DateTime fellAsleepAt, DateTime wokeAt}) nightFromTimes({
  required DateTime wakeDay,
  required TimeOfDay asleep,
  required TimeOfDay woke,
}) {
  final wokeAt = DateTime(
    wakeDay.year,
    wakeDay.month,
    wakeDay.day,
    woke.hour,
    woke.minute,
  );
  final asleepMinutes = asleep.hour * 60 + asleep.minute;
  final wokeMinutes = woke.hour * 60 + woke.minute;
  final fellAsleepAt = DateTime(
    wakeDay.year,
    wakeDay.month,
    wakeDay.day - (asleepMinutes >= wokeMinutes ? 1 : 0),
    asleep.hour,
    asleep.minute,
  );
  return (fellAsleepAt: fellAsleepAt, wokeAt: wokeAt);
}

/// Reads a stage length the way a watch shows it: `1:20`, `1u20`, `80`.
///
/// Null for an empty field - not filled in, which is not the same as zero -
/// and for anything that is not a length.
int? parseStageMinutes(String text) {
  final value = text.trim().toLowerCase().replaceAll(' ', '');
  if (value.isEmpty) return null;
  final split = RegExp(r'^(\d{1,2})[:u.h](\d{1,2})(min)?$').firstMatch(value);
  if (split != null) {
    final minutes = int.parse(split.group(2)!);
    if (minutes >= 60) return null;
    return int.parse(split.group(1)!) * 60 + minutes;
  }
  final plain = RegExp(r'^(\d{1,3})(min)?$').firstMatch(value);
  if (plain != null) return int.parse(plain.group(1)!);
  return null;
}

/// `7 u 30` for a night, the way people say it.
String nightLength(Duration d) {
  final minutes = d.inMinutes.remainder(60);
  return minutes == 0 ? '${d.inHours} u' : '${d.inHours} u $minutes';
}

/// The last few nights and the way to fill in one more.
class SleepSection extends ConsumerWidget {
  const SleepSection({super.key});

  /// How many nights the screen shows. The estimate itself looks at up to
  /// three after each session; showing more is a diary, which this is not.
  static const int shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(sleepEntriesProvider).value ?? const [];
    final stages = ref.watch(settingsProvider).value?.trackSleepStages ?? false;
    final today = DateTime.now();
    final todayKey = _dayKey(today);

    final recent = rows.reversed.take(shown).toList();
    final hasLastNight = rows.any(
      (row) =>
          _dayKey(DateTime.fromMillisecondsSinceEpoch(row.wokeAt)) == todayKey,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recent.isEmpty)
              Text(
                'Hoe laat viel je in slaap, en wanneer werd je wakker? Korte '
                'nachten rekken je herstel; lange maken het niet korter.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final row in recent)
                _NightRow(
                  row: row,
                  onTap: () => _edit(
                    context,
                    ref,
                    wakeDay: DateTime.fromMillisecondsSinceEpoch(row.wokeAt),
                    existing: row,
                    stages: stages,
                  ),
                ),
            if (!hasLastNight) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _edit(
                  context,
                  ref,
                  wakeDay: today,
                  existing: null,
                  stages: stages,
                  like: rows.isEmpty ? null : rows.last,
                ),
                icon: const Icon(Icons.bedtime_outlined),
                label: const Text('Afgelopen nacht invullen'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required DateTime wakeDay,
    required SleepEntryRow? existing,
    required bool stages,
    SleepEntryRow? like,
  }) async {
    final answer = await showAppSheet<_SleepAnswer>(
      context: context,
      title: existing == null
          ? 'Afgelopen nacht'
          : 'Nacht naar ${Formatters.weekdayDayMonth(wakeDay)}',
      builder: (context) => _SleepSheet(
        wakeDay: wakeDay,
        existing: existing,
        // A new night starts from the times of the last one: most people go
        // to bed and get up at roughly the same time.
        template: existing ?? like,
        stages: stages,
      ),
    );
    if (answer == null) return;

    final actions = ref.read(recoveryActionsProvider);
    if (answer.forget) {
      await actions.forgetNight(wakeDay);
      return;
    }
    await actions.sleep(
      fellAsleepAt: answer.fellAsleepAt!,
      wokeAt: answer.wokeAt!,
      lightMinutes: answer.light,
      remMinutes: answer.rem,
      deepMinutes: answer.deep,
    );
  }
}

String _dayKey(DateTime at) => '${at.year}-${at.month}-${at.day}';

class _NightRow extends StatelessWidget {
  const _NightRow({required this.row, required this.onTap});

  final SleepEntryRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asleep = DateTime.fromMillisecondsSinceEpoch(row.fellAsleepAt);
    final woke = DateTime.fromMillisecondsSinceEpoch(row.wokeAt);
    final length = woke.difference(asleep);

    final stages = [
      if (row.lightMinutes case final m?)
        'licht ${nightLength(Duration(minutes: m))}',
      if (row.remMinutes case final m?)
        'REM ${nightLength(Duration(minutes: m))}',
      if (row.deepMinutes case final m?)
        'diep ${nightLength(Duration(minutes: m))}',
    ];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.weekdayDayMonth(woke),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${Formatters.time(asleep)} - ${Formatters.time(woke)}'
                    '  ·  ${nightLength(length)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (stages.isNotEmpty)
                    Text(
                      stages.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the sheet hands back: a night to store, or one to forget.
class _SleepAnswer {
  const _SleepAnswer.night({
    required DateTime this.fellAsleepAt,
    required DateTime this.wokeAt,
    this.light,
    this.rem,
    this.deep,
  }) : forget = false;

  const _SleepAnswer.forget()
    : forget = true,
      fellAsleepAt = null,
      wokeAt = null,
      light = null,
      rem = null,
      deep = null;

  final bool forget;
  final DateTime? fellAsleepAt;
  final DateTime? wokeAt;
  final int? light;
  final int? rem;
  final int? deep;
}

class _SleepSheet extends StatefulWidget {
  const _SleepSheet({
    required this.wakeDay,
    required this.existing,
    required this.template,
    required this.stages,
  });

  final DateTime wakeDay;
  final SleepEntryRow? existing;
  final SleepEntryRow? template;
  final bool stages;

  @override
  State<_SleepSheet> createState() => _SleepSheetState();
}

class _SleepSheetState extends State<_SleepSheet> {
  late TimeOfDay _asleep;
  late TimeOfDay _woke;
  late final TextEditingController _light;
  late final TextEditingController _rem;
  late final TextEditingController _deep;
  String? _error;

  @override
  void initState() {
    super.initState();
    final from = widget.template;
    _asleep = from == null
        ? const TimeOfDay(hour: 23, minute: 0)
        : TimeOfDay.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(from.fellAsleepAt),
          );
    _woke = from == null
        ? const TimeOfDay(hour: 7, minute: 0)
        : TimeOfDay.fromDateTime(
            DateTime.fromMillisecondsSinceEpoch(from.wokeAt),
          );

    // Stages only carry over when correcting the same night: last night's
    // deep sleep is no default for tonight's.
    String stage(int? minutes) => widget.existing == null || minutes == null
        ? ''
        : '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
    _light = TextEditingController(text: stage(widget.existing?.lightMinutes));
    _rem = TextEditingController(text: stage(widget.existing?.remMinutes));
    _deep = TextEditingController(text: stage(widget.existing?.deepMinutes));
  }

  @override
  void dispose() {
    _light.dispose();
    _rem.dispose();
    _deep.dispose();
    super.dispose();
  }

  ({DateTime fellAsleepAt, DateTime wokeAt}) get _night =>
      nightFromTimes(wakeDay: widget.wakeDay, asleep: _asleep, woke: _woke);

  Future<void> _pick({required bool asleep}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: asleep ? _asleep : _woke,
      helpText: asleep ? 'In slaap gevallen' : 'Wakker geworden',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (asleep) {
        _asleep = picked;
      } else {
        _woke = picked;
      }
      _error = null;
    });
  }

  void _save() {
    final night = _night;
    final length = night.wokeAt.difference(night.fellAsleepAt);
    if (length < kShortestNight || length > kLongestNight) {
      setState(
        () => _error =
            'Een nacht van ${nightLength(length)} klopt waarschijnlijk niet. '
            'Kijk de twee tijden na.',
      );
      return;
    }

    int? light;
    int? rem;
    int? deep;
    if (widget.stages) {
      final fields = [_light, _rem, _deep];
      final parsed = [for (final f in fields) parseStageMinutes(f.text)];
      for (var i = 0; i < fields.length; i++) {
        if (fields[i].text.trim().isNotEmpty && parsed[i] == null) {
          setState(
            () => _error =
                'Schrijf een fase als uren en minuten, zoals 1:20, of als '
                'minuten, zoals 80.',
          );
          return;
        }
      }
      final total = parsed.fold<int>(0, (sum, m) => sum + (m ?? 0));
      // A few minutes over is a watch rounding; an hour over is a typo.
      if (total > length.inMinutes + 15) {
        setState(
          () => _error =
              'De fasen samen (${nightLength(Duration(minutes: total))}) '
              'zijn langer dan de nacht zelf.',
        );
        return;
      }
      (light, rem, deep) = (parsed[0], parsed[1], parsed[2]);
    }

    Navigator.of(context).pop(
      _SleepAnswer.night(
        fellAsleepAt: night.fellAsleepAt,
        wokeAt: night.wokeAt,
        light: light,
        rem: rem,
        deep: deep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = _night;
    final length = night.wokeAt.difference(night.fellAsleepAt);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('In slaap gevallen'),
            trailing: Text(
              _asleep.format(context),
              style: theme.textTheme.titleMedium,
            ),
            onTap: () => _pick(asleep: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Wakker geworden'),
            trailing: Text(
              _woke.format(context),
              style: theme.textTheme.titleMedium,
            ),
            onTap: () => _pick(asleep: false),
          ),
          Text(
            'Samen ${nightLength(length)} slaap.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.stages) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Slaapfasen, als je ze weet',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Van je horloge of je app, als 1:20 of als 80. Leeg laten mag. '
              'Ze worden bewaard en getoond; de schatting kijkt alleen naar '
              'hoe lang je sliep.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final (label, controller) in [
                  ('Licht', _light),
                  ('REM', _rem),
                  ('Diep', _deep),
                ]) ...[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: label,
                        hintText: 'u:mm',
                      ),
                    ),
                  ),
                  if (label != 'Diep') const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Opslaan')),
          if (widget.existing != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(const _SleepAnswer.forget()),
              child: const Text('Deze nacht verwijderen'),
            ),
        ],
      ),
    );
  }
}
