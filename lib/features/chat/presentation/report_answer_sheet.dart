import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../settings/presentation/about_screen.dart';
import '../domain/answer_report.dart';
import 'chat_providers.dart';

/// Reporting a coach answer to the maker, from where it was read.
///
/// Google Play asks an app that writes with AI for a way to flag what it
/// wrote without going elsewhere to find out how. The flag is made here: the
/// reason, a note, and the answer itself are put together in the app. The
/// mail app only carries it, with every word visible before it goes
/// (DECISIONS 211).
Future<void> showReportAnswer(
  BuildContext context, {
  required String answer,
  required DateTime answeredAt,
  String? question,
}) => showAppSheet<void>(
  context: context,
  title: 'Dit antwoord melden',
  builder: (context) =>
      _ReportAnswer(answer: answer, answeredAt: answeredAt, question: question),
);

class _ReportAnswer extends ConsumerStatefulWidget {
  const _ReportAnswer({
    required this.answer,
    required this.answeredAt,
    this.question,
  });

  final String answer;
  final DateTime answeredAt;
  final String? question;

  @override
  ConsumerState<_ReportAnswer> createState() => _ReportAnswerState();
}

class _ReportAnswerState extends ConsumerState<_ReportAnswer> {
  final _note = TextEditingController();
  ReportReason? _reason;

  /// No mail app took it, so the report went on the clipboard instead. Said
  /// here rather than in a snackbar, which would sit behind this sheet.
  bool _copied = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final report = AnswerReport(
      reason: _reason!,
      note: _note.text,
      question: widget.question,
      answer: widget.answer,
      answeredAt: widget.answeredAt,
      version: AboutScreen.appVersion,
    );
    final opener = ref.read(linkOpenerProvider);
    final opened = opener != null && await opener.open(report.mailto);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: '${report.subject}\n\n${report.body}'),
    );
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Zei de coach iets wat gevaarlijk is, kwetsend, of gewoon niet '
            'klopt? Laat het de maker van FitLog weten.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (reason) => setState(() => _reason = reason),
            child: Column(
              children: [
                for (final reason in ReportReason.values)
                  RadioListTile<ReportReason>(
                    value: reason,
                    title: Text(reason.label),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Toelichting (mag leeg blijven)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Je mail-app opent met de reden, je vraag en dit antwoord erin, '
            'aan $kReportAddress. Er gaat niets weg tot jij het verstuurt.',
            style: quiet,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _reason == null ? null : _send,
            icon: const Icon(Icons.mail_outline),
            label: const Text('E-mail opstellen'),
          ),
          if (_copied) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Er is geen mail-app die dit opent. Het verslag staat op je '
              'klembord: plak het in een e-mail aan $kReportAddress.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
