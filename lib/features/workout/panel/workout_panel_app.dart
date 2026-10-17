import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routing/routes.dart';
import 'coach_panel.dart';
import 'edit_panel.dart';
import 'panel_bridge.dart';
import 'panel_set.dart';

/// The panel over another app, from a button in the workout notification.
///
/// A card at the top, under the island it came from, over a dim of the app
/// below; a tap on the dim closes it as Sluiten does.
class WorkoutPanelApp extends StatefulWidget {
  const WorkoutPanelApp({super.key, required this.bridge, this.biometrics});

  final PanelBridge bridge;

  /// The fingerprint for the coach's lock; null where there is none.
  final BiometricService? biometrics;

  @override
  State<WorkoutPanelApp> createState() => _WorkoutPanelAppState();
}

class _WorkoutPanelAppState extends State<WorkoutPanelApp> {
  final _edit = GlobalKey<EditPanelState>();
  PanelState? _state;
  String _mode = 'edit';

  /// Bumped each time Coach is tapped, so the coach panel starts over.
  int _coachOpened = 0;
  StreamSubscription<String>? _modes;

  @override
  void initState() {
    super.initState();
    _modes = widget.bridge.modes.listen((mode) {
      setState(() {
        _mode = mode;
        if (mode == 'coach') _coachOpened++;
      });
      if (mode != 'coach') _load();
    });
    unawaited(_start());
  }

  Future<void> _start() async {
    final mode = await widget.bridge.mode();
    if (mounted) setState(() => _mode = mode);
    await _load();
  }

  @override
  void dispose() {
    _modes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final state = PanelState.from(await widget.bridge.relay('state'));
    if (mounted) setState(() => _state = state);
  }

  Future<void> _close() async {
    final edit = _edit.currentState;
    if (edit != null) {
      await edit.close();
    } else {
      await widget.bridge.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (state?.theme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    // A tap on the card itself is not a tap on the dim. Taller
                    // than the room left by a keyboard, it scrolls.
                    child: GestureDetector(
                      onTap: () {},
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height -
                                MediaQuery.of(context).viewInsets.bottom -
                                MediaQuery.of(context).padding.vertical -
                                AppSpacing.sm * 2,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _content(context, state),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, PanelState? state) {
    if (_mode == 'coach') {
      return CoachPanel(
        key: ValueKey(_coachOpened),
        bridge: widget.bridge,
        biometrics: widget.biometrics,
      );
    }
    if (state == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final set = state.set;
    if (state.closed) {
      return _Message(
        title: 'FitLog is gesloten',
        text: 'Android sloot de app. Open ze om verder te gaan met je workout.',
        bridge: widget.bridge,
      );
    }
    if (set == null) {
      return _Message(
        title: 'Alle sets gedaan',
        text: 'Rond je workout af in FitLog.',
        bridge: widget.bridge,
      );
    }
    if (!set.outside) {
      return _Message(
        title: set.exercise,
        text: 'Deze set vul je in FitLog zelf in.',
        bridge: widget.bridge,
      );
    }
    return EditPanel(
      key: _edit,
      state: state,
      bridge: widget.bridge,
      // The next set, or the message that there is none.
      onState: (next) => setState(() => _state = next),
    );
  }
}

/// A panel with nothing to change: why, and the way into FitLog.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.text,
    required this.bridge,
  });

  final String title;
  final String text;
  final PanelBridge bridge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(text, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton(
              onPressed: bridge.close,
              child: const Text('Sluiten'),
            ),
            FilledButton(
              onPressed: () => bridge.openApp(Routes.workout),
              child: const Text('Open FitLog'),
            ),
          ],
        ),
      ],
    );
  }
}
