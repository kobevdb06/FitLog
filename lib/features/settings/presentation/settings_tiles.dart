import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/util/notification_service.dart';
import '../../../core/widgets/common.dart';

/// A setting whose choices sit under its name instead of beside it.
///
/// A ListTile hands its trailing widget as much width as it asks for and
/// squeezes the title into whatever is left. Six segments leave so little that
/// the title wrapped to one letter per line - a column of single characters
/// down the screen.
///
/// Putting the choices on their own line means no number of options, no font
/// size and no translation can do that again.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final List<T> values;
  final String Function(T) label;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // The full width, shared evenly: every choice in sight on a
          // narrow phone with a large font. It used to scroll sideways
          // there, and a row with its last choice off the edge looks
          // broken rather than scrollable.
          SegmentedButton<T>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              for (final value in values)
                ButtonSegment(value: value, label: Text(label(value))),
            ],
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

/// Says so when notifications are switched off for the app.
///
/// Without them the rest timer stays silent when the phone is away and no
/// standing notification appears during a workout - and nothing else in the
/// app would ever mention it, which is how it went unnoticed for a fortnight.
class NotificationsOffBanner extends StatelessWidget {
  const NotificationsOffBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NotificationService.instance.isAllowed,
      builder: (context, snapshot) {
        if (snapshot.data != false) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: InfoBanner(
            icon: Icons.notifications_off_outlined,
            message:
                'Meldingen staan uit voor FitLog. De rusttimer laat dan niets '
                'zien als je je telefoon weglegt, en tijdens een workout komt '
                'er geen melding met je oefening en je set. Aan te zetten bij '
                'de app-instellingen van je toestel.',
          ),
        );
      },
    );
  }
}
