import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/fitlog_mark.dart';
import '../../../routing/routes.dart';
import '../data/ai_client.dart';
import '../data/links.dart';
import 'chat_providers.dart';

/// Switching the coach on, a step at a time: what it is and what it costs
/// you, fetching a free key from Google, pasting it - tested before it is
/// kept.
///
/// There is no way to hand a key over without the user: Google gives it to
/// them, not to an app. So the flow is about the few taps in between -
/// knowing why, finding the page, getting back, pasting - and each of them
/// is a screen of its own.
class CoachKeyScreen extends ConsumerStatefulWidget {
  const CoachKeyScreen({super.key, this.pasteFirst = false});

  /// Straight to pasting: for a key that was refused, or one being replaced.
  final bool pasteFirst;

  @override
  ConsumerState<CoachKeyScreen> createState() => _CoachKeyScreenState();
}

enum _Step { why, fetch, paste, done }

class _CoachKeyScreenState extends ConsumerState<CoachKeyScreen>
    with WidgetsBindingObserver {
  late _Step _step = widget.pasteFirst ? _Step.paste : _Step.why;
  final _field = TextEditingController();
  var _obscured = true;
  var _busy = false;
  String? _failure;

  /// Whether there is text on the clipboard - asked without reading it, so
  /// Android shows no notice. What it is, is read only when the user taps
  /// Plak.
  var _clipboardHasText = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_step == _Step.paste) _lookAtClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _field.dispose();
    super.dispose();
  }

  /// Back from AI Studio, with a key copied, most likely.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _Step.paste) {
      _lookAtClipboard();
    }
  }

  Future<void> _lookAtClipboard() async {
    final has = await Clipboard.hasStrings();
    if (mounted) setState(() => _clipboardHasText = has);
  }

  void _go(_Step step) {
    setState(() {
      _step = step;
      _failure = null;
    });
    if (step == _Step.paste) _lookAtClipboard();
  }

  Future<void> _fetch() async {
    final opener = ref.read(linkOpenerProvider);
    // Already on the paste step when the user comes back.
    _go(_Step.paste);
    if (opener == null) return;
    final opened = await opener.openOver(kAiStudioKeyUrl);
    if (!opened && mounted) {
      setState(
        () => _failure =
            'Er is geen browser om AI Studio te openen. Ga op een computer of '
            'in je browser naar aistudio.google.com/apikey.',
      );
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() => _failure = 'Er staat geen tekst op je klembord.');
      return;
    }
    setState(() {
      _field.text = text;
      _failure = null;
      _clipboardHasText = false;
    });
  }

  Future<void> _testAndKeep() async {
    // A key never has a space in it; one that was copied with a line break
    // around it, or split over two lines, is still the same key.
    final key = _field.text.replaceAll(RegExp(r'\s'), '');
    if (key.isEmpty) {
      setState(() => _failure = 'Plak of typ eerst je sleutel.');
      return;
    }
    // A key that unmistakably belongs to another service is said to be one,
    // rather than sent off to come back as a refusal that explains nothing.
    final belongsTo = CoachProvider.forKey(key);
    if (!kOfferedProviders.contains(belongsTo)) {
      setState(
        () => _failure =
            'Dat lijkt een sleutel van ${belongsTo.label}. De coach werkt '
            'alleen met een sleutel van Google AI Studio.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await ref
        .read(coachControllerProvider.notifier)
        .checkKey(key);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _failure = failure.badKey
            ? 'Deze sleutel werkt niet. Kijk of je hem helemaal kopieerde, of '
                  'maak in AI Studio een nieuwe.'
            : failure.message;
      });
      return;
    }

    await ref.read(databaseProvider).settingsDao.setApiKey(key);
    if (!mounted) return;
    setState(() => _busy = false);
    _go(_Step.done);
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.pasteFirst ? _Step.paste : _Step.why;
    final number = _step.index + 1;

    return PopScope(
      // Back goes a step back, until the step this was opened on.
      canPop: _step == first || _step == _Step.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Step.values[_step.index - 1]);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _step == _Step.done ? 'Coach aangezet' : 'Coach aanzetten',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_step != _Step.done) ...[
              Text(
                'Stap $number van 3',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            switch (_step) {
              _Step.why => _Why(onNext: () => _go(_Step.fetch)),
              _Step.fetch => _Fetch(
                onFetch: _fetch,
                onHaveOne: () => _go(_Step.paste),
              ),
              _Step.paste => _Paste(
                field: _field,
                obscured: _obscured,
                onToggleObscured: () => setState(() => _obscured = !_obscured),
                busy: _busy,
                failure: _failure,
                clipboardHasText: _clipboardHasText,
                onPaste: _paste,
                onTest: _testAndKeep,
              ),
              _Step.done => const _Done(),
            },
          ],
        ),
      ),
    );
  }
}

/// What the coach is, and what it costs you - in money and in what leaves
/// the phone.
class _Why extends ConsumerWidget {
  const _Why({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final opener = ref.watch(linkOpenerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Je eigen, gratis coach', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'De coach praat met Gemini van Google, met een sleutel van jezelf. '
          'Die is gratis en maak je in een paar tikken met je Google-account. '
          'FitLog heeft geen account, geen server en geen abonnement.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        const InfoBanner(
          icon: Icons.lock_outline,
          message:
              'Wat meegaat: je vraag, en wat de coach in je logboek opzoekt om '
              'te antwoorden. Met een gratis sleutel mag Google dat gebruiken '
              'om zijn producten te verbeteren, en kunnen mensen het daarvoor '
              'lezen.',
        ),
        if (opener != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => opener.open(kGeminiTermsUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Voorwaarden van Google'),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onNext, child: const Text('Volgende')),
      ],
    );
  }
}

/// Fetching the key: three things to do on Google's page, and the button
/// that opens it.
///
/// Said without the names of Google's buttons - those change - and drawn
/// rather than photographed, for the same reason.
class _Fetch extends StatelessWidget {
  const _Fetch({required this.onFetch, required this.onHaveOne});

  final VoidCallback onFetch;
  final VoidCallback onHaveOne;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Haal je sleutel', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'De knop opent Google AI Studio. Daar doe je dit:',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        const _HowTo(
          picture: _Picture.account,
          text: 'Log in met je Google-account.',
        ),
        const _HowTo(
          picture: _Picture.key,
          text:
              'Meestal staat er al een sleutel klaar. Zo niet, maak er een '
              'aan.',
        ),
        const _HowTo(
          picture: _Picture.back,
          text: 'Kopieer de sleutel en kom terug naar FitLog.',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onFetch,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Haal mijn gratis sleutel'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: onHaveOne,
          child: const Text('Ik heb al een sleutel'),
        ),
      ],
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo({required this.picture, required this.text});

  final _Picture picture;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          ExcludeSemantics(child: _StepPicture(picture)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

enum _Picture { account, key, back }

/// A small drawing of one step, in the app's own colours: a screen with the
/// one thing on it that matters.
class _StepPicture extends StatelessWidget {
  const _StepPicture(this.picture);

  final _Picture picture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(double width) => Container(
      width: width,
      height: 5,
      decoration: BoxDecoration(
        color: scheme.outline,
        borderRadius: BorderRadius.circular(3),
      ),
    );

    final content = switch (picture) {
      _Picture.account => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 30, color: AppColors.accent),
          const SizedBox(height: 4),
          bar(44),
        ],
      ),
      _Picture.key => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vpn_key_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: 4),
          bar(28),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.copy, size: 14, color: AppColors.accent),
          ),
        ],
      ),
      _Picture.back => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.copy, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          const FitLogMark(size: 28),
        ],
      ),
    };

    return Container(
      width: 96,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          // The top of a browser window: where the page is.
          Container(
            height: 10,
            margin: const EdgeInsets.fromLTRB(6, 5, 6, 0),
            decoration: BoxDecoration(
              color: scheme.outline.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Pasting the key, and testing it before it is kept.
class _Paste extends StatelessWidget {
  const _Paste({
    required this.field,
    required this.obscured,
    required this.onToggleObscured,
    required this.busy,
    required this.failure,
    required this.clipboardHasText,
    required this.onPaste,
    required this.onTest,
  });

  final TextEditingController field;
  final bool obscured;
  final VoidCallback onToggleObscured;
  final bool busy;
  final String? failure;
  final bool clipboardHasText;
  final VoidCallback onPaste;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plak je sleutel', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'FitLog test hem meteen, en bewaart hem pas als hij werkt - '
          'versleuteld, achter je pincode.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (clipboardHasText) ...[
          Text(
            'Er staat iets op je klembord.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        // Outlined: the step that counts is Testen en bewaren; two equally
        // loud buttons on one screen left that unclear.
        OutlinedButton.icon(
          onPressed: busy ? null : onPaste,
          icon: const Icon(Icons.content_paste),
          label: const Text('Plak sleutel'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: field,
          obscureText: obscured,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'API-sleutel',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: obscured ? 'Tonen' : 'Verbergen',
              onPressed: onToggleObscured,
              icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            failure!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: busy ? null : onTest,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Testen en bewaren'),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 48, color: AppColors.success),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Je coach staat aan',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Vraag hem alles over trainen, herstel en deze app. Onder elk '
          'antwoord staat wat hij in je logboek bekeek.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => context.go(Routes.chat),
          child: const Text('Stel je eerste vraag'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Klaar'),
        ),
      ],
    );
  }
}
