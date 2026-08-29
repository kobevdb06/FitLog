import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/security/recovery_phrase.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';

/// Unlocking with the twelve word phrase when the PIN is gone.
class RecoveryUnlockScreen extends ConsumerStatefulWidget {
  const RecoveryUnlockScreen({super.key});

  @override
  ConsumerState<RecoveryUnlockScreen> createState() =>
      _RecoveryUnlockScreenState();
}

class _RecoveryUnlockScreenState extends ConsumerState<RecoveryUnlockScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
        .unlockWithRecoveryPhrase(phrase);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Herstelzin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Typ je twaalf woorden in de juiste volgorde, gescheiden door '
              'spaties.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
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
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Bezig...' : 'Ontgrendelen'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const InfoBanner(
              message:
                  'De herstelzin staat alleen op papier bij jou. FitLog heeft '
                  'geen server en kan hem niet voor je opzoeken.',
            ),
          ],
        ),
      ),
    );
  }
}
