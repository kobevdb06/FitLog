import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import 'morning_providers.dart';

/// The report made on its own every morning, and at what time.
class MorningReportSettings extends ConsumerWidget {
  const MorningReportSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final on = ref.watch(morningReportEnabledProvider);
    final minutes = ref.watch(morningReportMinutesProvider);
    final state = ref.watch(morningControllerProvider);
    final app = ref.watch(appControllerProvider);
    final pin = app is AppReady && app.security.mode == LockMode.pin;
    final clock =
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';

    Future<void> pickTime() async {
      final picked = await showDayTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        helpText: 'Wanneer wil je je rapport?',
      );
      if (picked == null) return;
      await ref
          .read(morningControllerProvider.notifier)
          .setMinutes(picked.hour * 60 + picked.minute);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.wb_twilight_outlined),
          title: const Text('Elke ochtend een rapport'),
          subtitle: const Text(
            'Op het uur hieronder haalt FitLog zelf je nacht op, stelt het '
            'rapport op en stuurt je een melding. Het rapport staat ook onder '
            'Herstel.',
          ),
          value: on,
          onChanged: (value) {
            final morning = ref.read(morningControllerProvider.notifier);
            if (value) {
              morning.enable();
            } else {
              morning.disable();
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text('Om $clock'),
          subtitle: const Text('Tik om het uur te kiezen'),
          enabled: on,
          onTap: on ? pickTime : null,
        ),
        if (on && pin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Je gebruikt een pincode. Dan blijft je logboek dicht tot jij '
              'het opent: om $clock krijg je een melding, en het rapport staat '
              'klaar zodra je FitLog ontgrendelt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (state.notice ?? state.error case final message?)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: InfoBanner(
              message: message,
              icon: state.error == null
                  ? Icons.info_outline
                  : Icons.error_outline,
            ),
          ),
      ],
    );
  }
}
