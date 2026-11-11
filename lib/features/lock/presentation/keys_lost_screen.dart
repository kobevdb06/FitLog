import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/security/recovery_phrase.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import 'start_over.dart';
import '../../../core/security/screen_guard.dart';

/// The keys are gone, or Android will not hand them over, while the data is
/// still on this device. The twelve words open it again (DECISIONS 241).
///
/// This used to be the first screen of a new install: the app took itself
/// for new, and starting over made a key that never opened the old data.
class KeysLostScreen extends ConsumerStatefulWidget {
  const KeysLostScreen({super.key});

  @override
  ConsumerState<KeysLostScreen> createState() => _KeysLostScreenState();
}

class _KeysLostScreenState extends ConsumerState<KeysLostScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final phrase = normalizeRecoveryPhrase(_controller.text);
    if (!isValidRecoveryPhrase(phrase)) {
      setState(
        () => _error =
            'Dat zijn geen twaalf geldige woorden. Controleer de spelling.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(appControllerProvider.notifier)
        .recoverWithPhrase(phrase);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(appControllerProvider);
    final unreadable = state is AppNeedsRecovery && state.unreadable;
    final canUsePhrase = state is! AppNeedsRecovery || state.canUsePhrase;

    return SecureScreen(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              Icon(
                Icons.key_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                unreadable
                    ? 'Android geeft je sleutel niet vrij'
                    : 'Je sleutel is weg, je gegevens niet',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                unreadable
                    ? 'Je gegevens staan nog op dit toestel, maar Android kan '
                          'de sleutel ervan nu niet lezen. Probeer het opnieuw, '
                          'of open ze met je herstelzin van twaalf woorden.'
                    : 'Android heeft de sleutels van FitLog gewist, maar je '
                          'gegevens staan nog op dit toestel. Met je herstelzin '
                          'van twaalf woorden open je ze weer.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (canUsePhrase) ...[
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Herstelzin',
                    hintText: 'woord1 woord2 woord3 ...',
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InfoBanner(
                    message: _error!,
                    icon: Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _open,
                  child: Text(_busy ? 'Bezig...' : 'Openen met herstelzin'),
                ),
                const SizedBox(height: AppSpacing.md),
                const InfoBanner(
                  message:
                      'Daarna staat er geen pincode op FitLog. Stel er opnieuw '
                      'een in bij Profiel, Beveiliging.',
                ),
              ] else
                const InfoBanner(
                  icon: Icons.info_outline,
                  message:
                      'Op dit toestel staat geen kopie van de sleutel die je '
                      'herstelzin kan openen. Heb je een back-up (een '
                      '.fitlog-bestand), begin dan opnieuw en zet ze terug bij '
                      'Profiel, Back-up.',
                ),
              if (unreadable) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => ref
                            .read(appControllerProvider.notifier)
                            .initialise(),
                  child: const Text('Opnieuw proberen'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: _busy ? null : () => confirmStartOver(context, ref),
                child: const Text(
                  'Opnieuw beginnen',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The keys are here, the training data is not: said, rather than an empty
/// database made without a word (DECISIONS 241).
class DatabaseMissingScreen extends ConsumerWidget {
  const DatabaseMissingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(
              Icons.folder_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Je gegevens staan niet meer op dit toestel',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'De sleutel van FitLog is er nog, maar het bestand met je '
              'trainingen niet. Dat kan gebeuren als het terugzetten van een '
              'back-up halverwege stopte. Ga verder met lege gegevens en zet '
              'daarna je back-up terug bij Profiel, Back-up.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () =>
                  ref.read(appControllerProvider.notifier).startEmpty(),
              child: const Text('Verder met lege gegevens'),
            ),
          ],
        ),
      ),
    );
  }
}
