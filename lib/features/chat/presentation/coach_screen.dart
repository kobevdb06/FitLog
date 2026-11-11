/// The conversation with the coach.
///
/// It only exists once the user has entered an API key of their own. Every
/// answer says underneath it what the coach looked up in the database and
/// what the question cost, because both are the user's: their data and their
/// money.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../deload/presentation/deload_providers.dart';
import '../../deload/presentation/deload_start_sheet.dart';
import '../../../core/photos/photo_store.dart';
import '../../../core/photos/picked_copy.dart';
import '../../plans/presentation/plan_build_cards.dart';
import '../../plans/presentation/plan_card.dart';
import '../../plans/presentation/plan_panel.dart';
import '../../routines/presentation/routine_start.dart';
import '../../workout/presentation/workout_providers.dart';
import '../../prompts/domain/coach_moments.dart';
import '../data/ai_client.dart';
import '../data/coach_tools.dart' show routineForCoach;
import '../data/command_facts.dart';
import '../domain/coach_budget.dart';
import '../domain/coach_commands.dart';
import '../domain/coach_proposal.dart';
import '../domain/coach_suggestions.dart';
import '../../../routing/routes.dart';
import 'chat_providers.dart';
import 'coach_drawer.dart';
import 'coach_memory_screen.dart';
import 'coach_session.dart';
import 'photo_prompts_sheet.dart';
import 'report_answer_sheet.dart';
import '../../prompts/presentation/prompt_providers.dart';
import '../../../core/widgets/photo_image.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _controller = TextEditingController();

  /// Every conversation opens on its newest line, not where another one was
  /// left: nothing is kept to put back.
  final _scroll = ScrollController(keepScrollOffset: false);

  CoachSessionController get _session =>
      ref.read(coachSessionControllerProvider.notifier);

  /// Photos picked but not sent yet, as file names in the photo directory,
  /// in the order they were picked.
  final List<String> _photos = [];

  /// The answer as it was written, kept on screen until the stored one is in
  /// the list: between the two, it would blink away for a frame.
  String? _held;

  /// When the question that [_held] answers was sent. The stored answer is
  /// the first of the coach's after it.
  var _askedAt = 0;

  /// What the last command said back, or null.
  _Reply? _reply;

  /// The session of the schema the next question is about, put above the
  /// field with Bespreek in the panel.
  RoutineRow? _about;

  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(coachDraftProvider, (_, draft) {
      // Not while the tree is being built: taking the draft clears it.
      if (draft != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _takeDraft());
      }
    }, fireImmediately: true);
  }

  /// Puts the waiting question in the field of a new conversation. Sending
  /// it is left to the user.
  void _takeDraft() {
    if (!mounted) return;
    final draft = ref.read(coachDraftProvider);
    if (draft == null) return;
    ref.read(coachDraftProvider.notifier).clear();
    _session.startNew();
    setState(_photos.clear);
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// What the field sends: a command when it starts with a /, a question
  /// otherwise. Nothing while the coach is still writing.
  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty || ref.read(coachControllerProvider).sending) return;
    final typed = readCommand(question, own: _ownCommands());
    if (typed != null) return _run(typed);
    await _ask(question);
  }

  /// Your quick questions that have a name to ask them by.
  Map<String, String> _ownCommands() => {
    for (final row
        in ref.read(quickQuestionsProvider).value ?? const <QuickQuestionRow>[])
      ?row.command: row.question,
  };

  Future<void> _ask(String question) async {
    final controller = ref.read(coachControllerProvider.notifier);
    final thread = await _session.threadFor(question);
    // A session put up for discussion goes along as the coach reads one, so
    // it need not look it up; the question says which it was about.
    final about = _about;
    final content = about == null
        ? null
        : await routineForCoach(ref.read(databaseProvider), about.id);
    if (!mounted) return;

    final photos = List.of(_photos);
    _controller.clear();
    setState(() {
      _photos.clear();
      _held = null;
      _reply = null;
      _about = null;
      _askedAt = DateTime.now().millisecondsSinceEpoch;
    });
    // Your question is at the bottom, so that is where you go.
    _toBottom();
    await controller.ask(
      threadId: thread,
      question: about == null ? question : 'Over ${about.name}: $question',
      imageFiles: photos,
      situation: about == null
          ? null
          : 'de gebruiker vraagt over de sessie "${about.name}" van dit '
                'schema, zoals ze nu staat: ${jsonEncode(content)}',
      sent: [if (about != null) 'de sessie ${about.name}'],
    );
    _toBottom();
  }

  /// The panel of the schema this conversation is about.
  void _openPanel(String planId) => showPlanPanel(
    context,
    planId: planId,
    onStart: (id) => startSession(context, ref, routineId: id),
    onOpen: (id) => context.push(Routes.routineEdit(id)),
    onDiscuss: (session) => setState(() => _about = session),
  );

  /// Does what a command says. The free ones stay on the phone; the ones
  /// that ask go to the coach the way a question does. Something that is
  /// no command stays in the field, and nothing goes out.
  Future<void> _run(TypedCommand typed) async {
    setState(() => _reply = null);
    switch (typed) {
      case NoCommand(:final typed):
        _say('Geen commando: $typed. Met /help zie je ze allemaal.');
      case OwnCommand(:final question):
        await _ask(question);
      case AppCommand(:final command, :final argument):
        await _runApp(command, argument);
    }
  }

  void _say(String text) {
    if (mounted) setState(() => _reply = _Reply(text: text));
  }

  Future<void> _runApp(CoachCommand command, String argument) async {
    final db = ref.read(databaseProvider);
    final threadId = ref.read(coachSessionControllerProvider).threadId;
    final thread = threadId == null ? null : await db.chatDao.thread(threadId);
    if (!mounted) return;

    switch (command) {
      case CoachCommand.nieuw:
        _controller.clear();
        _session.startNew();
      case CoachCommand.onthoud:
        await _remember(argument);
      case CoachCommand.geheugen:
        _controller.clear();
        unawaited(context.push(Routes.coachMemory));
      case CoachCommand.kosten:
        _controller.clear();
        await _costs(thread);
      case CoachCommand.pin:
        if (_ownThread(thread) case final mine?) {
          _controller.clear();
          await db.chatDao.setPinned(mine.id, !mine.pinned);
          _say(
            mine.pinned
                ? 'Losgemaakt.'
                : 'Vastgepind: het staat bovenaan in het paneel.',
          );
        }
      case CoachCommand.map:
        if (_ownThread(thread) case final mine?) {
          if (argument.isEmpty) {
            _say('Zet de naam van de map erachter, zoals /map Techniek.');
            return;
          }
          final folder = await db.chatDao.folderNamed(argument);
          if (folder == null) return;
          await db.chatDao.moveToFolder(mine.id, folder);
          await db.chatDao.setFolderCollapsed(folder, false);
          final name = (await db.chatDao.folders())
              .firstWhere((f) => f.id == folder)
              .name;
          _controller.clear();
          _say('In de map "$name".');
        }
      case CoachCommand.help:
        _controller.clear();
        await _help(inPlan: thread?.planId != null);
      case CoachCommand.samenvat:
        if (thread == null || (await db.chatDao.messages(thread.id)).isEmpty) {
          _say('Er is nog niets om samen te vatten.');
          return;
        }
        if (thread.planId != null) {
          _say(
            'Het gesprek van een schema hoort bij dat schema: samenvatten in '
            'een nieuw gesprek kan daar niet.',
          );
          return;
        }
        _controller.clear();
        final fresh = await ref
            .read(coachControllerProvider.notifier)
            .summarize(thread.id);
        if (fresh != null && mounted) _session.show(fresh);
      case CoachCommand.workout || CoachCommand.week || CoachCommand.maand:
        await _askAbout(command);
      case CoachCommand.schema:
        if (thread?.planId == null) {
          _say(
            "/schema werkt in het gesprek van een schema. Je vindt ze onder "
            "Schema's in het paneel.",
          );
          return;
        }
        await _ask('Geef een stand van zaken van dit schema.');
    }
  }

  /// A conversation of your own to pin or put away, or null with the
  /// reason said: there is none yet, or it is the one of a schema.
  ChatThreadRow? _ownThread(ChatThreadRow? thread) {
    if (thread == null) {
      _say('Er is nog geen gesprek: stel eerst een vraag.');
      return null;
    }
    if (thread.planId != null) {
      _say(
        "Het gesprek van een schema staat onder Schema's, niet bij je chats.",
      );
      return null;
    }
    return thread;
  }

  /// /onthoud: into the coach's notebook, with the card the coach's own
  /// notes get. Full is full, as it is for the coach.
  Future<void> _remember(String text) async {
    if (text.isEmpty) {
      _say(
        'Zet erachter wat de coach moet onthouden, zoals /onthoud ik train '
        'thuis met dumbbells.',
      );
      return;
    }
    final db = ref.read(databaseProvider);
    if (!(await db.settingsDao.getSettings()).coachMemory) {
      _say(
        'Het geheugen van de coach staat uit. Je zet het aan bij '
        'Instellingen → AI-coach.',
      );
      return;
    }
    final count = await db.coachNotesDao.count();
    if (count >= kCoachNoteMax) {
      _say(
        'Het geheugen is vol: $kCoachNoteMax notities. Pas er een aan of '
        'vergeet er een, met /geheugen.',
      );
      return;
    }
    final id = await db.coachNotesDao.add(text);
    if (!mounted) return;
    _controller.clear();
    setState(
      () => _reply = _Reply(
        note: NoteProposal(
          id: id,
          text: CoachNotesDao.clean(text),
          kind: CoachNoteKind.other.wire,
          action: NoteAction.made,
          first: count == 0,
        ),
      ),
    );
  }

  /// /kosten: what this conversation and today cost, counted on the phone.
  Future<void> _costs(ChatThreadRow? thread) async {
    final db = ref.read(databaseProvider);
    final provider = ref.read(coachProviderProvider);
    final service = provider == CoachProvider.gemini ? 'Google' : 'Anthropic';
    final limit = ref.read(coachDailyLimitProvider);
    final today = await db.chatDao.usageSince(
      coachDayStart(DateTime.now(), provider),
    );
    final here = thread == null
        ? null
        : await db.chatDao.threadUsage(thread.id);

    String tokens(int input, int output) =>
        '${Formatters.number(input.toDouble())} tokens in en '
        '${Formatters.number(output.toDouble())} uit';
    _say(
      [
        if (here != null && here.answers > 0)
          'Dit gesprek: '
              '${Formatters.amount(here.answers, 'antwoord', 'antwoorden')}, '
              '${Formatters.amount(here.requests, 'vraag', 'vragen')} aan '
              '$service, ${tokens(here.inputTokens, here.outputTokens)}.'
        else
          'Dit gesprek kostte nog niets.',
        'Vandaag: ${today.requests} van je $limit vragen aan $service, '
            '${tokens(today.inputTokens, today.outputTokens)}.',
      ].join('\n'),
    );
  }

  /// /workout, /week and /maand: the facts and the prompt of their geplande
  /// moment - also when it is off - with the answer in this conversation.
  Future<void> _askAbout(CoachCommand command) async {
    final db = ref.read(databaseProvider);
    final about = await commandFacts(db, command, now: DateTime.now());
    final facts = about.facts;
    if (facts == null) {
      _say(about.none!);
      return;
    }
    final prompt = await MomentPrompt.load(db, momentOf(command)!);
    final thread = await _session.threadFor(prompt.text);
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _held = null;
      _askedAt = DateTime.now().millisecondsSinceEpoch;
    });
    _toBottom();
    await ref
        .read(coachControllerProvider.notifier)
        .askAbout(
          threadId: thread,
          prompt: prompt,
          facts: facts,
          sent: about.sent,
          withWeightUnit: command != CoachCommand.week,
        );
    _toBottom();
  }

  /// /help: every command, your own too. A tap puts it in the field.
  Future<void> _help({required bool inPlan}) async {
    final own = [
      for (final row
          in ref.read(quickQuestionsProvider).value ??
              const <QuickQuestionRow>[])
        if (row.command != null) row,
    ];
    final picked = await showAppSheet<String>(
      context: context,
      title: "Commando's",
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Typ / in het veld. Gratis blijft op je gsm; 1 vraag gaat naar '
              'de coach en telt op je daglimiet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final command in CoachCommand.values)
            if (!command.onlyInPlan || inPlan)
              _CommandRow(
                typed: command.typed,
                argument: command.argument,
                about: command.about,
                asks: command.asks,
                onTap: () => Navigator.of(context).pop(
                  command.argument == null
                      ? command.typed
                      : '${command.typed} ',
                ),
              ),
          for (final row in own)
            _CommandRow(
              typed: '/${row.command}',
              about: 'Jouw vraag: ${row.question}',
              asks: true,
              onTap: () => Navigator.of(context).pop('/${row.command}'),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    _controller.value = TextEditingValue(
      text: picked,
      selection: TextSelection.collapsed(offset: picked.length),
    );
  }

  /// Picks photos to ask about, up to [CoachController.photosPerQuestion].
  /// They are stored straight away and shown above the field, so what is
  /// about to be sent is visible before it goes.
  Future<void> _pickPhoto() async {
    final room = CoachController.photosPerQuestion - _photos.length;
    if (room <= 0) return;
    final source = await showAppSheet<ImageSource>(
      context: context,
      title: room == CoachController.photosPerQuestion
          ? "Welke foto's?"
          : room == 1
          ? 'Nog één foto'
          : "Nog $room foto's",
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Nu een foto maken'),
            subtitle: const Text('Bijvoorbeeld van een toestel in de zaal'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Uit je galerij'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    // From the gallery several at once, never more than there is room for;
    // the camera takes one at a time.
    final picked = source == ImageSource.gallery
        ? room == 1
              ? [?await picker.pickImage(source: source, maxWidth: 2400)]
              : await picker.pickMultiImage(maxWidth: 2400, limit: room)
        : [?await picker.pickImage(source: source, maxWidth: 2400)];
    if (picked.isEmpty || !mounted) return;

    final coach = ref.read(coachControllerProvider.notifier);
    final stored = <String>[];
    for (final file in picked) {
      try {
        if (stored.length < room) {
          if (await coach.importPhoto(File(file.path)) case final name?) {
            stored.add(name);
          }
        }
      } finally {
        await forgetPickedCopy(file.path);
      }
    }
    if (mounted) setState(() => _photos.addAll(stored));
  }

  /// To the newest line: the list is reversed, so that is where it starts.
  void _toBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachControllerProvider);
    final session = ref.watch(coachSessionControllerProvider);
    final threadId = session.threadId;
    final messages = threadId == null
        ? const <ChatMessageRow>[]
        : ref.watch(chatMessagesProvider(threadId)).value ?? const [];
    final running = ref.watch(activeWorkoutProvider).value?.workout;
    final ofWorkout = running != null && running.id == session.workoutId;
    final own = [
      for (final row
          in ref.watch(quickQuestionsProvider).value ??
              const <QuickQuestionRow>[])
        if (row.command != null) row,
    ];
    final planId = (ref.watch(chatThreadsProvider).value ?? const [])
        .where((t) => t.id == threadId)
        .firstOrNull
        ?.planId;
    final inPlan = planId != null;
    ref.listen<CoachState>(coachControllerProvider, (previous, next) {
      if (previous == null) return;
      if (previous.sending &&
          !next.sending &&
          next.error == null &&
          previous.answer.isNotEmpty) {
        setState(() => _held = previous.answer);
      }
    });
    // A held answer belongs to the conversation it was asked in. On another
    // - a new one above all, which never stores it - it stayed on screen
    // under nothing until the next question.
    // So do what a command said and the session put up for discussion.
    ref.listen<CoachSession>(coachSessionControllerProvider, (previous, next) {
      if (previous?.threadId != next.threadId &&
          (_held != null || _reply != null || _about != null)) {
        setState(() {
          _held = null;
          _reply = null;
          _about = null;
        });
      }
    });
    // Held only until the stored answer is in the list - which may already
    // be the case by the time the writing stops.
    final stored = messages.any(
      (m) => m.role == 'assistant' && m.createdAt >= _askedAt,
    );
    final held = stored ? null : _held;
    final writing = state.sending || held != null;

    // Counted from the newest: the answer being written, then the messages
    // back to the first.
    final count = messages.length + (writing ? 1 : 0);
    Widget item(int fromNewest) {
      if (writing && fromNewest == 0) {
        return _Writing(
          answer: state.sending ? state.answer : held!,
          looking: state.sending ? state.looking : null,
        );
      }
      final index = messages.length - 1 - fromNewest + (writing ? 1 : 0);
      return _Bubble(
        message: messages[index],
        question: _questionBefore(messages, index),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Gesprekken',
          icon: const Icon(Icons.menu),
          onPressed: () => showCoachDrawer(context),
        ),
        title: const Text('Coach'),
        actions: [
          if (planId != null)
            IconButton(
              tooltip: 'Schema',
              icon: const Icon(Icons.view_sidebar_outlined),
              onPressed: () => _openPanel(planId),
            ),
          IconButton(
            tooltip: 'Nieuw gesprek',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _session.startNew,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (ofWorkout) _WorkoutStrip(workout: running),
            if (planId != null)
              PlanStrip(planId: planId, onOpen: () => _openPanel(planId)),
            Expanded(
              child: messages.isEmpty && !writing
                  ? _Opening(onPick: _send)
                  // Reversed, so it starts at the newest line - also in a
                  // conversation from earlier - and shrink-wrapped at the
                  // top, so a short one still reads from the top down.
                  : Align(
                      alignment: Alignment.topCenter,
                      child: CustomScrollView(
                        key: ValueKey(threadId),
                        controller: _scroll,
                        reverse: true,
                        shrinkWrap: true,
                        slivers: [
                          _Newest(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              child: item(0),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              0,
                            ),
                            sliver: SliverList.builder(
                              itemCount: count - 1,
                              itemBuilder: (context, i) => item(i + 1),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (state.error != null)
              _Failure(
                message: state.error!,
                keyRejected: state.keyRejected,
                onClose: () =>
                    ref.read(coachControllerProvider.notifier).clearError(),
                // The question that got no answer, sent again: a refused key
                // needs another key first.
                onRetry:
                    threadId == null ||
                        state.keyRejected ||
                        messages.lastOrNull?.role != 'user'
                    ? null
                    : () => ref
                          .read(coachControllerProvider.notifier)
                          .retry(threadId),
              ),
            if (_reply case final reply?)
              _AppReply(
                reply: reply,
                onClose: () => setState(() => _reply = null),
              ),
            // While a / is typed, the commands that fit; otherwise your own
            // questions, a tap each, also in a conversation that is going:
            // the opening has them too.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (commandBeingTyped(value.text) case final typed?) {
                  return _Commands(
                    typed: typed,
                    inPlan: inPlan,
                    own: own,
                    onPick: (command, {required fill}) {
                      if (!fill) {
                        _send(command);
                        return;
                      }
                      _controller.value = TextEditingValue(
                        text: '$command ',
                        selection: TextSelection.collapsed(
                          offset: command.length + 1,
                        ),
                      );
                    },
                  );
                }
                if (messages.isNotEmpty && !state.sending) {
                  return _QuickQuestions(onPick: _send);
                }
                return const SizedBox.shrink();
              },
            ),
            if (_about case final about?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: InputChip(
                    avatar: const Icon(Icons.event_note_outlined, size: 18),
                    label: Text('Over: ${about.name}'),
                    deleteButtonTooltipMessage: 'Niet meer over deze sessie',
                    onDeleted: () => setState(() => _about = null),
                  ),
                ),
              ),
            if (_photos.isNotEmpty)
              _PickedPhotos(
                fileNames: _photos,
                onRemove: (name) => setState(() => _photos.remove(name)),
              ),
            _Ask(
              controller: _controller,
              busy: state.sending,
              onSend: _send,
              onStop: () => ref.read(coachControllerProvider.notifier).stop(),
              onPickPhoto: _photos.length < CoachController.photosPerQuestion
                  ? _pickPhoto
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// What the answer at [index] was to: the last thing the user said
  /// before it.
  static String? _questionBefore(List<ChatMessageRow> messages, int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].role == 'user') return messages[i].content;
    }
    return null;
  }
}

/// The newest line of the conversation, where the reversed list starts: at
/// the bottom.
///
/// What grows there, like the answer being written, pushes everything above
/// it up the screen. At the newest line that is right, because it stays in
/// sight. Close to it, the user is taken the last bit down. Further up,
/// reading something, the position moves along in the same layout, so the
/// text being read stays where it is.
class _Newest extends SingleChildRenderObjectWidget {
  const _Newest({required Widget super.child});

  /// How far up the user may have scrolled and still be following along.
  static const double following = 160;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNewest();
}

class _RenderNewest extends RenderSliverToBoxAdapter {
  /// How tall the newest line was the last time round.
  double? _height;

  @override
  void performLayout() {
    super.performLayout();
    final height = geometry!.scrollExtent;
    final before = _height;
    _height = height;
    // The first sliver, so its scroll offset is how far up the user is.
    final up = constraints.scrollOffset;
    if (before == null || height == before || up <= 0) return;
    geometry = SliverGeometry(
      scrollOffsetCorrection: up > _Newest.following ? height - before : -up,
    );
  }
}

/// Above the conversation of the running workout: which one, how long it has
/// been going, and that the island writes in it too.
class _WorkoutStrip extends StatefulWidget {
  const _WorkoutStrip({required this.workout});

  final WorkoutRow workout;

  @override
  State<_WorkoutStrip> createState() => _WorkoutStripState();
}

class _WorkoutStripState extends State<_WorkoutStrip> {
  late final Timer _minute = Timer.periodic(
    const Duration(seconds: 20),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _minute.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = DateTime.now()
        .difference(
          DateTime.fromMillisecondsSinceEpoch(widget.workout.startedAt),
        )
        .inMinutes;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Two lines rather than one: on a narrow phone with large text
          // the second half cut the first off at "lo…".
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.workout.name} · loopt $minutes min',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Hetzelfde gesprek als in het eiland', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An empty conversation: what the coach is, and questions about you,
/// today, to start one with.
class _Opening extends ConsumerStatefulWidget {
  const _Opening({required this.onPick});

  final void Function(String question) onPick;

  @override
  ConsumerState<_Opening> createState() => _OpeningState();
}

class _OpeningState extends ConsumerState<_Opening> {
  /// Which four are showing: Andere vragen moves on to the next.
  var _page = 0;

  static IconData _icon(SuggestionReason reason) => switch (reason) {
    SuggestionReason.workout => Icons.fitness_center,
    SuggestionReason.deload => Icons.battery_charging_full,
    SuggestionReason.today => Icons.event_outlined,
    SuggestionReason.recovery => Icons.schedule,
    SuggestionReason.stalled => Icons.trending_flat,
    SuggestionReason.record => Icons.emoji_events_outlined,
    SuggestionReason.comeback => Icons.replay,
    SuggestionReason.sleep => Icons.bedtime_outlined,
    SuggestionReason.start => Icons.flag_outlined,
    SuggestionReason.app => Icons.help_outline,
    SuggestionReason.general => Icons.lightbulb_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Nieuw gesprek on an empty one: questions as of now, from the first.
    ref.listen(coachSessionControllerProvider, (_, _) {
      ref.invalidate(coachSuggestionsProvider);
      setState(() => _page = 0);
    });
    // Something to start with, also when reading the logbook failed.
    final all = ref
        .watch(coachSuggestionsProvider)
        .when(
          data: (found) => found,
          loading: () => const <CoachSuggestion>[],
          error: (_, _) => suggestQuestions(const SuggestionFacts()),
        );
    final pages = (all.length / kSuggestionsShown).ceil();
    final page = pages == 0 ? 0 : _page % pages;
    final shown = all.skip(page * kSuggestionsShown).take(kSuggestionsShown);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Icon(
          Icons.smart_toy_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Vraag je coach', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        // Short, so the questions below are in sight on a small phone.
        Text(
          'Over trainen, herstel en de app. Onder elk antwoord staat wat hij '
          'in je logboek opzocht.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (ref.watch(quickQuestionsProvider).value ?? const [] case final own
            when own.isNotEmpty) ...[
          Text(
            'Jouw vragen',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final question in own)
                ActionChip(
                  label: Text(question.question),
                  onPressed: () => widget.onPick(question.question),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (all.isNotEmpty) ...[
          Text(
            'Voor jou, nu',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final suggestion in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => widget.onPick(suggestion.question),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.question,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_icon(suggestion.reason), size: 14, color: muted),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          suggestion.why,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (pages > 1)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _page = page + 1),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Andere vragen'),
            ),
          ),
      ],
    );
  }
}

/// One message. Yours on the right, the coach's on the left with its receipts.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.question});

  final ChatMessageRow message;

  /// For an answer: the question it answered, for a report about it.
  final String? question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.role == 'user';
    final lookups = message.lookups?.split('\n') ?? const <String>[];
    final photos = message.photos;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final name in photos)
                      _SentPhoto(
                        fileName: name,
                        width: photos.length == 1 ? 180 : 112,
                      ),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: mine
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: SelectableText(
                message.content,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            for (final (index, proposal) in parseProposals(
              message.proposals,
            ).indexed)
              if (proposal.note case final note?)
                _NoteCard(note: note)
              else if (proposal.kind == ProposalKind.plan)
                PlanProposalCard(proposal: proposal)
              else if (proposal.outline case final outline?)
                PlanOutlineCard(
                  message: message,
                  outline: outline,
                  proposal: proposal,
                )
              else if (proposal.session case final session?)
                PlanSessionCard(
                  message: message,
                  session: session,
                  proposal: proposal,
                )
              else if (proposal.kind == ProposalKind.planChange)
                PlanChangeCard(
                  message: message,
                  index: index,
                  proposal: proposal,
                )
              else
                _ProposalCard(
                  message: message,
                  index: index,
                  proposal: proposal,
                ),
            if (lookups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _Lookups(lookups: lookups),
              ),
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    if (message.outputTokens != null)
                      Text(
                        '${message.inputTokens ?? 0} in · '
                        '${message.outputTokens} uit',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Tooltip(
                      message: 'Meld dit antwoord',
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          textStyle: theme.textTheme.labelSmall,
                        ),
                        onPressed: () => showReportAnswer(
                          context,
                          answer: message.content,
                          answeredAt: DateTime.fromMillisecondsSinceEpoch(
                            message.createdAt,
                          ),
                          question: question,
                        ),
                        icon: const Icon(Icons.outlined_flag, size: 16),
                        label: const Text('Melden'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Something the coach offers to add, and the button that adds it.
///
/// The coach cannot write in your logbook. It describes, you decide: until
/// this button is tapped nothing exists, and afterwards the card says what was
/// made and takes you to it. A deload has a second button beside it, for the
/// start sheet with the coach's numbers in it. A note in the coach's memory
/// has a card of its own, [_NoteCard].
class _ProposalCard extends ConsumerStatefulWidget {
  const _ProposalCard({
    required this.message,
    required this.index,
    required this.proposal,
  });

  final ChatMessageRow message;
  final int index;
  final CoachProposal proposal;

  @override
  ConsumerState<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends ConsumerState<_ProposalCard> {
  bool _busy = false;

  /// [withPhotos]: added from "Toevoegen met foto's", after which the
  /// coach's two prompts are shown, with the way to Gemini.
  Future<void> _accept({
    bool withImages = false,
    bool withPhotos = false,
  }) async {
    // What gets drawn is worth reading before it is paid for. The coach picks
    // the exercise name too, and a name like "Overhead Extension - V-Bar
    // Attachment" drags the word bar into the picture, where the model turns
    // it into someone hanging from a pull-up bar. Whoever knows the exercise
    // can take that word out in one tap; the app cannot guess it.
    String? start;
    String? end;
    if (withImages) {
      final exercise = widget.proposal.exercise!;
      final pair = await promptForPair(
        context,
        title: 'Wat moeten de tekeningen tonen?',
        note:
            'In het Engels. Noem geen stang of handvat boven het hoofd - daar '
            'maakt de tekenaar een optrekbeweging van.',
        start: exercise.startImagePrompt ?? '',
        end: exercise.endImagePrompt ?? '',
        maxLength: ImageGenerator.maxPromptLength,
        // The coach wrote these along the way, while it was also inventing an
        // exercise. Asked again with nothing but this job in front of it, it
        // does better - and one small question is far cheaper than a drawing.
        writeLabel: 'Laat de coach het opnieuw schrijven',
        onWrite: () async {
          try {
            return await ref
                .read(coachControllerProvider.notifier)
                .writeFramePrompts(
                  messageId: widget.message.id,
                  name: exercise.name,
                  equipment: exercise.equipment,
                  instructions: exercise.instructions,
                );
          } on CoachException catch (error) {
            throw CoachDialogError(error.message);
          }
        },
      );
      if (pair == null || !mounted) return;
      (start, end) = pair;
    }

    setState(() => _busy = true);
    try {
      final id = await ref
          .read(coachControllerProvider.notifier)
          .accept(
            message: widget.message,
            index: widget.index,
            withImages: withImages,
            startPrompt: start,
            endPrompt: end,
          );
      if (!mounted) return;
      if (id == null) return;

      if (withPhotos) {
        _showPrompts();
        return;
      }
      showSnack(context, switch (widget.proposal.kind) {
        ProposalKind.exercise =>
          withImages
              ? 'Oefening toegevoegd, met tekeningen.'
              : 'Oefening toegevoegd.',
        ProposalKind.exerciseChange => 'Oefening aangepast.',
        ProposalKind.routine ||
        ProposalKind.coachRoutine => 'Routine toegevoegd.',
        ProposalKind.note => 'Onthouden.',
        ProposalKind.plan => 'Schema opgeslagen.',
        ProposalKind.planChange => 'Schema aangepast.',
        ProposalKind.planOutline || ProposalKind.planSession => 'Opgeslagen.',
        ProposalKind.deload => deloadStartedText(
          widget.proposal.deload!.startAt(DateTime.now()),
          widget.proposal.deload!.days,
          DateTime.now(),
        ),
      });
    } on CoachException catch (error) {
      // The exercise itself may well have been made; only the drawing failed.
      if (mounted) showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPrompts() {
    final exercise = widget.proposal.exercise!;
    showPhotoPrompts(
      context,
      exercise: exercise.name,
      start: exercise.startImagePrompt!,
      end: exercise.endImagePrompt!,
    );
  }

  /// Aanpassen: the start sheet, opened on what the coach proposed. What
  /// is started there is what the card keeps.
  Future<void> _adjust() async {
    final deload = widget.proposal.deload!;
    final id = await showDeloadStartSheet(
      context,
      source: 'coach',
      plan: deload.plan,
      days: deload.days,
      from: deload.startAt(DateTime.now()),
    );
    if (id == null || !mounted) return;
    await ref
        .read(coachControllerProvider.notifier)
        .noteDeloadStarted(
          message: widget.message,
          index: widget.index,
          id: id,
        );
  }

  /// Where Bekijken goes: to what was made. A deload has no page of its
  /// own; the banner on Start and Trainen shows it.
  String? _place(String id) => switch (widget.proposal.kind) {
    ProposalKind.exercise ||
    ProposalKind.exerciseChange => Routes.exerciseDetail(id),
    ProposalKind.routine ||
    ProposalKind.coachRoutine => Routes.routineDetail(id),
    ProposalKind.deload ||
    ProposalKind.note ||
    ProposalKind.plan ||
    ProposalKind.planChange ||
    ProposalKind.planOutline ||
    ProposalKind.planSession => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proposal = widget.proposal;
    final exercise = proposal.exercise;
    final routine = proposal.routine;
    final change = proposal.exerciseChange;
    final deload = proposal.deload;
    final action = switch (proposal.kind) {
      ProposalKind.exercise => 'Oefening toevoegen',
      ProposalKind.exerciseChange => 'Toepassen',
      ProposalKind.routine || ProposalKind.coachRoutine => 'Routine toevoegen',
      ProposalKind.deload => 'Starten',
      ProposalKind.note => 'Onthouden',
      ProposalKind.plan => 'Start schema',
      ProposalKind.planChange => 'Aanvaarden',
      ProposalKind.planOutline || ProposalKind.planSession => 'Goedkeuren',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  switch (proposal.kind) {
                    ProposalKind.exercise => Icons.fitness_center,
                    ProposalKind.routine => Icons.list_alt,
                    ProposalKind.coachRoutine => Icons.smart_toy_outlined,
                    ProposalKind.exerciseChange => Icons.edit_outlined,
                    ProposalKind.deload => Icons.battery_charging_full,
                    ProposalKind.note => Icons.sticky_note_2_outlined,
                    ProposalKind.plan ||
                    ProposalKind.planChange ||
                    ProposalKind.planOutline ||
                    ProposalKind.planSession => Icons.calendar_month_outlined,
                  },
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    switch (proposal.kind) {
                      ProposalKind.exercise => 'Voorstel: oefening',
                      ProposalKind.routine => 'Voorstel: routine',
                      ProposalKind.coachRoutine =>
                        proposal.made
                            ? 'Gemaakt door de coach'
                            : 'Aangepast door de coach',
                      ProposalKind.exerciseChange =>
                        'Voorstel: oefening aanpassen',
                      ProposalKind.deload => 'Voorstel: deload',
                      ProposalKind.note => 'Onthouden',
                      ProposalKind.plan => 'Schema',
                      ProposalKind.planChange => 'Voorstel: schema',
                      ProposalKind.planOutline => 'Opzet van je schema',
                      ProposalKind.planSession => 'Sessie van je schema',
                    },
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(proposal.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            if (proposal.change ?? change?.reason ?? deload?.reason
                case final why?) ...[
              Text(why, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (change != null) _ChangeLines(change: change),
            if (deload != null)
              _DeloadLines(deload: deload, started: proposal.isApplied),
            if (exercise != null && exercise.hasPhotos)
              _ProposalPhotos(
                start: exercise.startPhoto,
                end: exercise.endPhoto,
              ),
            if (change != null &&
                (change.startPhoto != null || change.endPhoto != null))
              _ProposalPhotos(start: change.startPhoto, end: change.endPhoto),
            if (exercise != null)
              Text(
                [
                  exercise.primaryMuscle,
                  ...exercise.secondaryMuscles,
                  ?exercise.equipment,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (routine != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in routine.exercises)
                    Text(
                      '${item.sets}× ${item.name}'
                      '${item.targetReps == null ? '' : ' · ${Formatters.amount(item.targetReps!, 'herhaling', 'herhalingen')}'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${Formatters.amount(routine.exercises.length, 'oefening', 'oefeningen')} · '
                    '${Formatters.amount(routine.totalSets, 'set', 'sets')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            if (proposal.appliedId case final id?) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(switch (proposal.kind) {
                      ProposalKind.coachRoutine => 'In de map Coach',
                      ProposalKind.exerciseChange => 'Toegepast',
                      ProposalKind.exercise ||
                      ProposalKind.routine => 'Toegevoegd',
                      ProposalKind.deload => 'Ingepland',
                      ProposalKind.note => 'Onthouden',
                      ProposalKind.plan => 'Opgeslagen',
                      ProposalKind.planChange => 'Aangepast',
                      ProposalKind.planOutline ||
                      ProposalKind.planSession => 'Opgeslagen',
                    }, style: theme.textTheme.bodySmall),
                  ),
                  if (_place(id) case final place?)
                    TextButton(
                      onPressed: () => context.push(place),
                      child: const Text('Bekijken'),
                    ),
                ],
              ),
              // The prompts stay where the coach wrote them, for whoever
              // makes the photos later - or the second one after the first.
              if (exercise != null &&
                  exercise.hasFramePrompts &&
                  !exercise.hasPhotos)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _showPrompts,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text("Prompts voor de foto's"),
                  ),
                ),
            ] else if (deload != null) ...[
              // Two halves, as high as each other, also with large text on
              // a narrow phone.
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                      onPressed: _busy ? null : () => _accept(),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(action),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                      onPressed: _busy ? null : _adjust,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Aanpassen'),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _accept(),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(change != null ? Icons.check : Icons.add),
                  label: Text(action),
                ),
              ),
              // The photos are made in Gemini, from the coach's two prompts;
              // this adds the exercise and shows them. Not when the photos
              // are already here, sent along by the user.
              if (exercise != null &&
                  exercise.hasFramePrompts &&
                  !exercise.hasPhotos) ...[
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _accept(withPhotos: true),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text("Toevoegen met foto's"),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Je krijgt twee prompts voor Gemini; de foto's maak je daar "
                  'zelf.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // A second button rather than a switch: two drawings cost
              // credit, and the difference between the buttons is what you
              // are agreeing to. Only while drawing is on (DECISIONS 201).
              if (exercise != null &&
                  exercise.hasFramePrompts &&
                  ref.watch(canDrawImagesProvider)) ...[
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _accept(withImages: true),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Toevoegen mét tekeningen'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Twee tekeningen, begin- en eindpositie. Kost tegoed bij '
                  'Hugging Face.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A note the coach wrote in its memory, changed or wiped - as it is in the
/// notebook now: Aanpassen and Vergeten while it is there, struck through
/// once it is not. The first one says what the memory is.
class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});

  final NoteProposal note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final notes = ref.watch(coachNotesProvider).value;
    final kept = notes?.where((n) => n.id == note.id).firstOrNull;
    final gone =
        note.action == NoteAction.forgotten || (notes != null && kept == null);
    final dao = ref.read(databaseProvider).coachNotesDao;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  coachNoteIcon(kept?.kind ?? note.kind),
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    switch (note.action) {
                      NoteAction.made => 'Onthouden',
                      NoteAction.changed => 'Aangepast in het geheugen',
                      NoteAction.forgotten => 'Vergeten',
                    },
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              kept?.note ?? note.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: gone ? TextDecoration.lineThrough : null,
                color: gone ? muted : null,
              ),
            ),
            if (note.first) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'De coach onthoudt korte notities over je en stuurt ze mee '
                'met elke vraag. Je ziet en beheert ze bij Instellingen → '
                'AI-coach → Geheugen.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if (!gone && kept != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final text = await askForNote(context, note: kept.note);
                      if (text == null || text.trim().isEmpty) return;
                      await dao.change(kept.id, text);
                    },
                    child: const Text('Aanpassen'),
                  ),
                  OutlinedButton(
                    onPressed: () => dao.forget(kept.id),
                    child: const Text('Vergeten'),
                  ),
                ],
              ),
            ] else if (note.action != NoteAction.forgotten &&
                notes != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Niet meer in het geheugen.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// When a proposed deload runs and how light it is - once started, as it
/// was started - and until then the deload it would take the place of.
class _DeloadLines extends ConsumerWidget {
  const _DeloadLines({required this.deload, required this.started});

  final DeloadProposal deload;
  final bool started;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final from = started ? deload.from : deload.startAt(DateTime.now());
    final last = DateTime(from.year, from.month, from.day + deload.days - 1);
    final replaced = started ? null : ref.watch(currentDeloadProvider).value;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Formatters.weekdayDayMonthShort(from)} tot en met '
            '${Formatters.weekdayDayMonthShort(last)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            [
              deloadPlanSummary(deload.plan),
              if (deload.plan.prAttempts) 'recordpogingen mogen',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (replaced != null)
            Text(
              'In de plaats van je deload vanaf '
              '${Formatters.weekdayDayMonthShort(replaced.from)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// What a proposed change does to the exercise, a line per field.
class _ChangeLines extends StatelessWidget {
  const _ChangeLines({required this.change});

  final ExerciseChangeProposal change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muscles = [?change.primaryMuscle, ...?change.secondaryMuscles];
    final lines = [
      if (change.name case final name?) 'Naam: $name',
      if (muscles.isNotEmpty) 'Spiergroepen: ${muscles.join(' · ')}',
      if (change.equipment case final equipment?) 'Materiaal: $equipment',
      if (change.instructions case final instructions?) 'Uitleg: $instructions',
      if (change.startPhoto != null && change.endPhoto != null)
        "Foto's: start en eind"
      else if (change.startPhoto != null)
        'Foto: start'
      else if (change.endPhoto != null)
        'Foto: eind',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(
              line,
              style: theme.textTheme.bodySmall,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// The photos a card would put on the exercise, start and end, with which is
/// which under each: the user checks that before tapping.
class _ProposalPhotos extends ConsumerWidget {
  const _ProposalPhotos({this.start, this.end});

  final String? start;
  final String? end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider).value;
    if (paths == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    Widget frame(String fileName, String label) => Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: photoImage(
            PhotoStore(paths).fileFor(fileName),
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.square(
              dimension: 88,
              child: MissingPhotoPlaceholder(compact: true),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          if (start case final name?) frame(name, 'Start'),
          if (end case final name?) frame(name, 'Eind'),
        ],
      ),
    );
  }
}

/// What left the device to answer this, in the user's own words.
class _Lookups extends StatelessWidget {
  const _Lookups({required this.lookups});

  final List<String> lookups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.search, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Bekeken: ${lookups.join(', ')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The photos that are about to be sent, above the field, each with a way
/// to take it back.
class _PickedPhotos extends ConsumerWidget {
  const _PickedPhotos({required this.fileNames, required this.onRemove});

  final List<String> fileNames;
  final void Function(String fileName) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider).value;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileNames.length == 1
                ? 'Deze foto gaat mee met je vraag.'
                : "Deze ${fileNames.length} foto's gaan mee met je vraag.",
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (index, name) in fileNames.indexed)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Room above and beside the photo for its button: it hung
                    // out of the frame, and only about 30 by 30 of it could
                    // be hit (DECISIONS 292).
                    if (paths != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14, right: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                          child: photoImage(
                            PhotoStore(paths).fileFor(name),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton.filledTonal(
                        tooltip: 'Foto ${index + 1} toch niet',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: () => onRemove(name),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A photo inside a message, tappable to see it whole.
class _SentPhoto extends ConsumerWidget {
  const _SentPhoto({required this.fileName, this.width = 180});

  final String fileName;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider).value;
    if (paths == null) return const SizedBox.shrink();

    final file = PhotoStore(paths).fileFor(fileName);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.md),
            child: InteractiveViewer(child: photoImage(file)),
          ),
        ),
        child: photoImage(
          file,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              const MissingPhotoPlaceholder(),
        ),
      ),
    );
  }
}

/// The answer while it is being written: what the coach is looking up
/// first, then the text as it comes in.
class _Writing extends StatelessWidget {
  const _Writing({required this.answer, this.looking});

  final String answer;
  final String? looking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A leading line break is how a piece often starts; the stored answer is
    // trimmed, and this should not jump when it replaces it.
    final text = answer.trimLeft();

    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                looking == null ? 'De coach denkt na…' : 'Bekijkt $looking…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: _Typing(text: text, style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}

/// Text that types itself out.
///
/// The service sends a few words to a sentence at a time; shown as they come
/// that is a jerk every half second. This lets the letters catch up with
/// what has arrived instead: one a frame while little is waiting, faster
/// when a big piece came in, so it never falls far behind. With reduced
/// motion switched on, everything that arrived is there at once.
class _Typing extends StatefulWidget {
  const _Typing({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  var _shown = 0;

  /// How many frames a backlog is allowed to take to show.
  static const int _catchUpFrames = 8;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keepUp();
  }

  @override
  void didUpdateWidget(_Typing old) {
    super.didUpdateWidget(old);
    if (_shown > widget.text.length) _shown = widget.text.length;
    _keepUp();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _keepUp() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _shown = widget.text.length;
      return;
    }
    if (_shown < widget.text.length && !_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    final behind = widget.text.length - _shown;
    if (behind <= 0) {
      _ticker.stop();
      return;
    }
    var next = _shown + (behind / _catchUpFrames).ceil();
    // Never half of a character made of two code units, like an emoji.
    if (next < widget.text.length &&
        _isHighSurrogate(widget.text.codeUnitAt(next - 1))) {
      next++;
    }
    setState(() => _shown = next);
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  @override
  Widget build(BuildContext context) =>
      Text(widget.text.substring(0, _shown), style: widget.style);
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.message,
    required this.keyRejected,
    required this.onClose,
    required this.onRetry,
  });

  final String message;
  final bool keyRejected;
  final VoidCallback onClose;

  /// Sends the question without an answer again; null when there is none.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            children: [
              if (onRetry case final retry?)
                TextButton(onPressed: retry, child: const Text('Opnieuw')),
              TextButton(onPressed: onClose, child: const Text('Sluiten')),
              // A refused key has one way on: another one, pasted.
              if (keyRejected)
                TextButton(
                  onPressed: () => context.push(Routes.coachKeyPaste),
                  child: const Text('Sleutel opnieuw plakken'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ask extends StatelessWidget {
  const _Ask({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.onPickPhoto,
  });

  final TextEditingController controller;
  final bool busy;
  final void Function(String question) onSend;

  /// While an answer is being written, the button stops it.
  final VoidCallback onStop;

  /// Null once there are as many photos as go with one question.
  final VoidCallback? onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Foto erbij',
            onPressed: busy ? null : onPickPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Stel je vraag',
                border: OutlineInputBorder(),
              ),
              onSubmitted: busy ? null : onSend,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Part of the field: sending keeps the keyboard up for the next
          // question, the way a chat does.
          TextFieldTapRegion(
            child: busy
                ? IconButton.filledTonal(
                    tooltip: 'Stoppen',
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                  )
                : IconButton.filled(
                    tooltip: 'Versturen',
                    onPressed: () => onSend(controller.text),
                    icon: const Icon(Icons.arrow_upward),
                  ),
          ),
        ],
      ),
    );
  }
}

/// What you get instead of the coach when there is no key.
class CoachDisabledScreen extends StatelessWidget {
  const CoachDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          icon: Icons.smart_toy_outlined,
          title: 'De coach staat uit',
          message:
              'De coach praat met Gemini van Google, met een gratis sleutel '
              'van jezelf. Zonder sleutel maakt FitLog geen enkele '
              'verbinding.',
          actionLabel: 'Coach aanzetten',
          onAction: () => context.push(Routes.coachKey),
        ),
      ),
    );
  }
}

/// What a command said back: from the app, not from the coach, and not
/// kept. It goes with the next question, another conversation, or ✕.
class _Reply {
  const _Reply({this.text, this.note});

  final String? text;

  /// A note /onthoud put in the notebook, shown as the coach's are.
  final NoteProposal? note;
}

class _AppReply extends StatelessWidget {
  const _AppReply({required this.reply, required this.onClose});

  final _Reply reply;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VAN DE APP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (reply.text case final text?)
                  Text(text, style: theme.textTheme.bodyMedium),
                if (reply.note case final note?) _NoteCard(note: note),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sluiten',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// The commands that fit what is typed after the /, over the field. A tap
/// runs one, or puts it in the field when something goes after it.
class _Commands extends StatelessWidget {
  const _Commands({
    required this.typed,
    required this.inPlan,
    required this.own,
    required this.onPick,
  });

  /// The name so far, without the /.
  final String typed;
  final bool inPlan;

  /// Your quick questions that have a name.
  final List<QuickQuestionRow> own;
  final void Function(String command, {required bool fill}) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = [
      for (final command in CoachCommand.values)
        if ((!command.onlyInPlan || inPlan) && command.name.startsWith(typed))
          command,
    ];
    final mine = [
      for (final row in own)
        if (row.command!.startsWith(typed)) row,
    ];
    if (app.isEmpty && mine.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.3,
      ),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        children: [
          for (final command in app)
            _CommandRow(
              typed: command.typed,
              argument: command.argument,
              about: command.about,
              asks: command.asks,
              onTap: () =>
                  onPick(command.typed, fill: command.argument != null),
            ),
          for (final row in mine)
            _CommandRow(
              typed: '/${row.command}',
              about: 'Jouw vraag: ${row.question}',
              asks: true,
              onTap: () => onPick('/${row.command}', fill: false),
            ),
        ],
      ),
    );
  }
}

/// One command: its name, what it does, and whether it costs a question.
class _CommandRow extends StatelessWidget {
  const _CommandRow({
    required this.typed,
    required this.about,
    required this.asks,
    required this.onTap,
    this.argument,
  });

  final String typed;
  final String? argument;
  final String about;
  final bool asks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: typed,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        if (argument != null)
                          TextSpan(
                            text: ' $argument',
                            style: TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    about,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Text(
                asks ? '1 vraag' : 'gratis',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: asks ? muted : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's own questions (Geplande prompts → Eigen snelle vragen), in a
/// row over the field: one tap asks one.
class _QuickQuestions extends ConsumerWidget {
  const _QuickQuestions({required this.onPick});

  final void Function(String question) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = ref.watch(quickQuestionsProvider).value ?? const [];
    if (own.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final question in own)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ActionChip(
                label: Text(
                  question.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => onPick(question.question),
              ),
            ),
        ],
      ),
    );
  }
}
