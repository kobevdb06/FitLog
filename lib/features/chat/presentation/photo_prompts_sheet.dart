import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../data/links.dart';
import 'chat_providers.dart';

/// The two prompts the coach wrote for the photos of [exercise], and the way
/// to Gemini to make them.
///
/// FitLog does not make the pictures itself (DECISIONS 201). A model the user
/// picks does, in its own app; what FitLog adds is the coach's words for it,
/// ready to paste - the start first, then the end in the same conversation,
/// so the two come out as the same person in the same place.
Future<void> showPhotoPrompts(
  BuildContext context, {
  required String exercise,
  required String start,
  required String end,
}) => showAppSheet<void>(
  context: context,
  title: "Foto's maken met Gemini",
  builder: (context) =>
      _PhotoPrompts(exercise: exercise, start: start, end: end),
);

class _PhotoPrompts extends ConsumerWidget {
  const _PhotoPrompts({
    required this.exercise,
    required this.start,
    required this.end,
  });

  final String exercise;
  final String start;
  final String end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final opener = ref.watch(linkOpenerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Plak de eerste prompt in Gemini voor de startpositie. Vraag '
            'daarna in hetzelfde gesprek de eindpositie: zo lijken de twee '
            "foto's op elkaar.",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _PromptCard(step: '1 · Startpositie', text: start),
          const SizedBox(height: AppSpacing.sm),
          _PromptCard(step: '2 · Eindpositie', text: end),
          if (opener != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () async {
                final opened = await opener.open(kGeminiUrl);
                if (!opened && context.mounted) {
                  showSnack(
                    context,
                    'Gemini kon niet geopend worden. Ga in je browser naar '
                    'gemini.google.com.',
                    isError: true,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Gemini'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            "Bewaar de twee foto's en zet ze op \"$exercise\" via Bewerken. "
            'Of stuur ze hier naar de coach: die zet ze er voor je op.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One prompt, to read and to copy.
///
/// The copy says so on its own button rather than in a snackbar: one shown
/// from here would sit behind this sheet.
class _PromptCard extends StatefulWidget {
  const _PromptCard({required this.step, required this.text});

  final String step;
  final String text;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.step, style: theme.textTheme.labelLarge),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                  label: Text(_copied ? 'Gekopieerd' : 'Kopiëren'),
                ),
              ],
            ),
            SelectableText(widget.text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
