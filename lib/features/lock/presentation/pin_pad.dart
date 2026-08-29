import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/feedback_service.dart';

/// The PIN length used everywhere in the app.
const int kPinLength = 6;

/// The six dots plus the digit pad. Used by onboarding, the lock screen and
/// the "change PIN" flow, so there is only one PIN interaction in the app.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.entered,
    required this.onDigit,
    required this.onBackspace,
    this.errorText,
    this.enabled = true,
    this.biometricEnabled = false,
    this.onBiometric,
    this.feedback = const FeedbackService(),
  });

  /// What the user has typed so far.
  final String entered;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final String? errorText;
  final bool enabled;

  final bool biometricEnabled;
  final VoidCallback? onBiometric;

  final FeedbackService feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dots(filled: entered.length, hasError: errorText != null),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 20,
          child: errorText == null
              ? null
              : Text(
                  errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !enabled,
            child: _Pad(
              onDigit: (d) {
                feedback.tick();
                onDigit(d);
              },
              onBackspace: () {
                feedback.tick();
                onBackspace();
              },
              biometricEnabled: biometricEnabled,
              onBiometric: onBiometric,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.hasError});

  final int filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kPinLength; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled
                    ? (hasError ? AppColors.danger : AppColors.accent)
                    : Colors.transparent,
                border: Border.all(
                  color: hasError
                      ? AppColors.danger
                      : theme.colorScheme.outline,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.onDigit,
    required this.onBackspace,
    required this.biometricEnabled,
    required this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool biometricEnabled;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              children: [
                for (final d in row)
                  Expanded(
                    child: _PinKey(label: d, onTap: () => onDigit(d)),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: biometricEnabled && onBiometric != null
                    ? _PinKey(
                        icon: Icons.fingerprint,
                        onTap: onBiometric,
                        semanticLabel: 'Ontgrendel met biometrie',
                      )
                    : const SizedBox(height: 72),
              ),
              Expanded(child: _PinKey(label: '0', onTap: () => onDigit('0'))),
              Expanded(
                child: _PinKey(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                  semanticLabel: 'Wis cijfer',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    this.label,
    this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: SizedBox(
        height: 72,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 26, color: theme.colorScheme.onSurface)
                : Text(
                    label!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
