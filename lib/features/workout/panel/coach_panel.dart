import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../routing/routes.dart';
import '../../lock/presentation/pin_pad.dart';
import 'panel_bridge.dart';

/// The three questions that come up between two sets, one tap each.
const List<String> kSetQuestions = [
  'Mag ik zwaarder?',
  'Hoe lang moet ik rusten?',
  'Wat kan ik in de plaats doen?',
];

/// Coach: a question about the set you are on, over the app you are in.
///
/// Behind the PIN when there is one. The answer comes in as it is written,
/// and the conversation goes on in FitLog's chat - it is stored there.
class CoachPanel extends StatefulWidget {
  const CoachPanel({super.key, required this.bridge, this.biometrics});

  final PanelBridge bridge;

  /// Null outside the phone, where there is no fingerprint to ask.
  final BiometricService? biometrics;

  @override
  State<CoachPanel> createState() => _CoachPanelState();
}

class _Line {
  const _Line(this.mine, this.text, {this.lookups = const []});

  final bool mine;
  final String text;
  final List<String> lookups;
}

class _CoachPanelState extends State<CoachPanel> {
  final _field = TextEditingController();
  StreamSubscription<Map<Object?, Object?>>? _events;

  bool _loaded = false;

  /// Android closed FitLog: there is no coach to reach from here.
  bool _closed = false;
  bool _available = false;
  bool _locked = false;
  bool _biometric = false;
  String? _about;
  final _lines = <_Line>[];

  String _pin = '';
  String? _pinError;
  int _lockout = 0;

  bool _asking = false;
  String _writing = '';
  String? _looking;
  String? _error;
  String? _empty;

  @override
  void initState() {
    super.initState();
    _events = widget.bridge.events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _field.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = await widget.bridge.relay('coachState');
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _closed = state['closed'] == true;
      _available = state['available'] == true;
      _locked = state['locked'] == true;
      _biometric = state['biometric'] == true;
      _lockout = (state['lockoutSeconds'] as num?)?.toInt() ?? 0;
      _about = state['about'] as String?;
      _lines
        ..clear()
        ..addAll([
          for (final raw in state['thread'] as List? ?? const [])
            _Line((raw as Map)['role'] == 'user', raw['text'] as String),
        ]);
    });
    if (_locked && _biometric) unawaited(_fingerprint());
  }

  void _onEvent(Map<Object?, Object?> event) {
    if (!mounted) return;
    setState(() {
      switch (event['type']) {
        case 'writing':
          _writing = event['text'] as String? ?? '';
          _looking = event['looking'] as String?;
        case 'done':
          _lines.add(
            _Line(
              false,
              event['text'] as String? ?? '',
              lookups: [for (final l in event['lookups'] as List? ?? []) '$l'],
            ),
          );
          _writing = '';
          _looking = null;
          _asking = false;
        case 'error':
          _error = event['message'] as String?;
          _writing = '';
          _looking = null;
          _asking = false;
      }
    });
  }

  Future<void> _digit(String digit) async {
    if (_pin.length >= kPinLength || _lockout > 0) return;
    setState(() {
      _pin += digit;
      _pinError = null;
    });
    if (_pin.length < kPinLength) return;
    final answer = await widget.bridge.relay('coachUnlock', {'pin': _pin});
    if (!mounted) return;
    setState(() {
      _pin = '';
      if (answer['ok'] == true) {
        _locked = false;
      } else {
        _lockout = (answer['lockoutSeconds'] as num?)?.toInt() ?? 0;
        _pinError = _lockout > 0
            ? 'Verkeerde pincode. Probeer opnieuw over $_lockout s.'
            : 'Verkeerde pincode.';
      }
    });
    if (_lockout > 0) _countDown();
  }

  void _countDown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _lockout <= 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockout--;
        if (_lockout == 0) _pinError = null;
      });
    });
  }

  Future<void> _fingerprint() async {
    final biometrics = widget.biometrics;
    if (biometrics == null) return;
    final ok = await biometrics.authenticate(
      reason: 'Ontgrendel de coach van FitLog',
    );
    if (!ok || !mounted) return;
    final answer = await widget.bridge.relay('coachUnlock', {
      'biometric': true,
    });
    if (mounted && answer['ok'] == true) setState(() => _locked = false);
  }

  Future<void> _ask(String question) async {
    final text = question.trim();
    if (text.isEmpty) {
      setState(() => _empty = 'Typ eerst een vraag');
      return;
    }
    if (_asking) return;
    setState(() {
      _lines.add(_Line(true, text));
      _asking = true;
      _error = null;
      _empty = null;
      _writing = '';
    });
    _field.clear();
    final answer = await widget.bridge.relay('coachAsk', {'question': text});
    if (!mounted) return;
    if (answer['locked'] == true) setState(() => _locked = true);
    if (answer['closed'] == true) {
      setState(() {
        _asking = false;
        _error = 'FitLog is gesloten. Open de app om de coach te vragen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent,
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coach', style: theme.textTheme.titleMedium),
                  if (_about != null) Text(_about!, style: muted),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Coach sluiten',
              onPressed: widget.bridge.close,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._body(context),
      ],
    );
  }

  List<Widget> _body(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!_loaded) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_closed) {
      return [
        Text(
          'Android sloot FitLog. Open de app om de coach te vragen.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => widget.bridge.openApp(Routes.chat),
            child: const Text('Open FitLog'),
          ),
        ),
      ];
    }
    if (!_available) {
      return [
        Text(
          'De coach staat uit. Zet hem aan in FitLog, met een sleutel van '
          'Google.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => widget.bridge.openApp(Routes.coachKey),
            child: const Text('Coach aanzetten'),
          ),
        ),
      ];
    }
    if (_locked) {
      return [
        Text(
          'Je pincode, om de coach te openen.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        PinPad(
          entered: _pin,
          onDigit: _digit,
          onBackspace: () => setState(() {
            if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
          }),
          errorText: _pinError,
          enabled: _lockout == 0,
          biometricEnabled: _biometric && widget.biometrics != null,
          onBiometric: _fingerprint,
        ),
      ];
    }

    return [
      for (final line
          in _lines.length > 6 ? _lines.sublist(_lines.length - 6) : _lines)
        _Bubble(line: line),
      if (_asking)
        _Bubble(
          line: _Line(
            false,
            _writing.isNotEmpty
                ? _writing
                : _looking == null
                ? 'De coach denkt na…'
                : 'Bekijkt $_looking…',
          ),
          waiting: _writing.isEmpty,
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      if (_lines.isEmpty && !_asking)
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final question in kSetQuestions)
              ActionChip(
                label: Text(question),
                onPressed: () => _ask(question),
              ),
          ],
        ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _field,
              enabled: !_asking,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              onChanged: (_) {
                if (_empty != null) setState(() => _empty = null);
              },
              decoration: InputDecoration(
                hintText: 'Vraag iets over deze set',
                errorText: _empty,
                isDense: true,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Versturen',
            onPressed: _asking ? null : () => _ask(_field.text),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      // Under each other: side by side they do not fit a phone with large
      // text.
      Text('Gaat naar Google, zoals elke vraag aan de coach.', style: muted),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => widget.bridge.openApp(Routes.chat),
          child: const Text('Verder in FitLog'),
        ),
      ),
    ];
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.line, this.waiting = false});

  final _Line line;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = line.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: mine
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    line.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: waiting
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
              ),
              if (line.lookups.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Bekeken: ${line.lookups.join(', ')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
