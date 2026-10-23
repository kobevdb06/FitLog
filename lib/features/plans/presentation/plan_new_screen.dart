import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/schedule.dart';
import '../../../core/db/dao/plans_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/coach_session.dart';

const _uuid = Uuid();

/// How long the goal may be: a few sentences, not an essay to pay for with
/// every question in the conversation.
const int kPlanGoalLength = 600;

/// The first message of a schema's conversation: the form, in words.
///
/// Written as the user would say it, and kept as their question, so the
/// conversation shows what the coach was asked.
String planRequest({
  required String goal,
  required PlanSplit split,
  String? splitNote,
  required WeekdaySet days,
  required PlanProgression progression,
}) {
  final names = [
    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
      if (days.has(d)) Formatters.weekdayName(d),
  ];
  final dayList = names.length < 2
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} en ${names.last}';
  return [
    'Maak een schema voor me.',
    'Wat ik wil: ${goal.trim()}',
    'Split: ${switch (split) {
      PlanSplit.coach => 'kies jij',
      PlanSplit.custom => 'zelf gekozen: ${splitNote?.trim() ?? ''}',
      _ => split.label,
    }}',
    'Dagen: $dayList',
    'Gewichten en herhalingen bijstellen: ${switch (progression) {
      PlanProgression.app => 'FitLog',
      PlanProgression.coach => 'jij, elke zondag',
    }}',
  ].join('\n');
}

/// Nieuw schema: what you want, how to divide it, which days, and who keeps
/// the numbers up to date. The coach then lays it out in a conversation of
/// its own, and nothing is followed until you start it.
class PlanNewScreen extends ConsumerStatefulWidget {
  const PlanNewScreen({super.key});

  @override
  ConsumerState<PlanNewScreen> createState() => _PlanNewScreenState();
}

class _PlanNewScreenState extends ConsumerState<PlanNewScreen> {
  final _goal = TextEditingController();
  final _custom = TextEditingController();
  var _split = PlanSplit.coach;
  var _days = WeekdaySet.none;
  var _progression = PlanProgression.app;
  String? _goalError;
  String? _customError;
  String? _daysError;
  bool _busy = false;

  @override
  void dispose() {
    _goal.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _goalError = _goal.text.trim().isEmpty
          ? 'Schrijf wat je met dit schema wil bereiken.'
          : null;
      _customError = _split == PlanSplit.custom && _custom.text.trim().isEmpty
          ? 'Beschrijf welke split je wil.'
          : null;
      _daysError = _days.mask == 0 ? 'Kies minstens één dag.' : null;
    });
    if (_goalError != null || _customError != null || _daysError != null) {
      return;
    }
    if (!ref.read(coachEnabledProvider)) {
      unawaited(context.push(Routes.coachKey));
      return;
    }

    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final planId = _uuid.v4();
    final threadId = _uuid.v4();
    await db.plansDao.createDraft(
      id: planId,
      goal: _goal.text,
      split: _split,
      splitNote: _custom.text,
      days: _days.mask,
      progression: _progression,
      at: DateTime.now(),
    );
    await db.chatDao.createThread(threadId, PlansDao.unnamed, planId: planId);

    // Read before leaving: this screen is gone once the chat is shown.
    final coach = ref.read(coachControllerProvider.notifier);
    ref.read(coachSessionControllerProvider.notifier).show(threadId);
    final question = planRequest(
      goal: _goal.text,
      split: _split,
      splitNote: _custom.text,
      days: _days,
      progression: _progression,
    );
    if (!mounted) return;
    context.go(Routes.chat);
    unawaited(coach.ask(threadId: threadId, question: question));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final enabled = ref.watch(coachEnabledProvider);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Nieuw schema')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          if (!enabled)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Een schema maakt de coach, met je eigen sleutel. Zet '
                    'hem eerst aan.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.push(Routes.coachKey),
                    child: const Text('Coach aanzetten'),
                  ),
                ],
              ),
            ),
          heading('Wat wil je bereiken?'),
          TextField(
            controller: _goal,
            minLines: 3,
            maxLines: 6,
            maxLength: kPlanGoalLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Sterker op bench en squat, en wat breder in de rug. Mijn '
                  'linkerschouder doet soms pijn bij overhead press.',
              errorText: _goalError,
            ),
            onChanged: (_) {
              if (_goalError != null) setState(() => _goalError = null);
            },
          ),
          heading('Split'),
          RadioGroup<PlanSplit>(
            groupValue: _split,
            onChanged: (split) => setState(() {
              _split = split ?? _split;
              _customError = null;
            }),
            child: Column(
              children: [
                for (final split in PlanSplit.values)
                  RadioListTile<PlanSplit>(
                    value: split,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      split == PlanSplit.custom
                          ? 'Custom: je eigen split'
                          : split.label,
                    ),
                  ),
              ],
            ),
          ),
          if (_split == PlanSplit.custom)
            TextField(
              controller: _custom,
              maxLines: 3,
              minLines: 1,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Borst en rug, schouders en armen, benen',
                errorText: _customError,
              ),
              onChanged: (_) {
                if (_customError != null) setState(() => _customError = null);
              },
            ),
          heading('Trainingsdagen'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                FilterChip(
                  label: Text(Formatters.weekdayShort(d)),
                  selected: _days.has(d),
                  onSelected: (_) => setState(() {
                    _days = _days.toggle(d);
                    _daysError = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _daysError ??
                'Een richtlijn: een sessie op een andere dag telt gewoon mee.',
            style: _daysError == null
                ? muted
                : theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
          ),
          heading('Gewichten en herhalingen bijstellen'),
          SegmentedButton<PlanProgression>(
            segments: const [
              ButtonSegment(value: PlanProgression.app, label: Text('FitLog')),
              ButtonSegment(value: PlanProgression.coach, label: Text('Coach')),
            ],
            selected: {_progression},
            onSelectionChanged: (picked) =>
                setState(() => _progression = picked.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(switch (_progression) {
            PlanProgression.app =>
              'Gratis: FitLog rekent elke week uit wat je deed. Eerst de '
                  'herhalingen, dan het gewicht.',
            PlanProgression.coach =>
              'De coach stelt elke zondag de volgende week bij. Dat kost een '
                  'vraag per week.',
          }, style: muted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'De lengte kiest de coach, meestal met een deloadweek op het '
            'einde. Je ziet alles voor het begint.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Bespreek met de coach'),
            ),
          ),
        ],
      ),
    );
  }
}
