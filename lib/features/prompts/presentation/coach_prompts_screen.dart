/// Instellingen → AI-coach → Geplande prompts: what the coach is asked at a
/// moment, in the user's own words, the screen of one moment, and the
/// user's own quick questions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/week_navigator.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/coach_session.dart';
import '../../morning/presentation/morning_providers.dart';
import '../../review/data/week_alarm.dart';
import '../../review/presentation/review_providers.dart';
import '../data/moment_facts.dart';
import '../domain/coach_moments.dart';
import 'moment_answer_card.dart';
import 'prompt_notify.dart';
import 'prompt_providers.dart';

/// The longest prompt: a few sentences, not a second system prompt.
const int kMomentPromptLength = 500;

/// The longest quick question, and how many there can be: a row of buttons,
/// not a second chat.
const int kQuickQuestionLength = 200;
const int kQuickQuestionMax = 10;

/// Stores [prompt] with what changed. Words or a length equal to the
/// moment's own are stored as its own, so a later version of the app can
/// still improve them.
Future<void> saveMomentPrompt(
  AppDatabase db,
  MomentPrompt prompt, {
  bool? enabled,
  String? text,
  AnswerLength? length,
  String? option,
}) {
  final moment = prompt.moment;
  final words = (text ?? prompt.text).trim();
  final chosen = length ?? prompt.length;
  return db.coachPromptsDao.savePrompt(
    moment: moment,
    enabled: enabled ?? prompt.enabled,
    prompt: words.isEmpty || words == moment.defaultPrompt ? null : words,
    length: chosen == moment.defaultLength ? null : chosen,
    option: option ?? prompt.option,
  );
}

/// Whether [moment] comes with the alarm: then a change moves the alarm.
bool _alarmed(CoachMoment moment) =>
    moment == CoachMoment.idle ||
    moment == CoachMoment.free ||
    moment == CoachMoment.month;

/// Stores [prompt] switched [on] or off, and keeps the alarm in step.
Future<void> switchMoment(WidgetRef ref, MomentPrompt prompt, bool on) async {
  await saveMomentPrompt(ref.read(databaseProvider), prompt, enabled: on);
  if (!_alarmed(prompt.moment)) return;
  final notify = ref.read(promptNotifyProvider);
  await (on ? notify.switchedOn() : notify.syncAlarm());
}

class CoachPromptsScreen extends ConsumerWidget {
  const CoachPromptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prompts = ref.watch(momentPromptsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Geplande prompts')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              'Op een vast moment vraagt FitLog de coach iets, in jouw '
              'woorden. Elke prompt is één vraag op je eigen sleutel, en telt '
              'mee op je daglimiet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final group in MomentGroup.values) ...[
            SectionHeader(group.label),
            for (final prompt in prompts ?? const <MomentPrompt>[])
              if (prompt.moment.group == group) _MomentTile(prompt: prompt),
          ],
          const SectionHeader('Eigen snelle vragen'),
          const _QuickQuestionsEditor(),
        ],
      ),
    );
  }
}

class _MomentTile extends ConsumerWidget {
  const _MomentTile({required this.prompt});

  final MomentPrompt prompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    isThreeLine: true,
    title: Text(prompt.moment.title),
    subtitle: Text(
      '${prompt.moment.when}\n${prompt.enabled ? prompt.text : 'Uit'}',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Switch(
      value: prompt.enabled,
      onChanged: (on) => switchMoment(ref, prompt, on),
    ),
    onTap: () => context.push(Routes.coachPrompt(prompt.moment.wire)),
  );
}

/// The user's own questions: a row of buttons in the coach, one tap asks.
class _QuickQuestionsEditor extends ConsumerWidget {
  const _QuickQuestionsEditor();

  Future<String?> _ask(BuildContext context, {String? question}) =>
      promptForText(
        context,
        title: question == null ? 'Vraag toevoegen' : 'Vraag aanpassen',
        initialValue: question,
        hintText: 'Hoeveel sets heb ik deze week nog nodig voor mijn rug?',
        maxLength: kQuickQuestionLength,
        maxLines: 3,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final own = ref.watch(quickQuestionsProvider).value ?? const [];
    final dao = ref.read(databaseProvider).coachPromptsDao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            'Je eigen vragen staan als knopjes in de coach. Er gebeurt niets '
            'vanzelf: één tik, en de vraag is gesteld.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final question in own)
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: Text(question.question),
            onTap: () async {
              final changed = await _ask(context, question: question.question);
              final words = changed?.trim();
              if (words != null && words.isNotEmpty) {
                await dao.changeQuickQuestion(question.id, words);
              }
            },
            trailing: IconButton(
              tooltip: 'Verwijderen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => dao.deleteQuickQuestion(question.id),
            ),
          ),
        if (own.length < kQuickQuestionMax)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: () async {
                  final words = (await _ask(context))?.trim();
                  if (words != null && words.isNotEmpty) {
                    await dao.addQuickQuestion(words);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Vraag toevoegen'),
              ),
            ),
          ),
      ],
    );
  }
}

/// One moment: on or off, the words, the length, when, what goes along,
/// and a way to try it.
class MomentPromptScreen extends ConsumerStatefulWidget {
  const MomentPromptScreen({super.key, required this.wire});

  /// The moment, as it is in the route.
  final String wire;

  @override
  ConsumerState<MomentPromptScreen> createState() => _MomentPromptScreenState();
}

class _MomentPromptScreenState extends ConsumerState<MomentPromptScreen> {
  final _field = TextEditingController();

  /// Words not stored yet: they are kept a moment after the last key, and
  /// at once when the screen goes.
  Timer? _pending;
  bool _filled = false;

  CoachMoment? get _moment => CoachMoment.fromWire(widget.wire);

  @override
  void dispose() {
    if (_pending?.isActive ?? false) {
      _pending!.cancel();
      _storeWords();
    }
    _field.dispose();
    super.dispose();
  }

  void _storeWords() {
    final moment = _moment;
    if (moment == null) return;
    final prompt = ref.read(momentPromptProvider(moment));
    if (prompt == null) return;
    saveMomentPrompt(ref.read(databaseProvider), prompt, text: _field.text);
  }

  void _typed(String _) {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 600), _storeWords);
  }

  void _fill(MomentPrompt prompt, String words) {
    _pending?.cancel();
    _field.text = words;
    saveMomentPrompt(ref.read(databaseProvider), prompt, text: words);
  }

  /// Keeps the words in the field now, also when the last key was a moment
  /// ago: what is tried is what is there.
  Future<void> _keepWords() async {
    final moment = _moment;
    final prompt = moment == null
        ? null
        : ref.read(momentPromptProvider(moment));
    if (prompt == null) return;
    _pending?.cancel();
    await saveMomentPrompt(
      ref.read(databaseProvider),
      prompt,
      text: _field.text,
    );
  }

  Future<void> _setOption(MomentPrompt prompt, String option) async {
    await saveMomentPrompt(ref.read(databaseProvider), prompt, option: option);
    await ref.read(promptNotifyProvider).syncAlarm();
  }

  Future<void> _tryMorning() async {
    await _keepWords();
    if (!mounted) return;
    await ref.read(morningControllerProvider.notifier).makeNow();
  }

  Future<void> _tryWeek(DateTime start) async {
    await _keepWords();
    if (!mounted) return;
    await ref.read(weekReviewControllerProvider.notifier).write(start);
  }

  @override
  Widget build(BuildContext context) {
    final moment = _moment;
    if (moment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.help_outline,
          title: 'Deze prompt bestaat niet',
          message: 'Kies er een uit de lijst.',
        ),
      );
    }
    final prompt = ref.watch(momentPromptProvider(moment));
    if (prompt == null) {
      return Scaffold(appBar: AppBar(title: Text(moment.title)));
    }
    if (!_filled) {
      _filled = true;
      _field.text = prompt.text;
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final settings = ref.watch(settingsProvider).value;
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(moment.title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          SwitchListTile(
            title: Text(moment.switchTitle),
            subtitle: Text(moment.switchHint),
            value: prompt.enabled,
            onChanged: (on) => switchMoment(ref, prompt, on),
          ),
          if (moment == CoachMoment.idle) ...[
            const SectionHeader('Wanneer'),
            ListTile(
              title: Text('Na ${prompt.idleDays} dagen zonder training'),
              subtitle: const Text(
                'Om 18:00, één keer per keer dat je stilvalt.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Slider(
                value: prompt.idleDays.toDouble(),
                min: kIdleDaysMin.toDouble(),
                max: kIdleDaysMax.toDouble(),
                divisions: kIdleDaysMax - kIdleDaysMin,
                label: '${prompt.idleDays} dagen',
                onChanged: (days) => _setOption(prompt, '${days.round()}'),
              ),
            ),
          ],
          if (moment == CoachMoment.free) ...[
            const SectionHeader('Wanneer'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    ChoiceChip(
                      label: Text(Formatters.weekdayName(day)),
                      selected: prompt.freeTime.weekday == day,
                      onSelected: (_) => _setOption(
                        prompt,
                        freeTimeOption((
                          weekday: day,
                          hour: prompt.freeTime.hour,
                        )),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Uur'),
              subtitle: Text('${prompt.freeTime.hour}:00'),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: prompt.freeTime.hour, minute: 0),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (picked == null) return;
                await _setOption(
                  prompt,
                  freeTimeOption((
                    weekday: prompt.freeTime.weekday,
                    hour: picked.hour,
                  )),
                );
              },
            ),
          ],
          const SectionHeader('Je prompt'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _field,
              onChanged: _typed,
              minLines: 3,
              maxLines: 6,
              maxLength: kMomentPromptLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: moment.defaultPrompt,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final example in moment.examples)
                  ActionChip(
                    label: Text(example.label),
                    onPressed: () => _fill(prompt, example.prompt),
                  ),
                if (prompt.custom != null)
                  ActionChip(
                    avatar: const Icon(Icons.undo, size: 18),
                    label: const Text('De gewone'),
                    onPressed: () => _fill(prompt, moment.defaultPrompt),
                  ),
              ],
            ),
          ),
          const SectionHeader('Lengte'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<AnswerLength>(
              showSelectedIcon: false,
              segments: [
                for (final length in AnswerLength.values)
                  ButtonSegment(value: length, label: Text(length.label)),
              ],
              selected: {prompt.length},
              onSelectionChanged: (chosen) =>
                  saveMomentPrompt(db, prompt, length: chosen.single),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              0,
            ),
            child: Text(switch (prompt.length) {
              AnswerLength.short => 'Hoogstens drie korte zinnen.',
              AnswerLength.normal => 'Hoogstens vijf zinnen.',
              AnswerLength.long =>
                'Hoogstens tien zinnen, eventueel een korte opsomming.',
            }, style: muted),
          ),
          const SectionHeader('Wat de coach krijgt'),
          for (final line in momentGets(
            moment,
            profile: settings?.coachSeesProfile ?? false,
            health: settings?.coachSeesHealth ?? false,
            memory: settings?.coachMemory ?? true,
          ))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              'Wat je deelt, kies je onder AI-coach → Wat de coach over je '
              'weet. FitLog rekent de cijfers; de coach zoekt niets zelf op.',
              style: muted,
            ),
          ),
          const SectionHeader('Uitproberen'),
          switch (moment) {
            CoachMoment.morning => _TryReport(
              moment: moment,
              on: prompt.enabled,
              onTry: _tryMorning,
            ),
            CoachMoment.week => _TryReport(
              moment: moment,
              on: prompt.enabled,
              onTry: () => _tryWeek(weekStartOf(lastSundayEvening(_now()))),
            ),
            _ => _TryMoment(moment: moment, keepWords: _keepWords),
          },
        ],
      ),
    );
  }
}

DateTime _now() => DateTime.now();

/// What a prompt at [moment] is tried on, worked out when the screen opens.
final _trySubjectProvider = FutureProvider.autoDispose
    .family<TrySubject, CoachMoment>((ref, moment) async {
      final settings = await ref.watch(settingsProvider.future);
      return trySubject(
        ref.watch(databaseProvider),
        moment,
        health: settings.coachSeesHealth,
        now: DateTime.now(),
      );
    });

/// The prompt as it stands, asked about the newest thing it could be about;
/// the answer takes the place of what was there. In the chat, a try is a
/// conversation of its own.
class _TryMoment extends ConsumerWidget {
  const _TryMoment({required this.moment, required this.keepWords});

  final CoachMoment moment;
  final Future<void> Function() keepWords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final found = ref.watch(_trySubjectProvider(moment)).value;
    if (found == null) return const SizedBox.shrink();
    final subject = found.subject;
    final hasCoach = ref.watch(coachApiKeyProvider) != null;
    final busy =
        subject != null && ref.watch(momentAskProvider(moment, subject)).busy;
    final thread = subject == null
        ? null
        : ref.watch(momentAnswerProvider(moment, subject)).value?.threadId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            !hasCoach
                ? 'Zet eerst de coach aan met je sleutel.'
                : subject == null
                ? found.note
                : '${found.note} Dat is één vraag, en het antwoord komt in de '
                      'plaats van wat er stond.',
            style: muted,
          ),
          if (subject != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: !hasCoach || busy
                  ? null
                  : () async {
                      await keepWords();
                      await ref
                          .read(momentAskProvider(moment, subject).notifier)
                          .ask();
                    },
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_outlined),
              // Short: the line above says on what, and on a narrow phone
              // with large text a longer label took two lines.
              label: const Text('Uitproberen'),
            ),
            const SizedBox(height: AppSpacing.md),
            if (thread != null)
              FilledButton.tonalIcon(
                onPressed: () {
                  ref
                      .read(coachSessionControllerProvider.notifier)
                      .show(thread);
                  context.go(Routes.chat);
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Open het gesprek'),
              )
            else
              MomentAnswerCard(
                moment: moment,
                subject: subject,
                actions: false,
              ),
          ],
        ],
      ),
    );
  }
}

/// The morning report of today or the last week that is over, written
/// again with the prompt as it stands: what was there makes way for it.
///
/// Only with the question on: off, there is nothing to ask.
class _TryReport extends ConsumerWidget {
  const _TryReport({
    required this.moment,
    required this.on,
    required this.onTry,
  });

  /// The morning or the week.
  final CoachMoment moment;
  final bool on;
  final Future<void> Function() onTry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final hasCoach = ref.watch(coachApiKeyProvider) != null;
    final morning = moment == CoachMoment.morning;
    final busy = morning
        ? ref.watch(morningControllerProvider).busy
        : ref.watch(weekReviewControllerProvider).busy;

    final String? text;
    final String? error;
    if (morning) {
      final reports = ref.watch(morningReportsProvider).value ?? const [];
      final today = DateUtils.dateOnly(DateTime.now());
      final report = reports.isNotEmpty && reports.first.facts.day == today
          ? reports.first
          : null;
      text = report?.coachText;
      error = report?.coachError ?? ref.watch(morningControllerProvider).error;
    } else {
      final start = weekStartOf(lastSundayEvening(DateTime.now()));
      final review = ref.watch(weekReviewProvider(start)).value;
      text = review?.coachText;
      error =
          review?.coachError ?? ref.watch(weekReviewControllerProvider).error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            !hasCoach
                ? 'Zet eerst de coach aan met je sleutel.'
                : !on
                ? 'Zet de prompt eerst aan om hem uit te proberen.'
                : morning
                ? 'Stelt het rapport van vandaag opnieuw op. Dat is één vraag.'
                : 'Schrijft het overzicht van je laatste week opnieuw. Dat '
                      'is één vraag.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: !hasCoach || !on || busy ? null : onTry,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_outlined),
            // Short: the line above says on what, and on a narrow phone
            // with large text a longer label took two lines.
            label: const Text('Uitproberen'),
          ),
          if (text != null || error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.4),
              child: Text(
                text ?? error!,
                style: text != null
                    ? theme.textTheme.bodyMedium
                    : muted?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
