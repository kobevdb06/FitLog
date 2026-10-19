/// The conversation with the coach.
///
/// It only exists once the user has entered an API key of their own. Every
/// answer says underneath it what the coach looked up in the database and
/// what the question cost, because both are the user's: their data and their
/// money.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
import '../../photos/data/photo_store.dart';
import '../../workout/presentation/workout_providers.dart';
import '../data/ai_client.dart';
import '../domain/coach_proposal.dart';
import '../../../routing/routes.dart';
import 'chat_providers.dart';
import 'coach_drawer.dart';
import 'coach_session.dart';
import 'photo_prompts_sheet.dart';
import 'report_answer_sheet.dart';

/// What a new conversation offers when there is nothing to show yet.
const List<String> kCoachOpeners = [
  'Hoe ga ik verder met mijn bankdrukken?',
  'Doe ik genoeg voor mijn rug deze week?',
  'Geef me een oefening voor mijn schouders thuis.',
  'Hoe log ik een dropset in deze app?',
];

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

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

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty) return;

    final controller = ref.read(coachControllerProvider.notifier);
    final thread = await _session.threadFor(question);
    if (!mounted) return;

    final photos = List.of(_photos);
    _controller.clear();
    setState(() {
      _photos.clear();
      _held = null;
      _askedAt = DateTime.now().millisecondsSinceEpoch;
    });
    await controller.ask(
      threadId: thread,
      question: question,
      imageFiles: photos,
    );
    _toBottom();
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
    for (final file in picked.take(room)) {
      if (await coach.importPhoto(File(file.path)) case final name?) {
        stored.add(name);
      }
    }
    if (mounted) setState(() => _photos.addAll(stored));
  }

  /// Keeps the newest line in sight while the answer grows - unless the user
  /// scrolled up to read something, which this does not take away from them.
  void _follow() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 160) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
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
    ref.listen<CoachState>(coachControllerProvider, (previous, next) {
      if (previous == null) return;
      if (previous.sending &&
          !next.sending &&
          next.error == null &&
          previous.answer.isNotEmpty) {
        setState(() => _held = previous.answer);
      }
      if (next.answer != previous.answer) _follow();
    });
    // Held only until the stored answer is in the list - which may already
    // be the case by the time the writing stops.
    final stored = messages.any(
      (m) => m.role == 'assistant' && m.createdAt >= _askedAt,
    );
    final held = stored ? null : _held;
    final writing = state.sending || held != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Gesprekken',
          icon: const Icon(Icons.menu),
          onPressed: () => showCoachDrawer(context),
        ),
        title: const Text('Coach'),
        actions: [
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
            Expanded(
              child: messages.isEmpty && !writing
                  ? _Opening(onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: messages.length + (writing ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return _Writing(
                            answer: state.sending ? state.answer : held!,
                            looking: state.sending ? state.looking : null,
                            onGrow: _follow,
                          );
                        }
                        return _Bubble(
                          message: messages[index],
                          question: _questionBefore(messages, index),
                        );
                      },
                    ),
            ),
            if (state.error != null)
              _Failure(
                message: state.error!,
                keyRejected: state.keyRejected,
                onRetry: () =>
                    ref.read(coachControllerProvider.notifier).clearError(),
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
          Expanded(
            child: Text(
              '${widget.workout.name} · loopt $minutes min',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('ook in het eiland', style: muted),
        ],
      ),
    );
  }
}

/// An empty conversation: what the coach is, and four ways to start one.
class _Opening extends StatelessWidget {
  const _Opening({required this.onPick});

  final void Function(String question) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        Text(
          'Over trainen, oefeningen, herstel en over deze app. De coach kent '
          'de oefeningencatalogus en mag je logboek raadplegen; onder elk '
          'antwoord staat wat het heeft opgezocht.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final opener in kCoachOpeners)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () => onPick(opener),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(opener, textAlign: TextAlign.left),
              ),
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
              _ProposalCard(message: message, index: index, proposal: proposal),
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
/// start sheet with the coach's numbers in it.
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
    ProposalKind.deload => null,
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
          child: Image.file(
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
                    if (paths != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                        child: Image.file(
                          PhotoStore(paths).fileFor(name),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Positioned(
                      top: -10,
                      right: -10,
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
            child: InteractiveViewer(child: Image.file(file)),
          ),
        ),
        child: Image.file(
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
  const _Writing({required this.answer, this.looking, required this.onGrow});

  final String answer;
  final String? looking;
  final VoidCallback onGrow;

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
          child: _Typing(
            text: text,
            style: theme.textTheme.bodyMedium,
            onGrow: onGrow,
          ),
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
  const _Typing({required this.text, this.style, required this.onGrow});

  final String text;
  final TextStyle? style;

  /// Called each time more is shown, so the list can keep it in sight.
  final VoidCallback onGrow;

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
    widget.onGrow();
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
    required this.onRetry,
  });

  final String message;
  final bool keyRejected;
  final VoidCallback onRetry;

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
              TextButton(onPressed: onRetry, child: const Text('Sluiten')),
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
    required this.onPickPhoto,
  });

  final TextEditingController controller;
  final bool busy;
  final void Function(String question) onSend;

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
            child: IconButton.filled(
              tooltip: 'Versturen',
              onPressed: busy ? null : () => onSend(controller.text),
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
