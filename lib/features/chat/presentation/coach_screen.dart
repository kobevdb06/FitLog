/// The conversation with the coach.
///
/// It only exists once the user has entered an API key of their own. Every
/// answer says underneath it what the coach looked up in the database and
/// what the question cost, because both are the user's: their data and their
/// money.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
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

    _controller.clear();
    await controller.ask(threadId: thread, question: question);
    _toBottom();
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

  Future<void> _pickThread() async {
    final threads = ref.read(chatThreadsProvider).value ?? const [];
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
          if (threads.isNotEmpty) const Divider(height: 1),
          for (final thread in threads)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(thread.title, maxLines: 2),
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
            onPressed: _pickThread,
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
            _Ask(controller: _controller, busy: state.sending, onSend: _send),
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
  });

  final TextEditingController controller;
  final bool busy;
  final void Function(String question) onSend;

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
