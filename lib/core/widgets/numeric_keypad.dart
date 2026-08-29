import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../util/feedback_service.dart';
import 'keypad_value.dart';

/// Which cell of a set row the keypad is editing.
enum KeypadFieldKind {
  weight(label: 'Gewicht', decimals: 2, steps: [1.25, 2.5, 5]),
  reps(label: 'Reps', decimals: 0, steps: [1, 5]),
  duration(label: 'Tijd (s)', decimals: 0, steps: [5, 15, 30]),
  distance(label: 'Afstand', decimals: 2, steps: [0.1, 0.5, 1]),
  rpe(label: 'RPE', decimals: 1, steps: [0.5, 1]);

  const KeypadFieldKind({
    required this.label,
    required this.decimals,
    required this.steps,
  });

  final String label;
  final int decimals;
  final List<double> steps;

  bool get allowsDecimal => decimals > 0;
}

/// The custom numeric pad.
///
/// This is the single biggest usability decision in the app: logging a set
/// never opens the system keyboard. The pad is thumb-sized, has plus/minus
/// steps for the increments people actually load, and a "next" key that walks
/// from weight to reps to the next set.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.value,
    required this.kind,
    required this.onChanged,
    required this.onDone,
    this.onNext,
    this.unitLabel,
    this.title,
    this.steps,
    this.feedback = const FeedbackService(),
  });

  final KeypadValue value;
  final KeypadFieldKind kind;
  final ValueChanged<KeypadValue> onChanged;
  final VoidCallback onDone;

  /// Moves to the next field. Hidden when there is nothing to move to.
  final VoidCallback? onNext;

  final String? unitLabel;
  final String? title;

  /// Overrides the default steps, so pounds can use 5/10 instead of 2.5/5.
  final List<double>? steps;

  final FeedbackService feedback;

  List<double> get _steps => steps ?? kind.steps;

  void _emit(KeypadValue next) {
    if (next == value) return;
    feedback.tick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                title: title ?? kind.label,
                value: value,
                unitLabel: unitLabel,
                onClear: () => _emit(value.clear()),
              ),
              const SizedBox(height: AppSpacing.sm),
              _StepRow(
                steps: _steps,
                onStep: (delta) => _emit(
                  value.step(delta, decimals: kind.decimals),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Digits(
                kind: kind,
                onDigit: (d) => _emit(
                  value.appendDigit(d, maxDecimals: kind.decimals),
                ),
                onDecimal: () => _emit(
                  value.appendDecimal(allowDecimal: kind.allowsDecimal),
                ),
                onBackspace: () => _emit(value.backspace()),
                onNext: onNext,
                onDone: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.value,
    required this.unitLabel,
    required this.onClear,
  });

  final String title;
  final KeypadValue value;
  final String? unitLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value.isEmpty ? '-' : value.text,
          style: theme.textTheme.headlineSmall,
        ),
        if (unitLabel != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            unitLabel!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: 'Leegmaken',
          onPressed: onClear,
          icon: const Icon(Icons.backspace_outlined),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.steps, required this.onStep});

  final List<double> steps;
  final ValueChanged<double> onStep;

  String _label(double v) {
    final text = v == v.roundToDouble()
        ? '${v.round()}'
        : v.toString().replaceAll('.', ',');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final step in steps.reversed) ...[
          Expanded(
            child: _StepButton(
              label: '−${_label(step)}',
              onTap: () => onStep(-step),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        for (final step in steps) ...[
          Expanded(
            child: _StepButton(
              label: '+${_label(step)}',
              onTap: () => onStep(step),
              accent: true,
            ),
          ),
          if (step != steps.last) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppSpacing.minTouch,
      child: Material(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent ? AppColors.accent : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Digits extends StatelessWidget {
  const _Digits({
    required this.kind,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.onNext,
    required this.onDone,
  });

  final KeypadFieldKind kind;
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback? onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                for (final d in row) ...[
                  Expanded(child: _Key(label: d, onTap: () => onDigit(d))),
                  if (d != row.last) const SizedBox(width: AppSpacing.xs),
                ],
                const SizedBox(width: AppSpacing.xs),
                if (row.first == '1')
                  Expanded(
                    child: _Key(
                      icon: Icons.backspace_outlined,
                      onTap: onBackspace,
                      semanticLabel: 'Wis cijfer',
                    ),
                  )
                else if (row.first == '4')
                  Expanded(
                    child: _Key(
                      icon: Icons.keyboard_tab,
                      onTap: onNext,
                      semanticLabel: 'Volgend veld',
                      tone: _KeyTone.neutral,
                    ),
                  )
                else
                  Expanded(
                    child: _Key(
                      icon: Icons.check,
                      onTap: onDone,
                      semanticLabel: 'Klaar',
                      tone: _KeyTone.accent,
                      tall: true,
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _Key(
                label: kind.allowsDecimal ? kDecimalSeparator : '',
                onTap: kind.allowsDecimal ? onDecimal : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 2,
              child: _Key(label: '0', onTap: () => onDigit('0')),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Keeps the grid aligned with the fourth column above.
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

enum _KeyTone { normal, neutral, accent }

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.tone = _KeyTone.normal,
    this.semanticLabel,
    this.tall = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final _KeyTone tone;
  final String? semanticLabel;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background = switch (tone) {
      _KeyTone.accent => AppColors.accent,
      _KeyTone.neutral => theme.colorScheme.surfaceContainerHighest,
      _KeyTone.normal => theme.colorScheme.surfaceContainerHighest,
    };
    final foreground = switch (tone) {
      _KeyTone.accent => Colors.white,
      _ => theme.colorScheme.onSurface,
    };

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: SizedBox(
        height: tall ? 56 : 52,
        child: Material(
          color: onTap == null
              ? Colors.transparent
              : background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: foreground)
                  : Text(
                      label ?? '',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
