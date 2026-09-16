/// The conversation with the coach.
///
/// It only exists once the user has entered an API key of their own. Every
/// answer says underneath it what the coach looked up in the database and
/// what the question cost, because both are the user's: their data and their
/// money.
library;

import 'dart:io';

import 'package:flutter/material.dart';
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
import '../../photos/data/photo_store.dart';
import '../domain/coach_proposal.dart';
import '../../../routing/routes.dart';
import 'chat_providers.dart';

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

  /// The conversation being shown, or null until the first question makes one.
  String? _threadId;
  var _loaded = false;

  /// A photo picked but not sent yet, as a file name in the photo directory.
  String? _photo;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the conversation you were last in, so the tab picks up where you
  /// left it rather than starting blank every time.
  Future<void> _openNewest() async {
    if (_loaded) return;
    _loaded = true;
    final newest = await ref.read(databaseProvider).chatDao.newestThread();
    if (mounted && newest != null) setState(() => _threadId = newest.id);
  }

  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty) return;

    final controller = ref.read(coachControllerProvider.notifier);
    var thread = _threadId;
    if (thread == null) {
      thread = await controller.startThread(question);
      if (!mounted) return;
      setState(() => _threadId = thread);
    }

    final photo = _photo;
    _controller.clear();
    setState(() => _photo = null);
    await controller.ask(
      threadId: thread,
      question: question,
      imageFile: photo,
    );
    _toBottom();
  }

  /// Picks a photo to ask about. It is stored straight away and shown above
  /// the field, so what is about to be sent is visible before it goes.
  Future<void> _pickPhoto() async {
    final source = await showAppSheet<ImageSource>(
      context: context,
      title: 'Welke foto?',
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

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
    );
    if (picked == null || !mounted) return;

    final stored = await ref
        .read(coachControllerProvider.notifier)
        .importPhoto(File(picked.path));
    if (mounted) setState(() => _photo = stored);
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

  /// [threads] comes from build, which is where the list is watched.
  ///
  /// Reading it here instead was the bug: nothing was subscribed to that
  /// stream, so the read answered "still loading" - an empty list - and the
  /// sheet offered a new conversation and nothing else.
  Future<void> _pickThread(List<ChatThreadRow> threads) async {
    final picked = await showAppSheet<String>(
      context: context,
      title: 'Gesprekken',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Nieuw gesprek'),
            onTap: () => Navigator.of(context).pop('nieuw'),
          ),
          const Divider(height: 1),
          if (threads.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Nog geen eerdere gesprekken.'),
            ),
          for (final thread in threads)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(thread.title, maxLines: 2),
              subtitle: Text(
                Formatters.relativeDay(
                  DateTime.fromMillisecondsSinceEpoch(thread.updatedAt),
                ),
              ),
              selected: thread.id == _threadId,
              onTap: () => Navigator.of(context).pop(thread.id),
            ),
        ],
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _threadId = picked == 'nieuw' ? null : picked);
  }

  Future<void> _deleteThread() async {
    final thread = _threadId;
    if (thread == null) return;

    final ok = await confirm(
      context,
      title: 'Gesprek verwijderen?',
      message: 'De vragen en antwoorden in dit gesprek verdwijnen.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok || !mounted) return;

    await ref.read(databaseProvider).chatDao.deleteThread(thread);
    if (mounted) setState(() => _threadId = null);
  }

  @override
  Widget build(BuildContext context) {
    unawaitedOpen();

    final state = ref.watch(coachControllerProvider);
    final threads = ref.watch(chatThreadsProvider).value ?? const [];
    final messages = _threadId == null
        ? const <ChatMessageRow>[]
        : ref.watch(chatMessagesProvider(_threadId!)).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach'),
        actions: [
          IconButton(
            tooltip: 'Gesprekken',
            icon: const Icon(Icons.history),
            onPressed: () => _pickThread(threads),
          ),
          if (_threadId != null)
            IconButton(
              tooltip: 'Dit gesprek verwijderen',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteThread,
            ),
          IconButton(
            tooltip: 'Instellingen',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.settingsCoach),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty && !state.sending
                  ? _Opening(onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: messages.length + (state.sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) return const _Thinking();
                        return _Bubble(message: messages[index]);
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
            if (_photo != null)
              _PickedPhoto(
                fileName: _photo!,
                onRemove: () => setState(() => _photo = null),
              ),
            _Ask(
              controller: _controller,
              busy: state.sending,
              onSend: _send,
              onPickPhoto: _pickPhoto,
            ),
          ],
        ),
      ),
    );
  }

  /// Kicked off from build, once: the newest thread is a database read and
  /// the screen should already be on screen while it happens.
  void unawaitedOpen() {
    if (!_loaded) _openNewest();
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
  const _Bubble({required this.message});

  final ChatMessageRow message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.role == 'user';
    final lookups = message.lookups?.split('\n') ?? const <String>[];

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
            if (message.imageFile != null)
              _SentPhoto(fileName: message.imageFile!),
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
            if (!mine && message.outputTokens != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  '${message.inputTokens ?? 0} in · '
                  '${message.outputTokens} uit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
/// made and takes you to it.
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

  Future<void> _accept() async {
    setState(() => _busy = true);
    final id = await ref
        .read(coachControllerProvider.notifier)
        .accept(message: widget.message, index: widget.index);
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) return;

    showSnack(
      context,
      widget.proposal.kind == ProposalKind.exercise
          ? 'Oefening toegevoegd.'
          : 'Routine toegevoegd.',
    );
  }

  void _open(String id) => switch (widget.proposal.kind) {
    ProposalKind.exercise => context.push(Routes.exerciseDetail(id)),
    ProposalKind.routine => context.push(Routes.routineDetail(id)),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proposal = widget.proposal;
    final exercise = proposal.exercise;
    final routine = proposal.routine;

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
                  proposal.kind == ProposalKind.exercise
                      ? Icons.fitness_center
                      : Icons.list_alt,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    proposal.kind == ProposalKind.exercise
                        ? 'Voorstel: oefening'
                        : 'Voorstel: routine',
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
                      '${item.targetReps == null ? '' : ' · ${item.targetReps} herhalingen'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${routine.exercises.length} oefeningen · '
                    '${routine.totalSets} sets',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            if (proposal.appliedId case final id?)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Toegevoegd', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _open(id),
                    child: const Text('Bekijken'),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _accept,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    proposal.kind == ProposalKind.exercise
                        ? 'Oefening toevoegen'
                        : 'Routine toevoegen',
                  ),
                ),
              ),
          ],
        ),
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

/// The photo that is about to be sent, above the field.
class _PickedPhoto extends ConsumerWidget {
  const _PickedPhoto({required this.fileName, required this.onRemove});

  final String fileName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (paths != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.file(
                PhotoStore(paths).fileFor(fileName),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Deze foto gaat mee met je vraag.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Toch niet',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// A photo inside a message, tappable to see it whole.
class _SentPhoto extends ConsumerWidget {
  const _SentPhoto({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(appPathsProvider).value;
    if (paths == null) return const SizedBox.shrink();

    final file = PhotoStore(paths).fileFor(fileName);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
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
            width: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                const MissingPhotoPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text(
            'De coach denkt na…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
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
          Row(
            children: [
              TextButton(onPressed: onRetry, child: const Text('Sluiten')),
              if (keyRejected)
                TextButton(
                  onPressed: () => context.push(Routes.settingsCoach),
                  child: const Text('Naar instellingen'),
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
  final VoidCallback onPickPhoto;

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
          IconButton.filled(
            tooltip: 'Versturen',
            onPressed: busy ? null : () => onSend(controller.text),
            icon: const Icon(Icons.arrow_upward),
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
              'Vul een Anthropic API-sleutel in om hem aan te zetten. Zonder '
              'sleutel maakt FitLog geen enkele verbinding.',
          actionLabel: 'Naar instellingen',
          onAction: () => context.push(Routes.settingsCoach),
        ),
      ),
    );
  }
}
