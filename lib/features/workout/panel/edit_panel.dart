import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/db/enums.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fitlog_mark.dart';
import 'panel_bridge.dart';
import 'panel_set.dart';

/// How long the tick stays before the next set comes - the same moment the
/// island holds its "afgevinkt".
const Duration kPanelConfirmTime = Duration(milliseconds: 1200);

/// Aanpassen: the set's weight and reps with a minus and a plus, ticked off
/// from here or saved as it is when the panel closes.
class EditPanel extends StatefulWidget {
  const EditPanel({
    super.key,
    required this.state,
    required this.bridge,
    required this.onState,
  });

  final PanelState state;
  final PanelBridge bridge;

  /// The app's answer after a tick: the next set, or none left.
  final ValueChanged<PanelState> onState;

  @override
  State<EditPanel> createState() => EditPanelState();
}

class EditPanelState extends State<EditPanel> {
  double _weight = 0;
  int _reps = 0;
  int _seconds = 0;
  bool _changed = false;

  /// Set from the tap on Afvinken until the next set is there.
  String? _ticked;
  bool _busy = false;

  Formatters get _format => Formatters(weightUnit: widget.state.unit);

  /// In the unit shown: the exercise's own step in kilograms, a fixed 5 in
  /// pounds, as the keypad does.
  double get _step => widget.state.unit == WeightUnit.kg
      ? widget.state.set!.stepKg
      : _format.weightStep;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.set?.id != widget.state.set?.id) _load();
  }

  void _load() {
    final set = widget.state.set;
    if (set == null) return;
    _weight = set.weightKg == null ? 0 : _format.toDisplayWeight(set.weightKg!);
    _reps = set.reps ?? 0;
    _seconds = set.durationSeconds ?? 0;
    _changed = false;
    _ticked = null;
  }

  Map<String, Object?> _values(PanelSet set) => {
    'setId': set.id,
    if (set.hasWeight)
      'weightKg': _format.fromDisplayWeight(
        (_weight * 100).roundToDouble() / 100,
      ),
    if (set.hasReps) 'reps': _reps,
    if (set.hasDuration) 'durationSeconds': _seconds,
  };

  String _summary(PanelSet set) => _format.setSummary(
    weightKg: set.hasWeight ? _format.fromDisplayWeight(_weight) : null,
    reps: set.hasReps ? _reps : null,
    durationSeconds: set.hasDuration ? _seconds : null,
  );

  /// Closes the panel, keeping what the steppers say: the island then shows
  /// it, and so does the set row in the app.
  Future<void> close() async {
    final set = widget.state.set;
    if (_changed && _ticked == null && set != null) {
      await widget.bridge.relay('update', _values(set));
    }
    await widget.bridge.close();
  }

  Future<void> _tick() async {
    final set = widget.state.set;
    if (set == null || _busy) return;
    final summary = _summary(set);
    setState(() {
      _busy = true;
      _ticked = '${set.label} afgevinkt · $summary';
    });
    final started = DateTime.now();
    final answer = await widget.bridge.relay('complete', _values(set));
    final rest = kPanelConfirmTime - DateTime.now().difference(started);
    if (rest > Duration.zero) await Future<void>.delayed(rest);
    if (!mounted) return;
    _busy = false;
    widget.onState(PanelState.from(answer));
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.state.set!;
    final theme = Theme.of(context);
    final ticked = _ticked;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ticked != null
          ? _Ticked(key: ValueKey('ticked-${set.id}'), text: ticked, set: set)
          : Column(
              key: ValueKey('edit-${set.id}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const FitLogMark(size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            set.exercise,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            set.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (set.hasWeight)
                  _Stepper(
                    label: 'Gewicht',
                    value:
                        '${_format.decimal(_weight)} ${_format.weightUnitLabel}',
                    less: 'Minder gewicht',
                    more: 'Meer gewicht',
                    onLess: _weight <= 0
                        ? null
                        : () => setState(() {
                            _weight = (_weight - _step).clamp(0, 10000);
                            _changed = true;
                          }),
                    onMore: () => setState(() {
                      _weight += _step;
                      _changed = true;
                    }),
                  ),
                if (set.hasReps)
                  _Stepper(
                    label: 'Herhalingen',
                    value: '$_reps',
                    less: 'Minder herhalingen',
                    more: 'Meer herhalingen',
                    onLess: _reps <= 0
                        ? null
                        : () => setState(() {
                            _reps--;
                            _changed = true;
                          }),
                    onMore: () => setState(() {
                      _reps++;
                      _changed = true;
                    }),
                  ),
                if (set.hasDuration)
                  _Stepper(
                    label: 'Tijd',
                    value: Formatters.duration(_seconds)
                        .replaceFirst(RegExp('^0'), ''),
                    less: '5 seconden minder',
                    more: '5 seconden meer',
                    onLess: _seconds <= 0
                        ? null
                        : () => setState(() {
                            _seconds = (_seconds - 5).clamp(0, 36000);
                            _changed = true;
                          }),
                    onMore: () => setState(() {
                      _seconds += 5;
                      _changed = true;
                    }),
                  ),
                const SizedBox(height: AppSpacing.sm),
                PanelBar(marks: set.marks),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      onPressed: close,
                      child: const Text('Sluiten'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _tick,
                      icon: const Icon(Icons.check),
                      label: const Text('Afvinken'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// One value with its minus and plus.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.less,
    required this.more,
    required this.onLess,
    required this.onMore,
  });

  final String label;
  final String value;
  final String less;
  final String more;
  final VoidCallback? onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: less,
              onPressed: onLess,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: more,
              onPressed: onMore,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

/// The working sets of the exercise, one segment each - as in the island.
class PanelBar extends StatelessWidget {
  const PanelBar({super.key, required this.marks, this.justDone});

  final List<String> marks;

  /// The segment that was just ticked off, drawn as it fills.
  final int? justDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < marks.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == justDone
                    ? AppColors.success
                    : switch (marks[i]) {
                        'done' => AppColors.accent,
                        'skipped' => scheme.outline,
                        _ => scheme.outlineVariant,
                      },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The moment after Afvinken: a tick that springs into view, and the
/// segment of the set filling.
class _Ticked extends StatefulWidget {
  const _Ticked({super.key, required this.text, required this.set});

  final String text;
  final PanelSet set;

  @override
  State<_Ticked> createState() => _TickedState();
}

class _TickedState extends State<_Ticked> {
  int? _filled;

  @override
  void initState() {
    super.initState();
    // One frame later, so the segment is seen to fill rather than appear.
    scheduleMicrotask(() {
      if (mounted) setState(() => _filled = widget.set.position);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.md),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: still ? 1 : 0.3, end: 1),
          duration: still ? Duration.zero : const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.text,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        PanelBar(marks: widget.set.marks, justDone: _filled),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
