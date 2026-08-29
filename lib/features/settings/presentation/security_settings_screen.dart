import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/security/key_material.dart';
import '../../../core/security/recovery_phrase.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../lock/presentation/pin_pad.dart';

/// PIN, biometrics, auto-lock and the recovery phrase.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  SecurityStatus? _status;
  bool _biometricAvailable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await ref.read(keyManagerProvider).status();
    final available = await ref.read(biometricServiceProvider).isAvailable();
    if (!mounted) return;
    setState(() {
      _status = status;
      _biometricAvailable = available;
    });
  }

  Uint8List? get _dek =>
      ref.read(appControllerProvider.notifier).currentDek;

  // --- Actions --------------------------------------------------------------

  Future<void> _enablePin() async {
    final dek = _dek;
    if (dek == null) return;

    final pin = await _askForNewPin();
    if (pin == null) return;

    setState(() => _busy = true);
    final manager = ref.read(keyManagerProvider);
    await manager.setPin(
      dek: dek,
      pin: pin,
      keepDirectKey: _status?.biometricEnabled ?? false,
    );
    await _refresh();
    if (mounted) {
      setState(() => _busy = false);
      showSnack(context, 'Pincode ingesteld');
    }
  }

  Future<void> _disablePin() async {
    final dek = _dek;
    if (dek == null) return;

    final ok = await confirm(
      context,
      title: 'Pincode uitzetten?',
      message:
          'FitLog opent dan meteen. Je gegevens blijven versleuteld, maar '
          'iedereen met je ontgrendelde toestel kan ze lezen.',
      confirmLabel: 'Uitzetten',
      destructive: true,
    );
    if (!ok) return;

    await ref.read(keyManagerProvider).removePin(dek);
    await _refresh();
    if (mounted) showSnack(context, 'Pincode uitgezet');
  }

  Future<void> _changePin() async {
    final current = await _askForPin('Huidige pincode');
    if (current == null) return;

    setState(() => _busy = true);
    try {
      final next = await _askForNewPin();
      if (next == null) {
        setState(() => _busy = false);
        return;
      }
      await ref
          .read(keyManagerProvider)
          .changePin(currentPin: current, newPin: next);
      await _refresh();
      if (mounted) showSnack(context, 'Pincode gewijzigd');
    } on InvalidSecretException {
      if (mounted) {
        showSnack(context, 'Die pincode klopt niet.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    final dek = _dek;
    if (dek == null) return;
    final manager = ref.read(keyManagerProvider);

    if (enabled) {
      final ok = await ref
          .read(biometricServiceProvider)
          .authenticate(reason: 'Bevestig om biometrie aan te zetten');
      if (!ok) return;
      await manager.enableBiometrics(dek);
    } else {
      await manager.disableBiometrics();
    }
    await _refresh();
  }

  Future<void> _showRecoveryPhrase() async {
    final current = _status?.mode == LockMode.pin
        ? await _askForPin('Pincode ter controle')
        : '';
    if (current == null) return;

    final manager = ref.read(keyManagerProvider);
    Uint8List dek;
    if (_status?.mode == LockMode.pin) {
      try {
        dek = await manager.unlockWithPin(current);
      } on InvalidSecretException {
        if (mounted) {
          showSnack(context, 'Die pincode klopt niet.', isError: true);
        }
        return;
      }
    } else {
      final stored = _dek ?? await manager.readDirectKey();
      if (stored == null) return;
      dek = stored;
    }

    final phrase = await manager.readRecoveryPhrase(dek);
    if (!mounted) return;
    if (phrase == null) {
      showSnack(
        context,
        'Er is geen herstelzin bewaard op dit toestel.',
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Je herstelzin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deze twaalf woorden zijn de enige manier om je gegevens terug '
              'te krijgen als je je pincode vergeet. Wij kunnen ze niet voor '
              'je opzoeken.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              recoveryWords(phrase)
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: phrase));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Kopiëren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  // --- PIN entry helpers ----------------------------------------------------

  Future<String?> _askForPin(String title) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _PinEntryPage(title: title),
      ),
    );
  }

  Future<String?> _askForNewPin() async {
    final first = await _askForPin('Kies een nieuwe pincode');
    if (first == null) return null;
    if (!mounted) return null;
    final second = await _askForPin('Herhaal de pincode');
    if (second == null) return null;
    if (first != second) {
      if (mounted) {
        showSnack(context, 'De pincodes zijn niet gelijk.', isError: true);
      }
      return null;
    }
    return first;
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final settings = ref.watch(settingsProvider).value;

    if (status == null || settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasPin = status.mode == LockMode.pin;

    return Scaffold(
      appBar: AppBar(title: const Text('Beveiliging')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          children: [
            const SectionHeader('Toegang'),
            SwitchListTile(
              title: const Text('Pincode'),
              subtitle: Text(
                hasPin
                    ? 'Vereist bij elke start en na auto-vergrendelen'
                    : 'FitLog opent nu meteen',
              ),
              value: hasPin,
              onChanged: (value) => value ? _enablePin() : _disablePin(),
            ),
            if (hasPin)
              ListTile(
                title: const Text('Pincode wijzigen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePin,
              ),
            SwitchListTile(
              title: const Text('Biometrie'),
              subtitle: Text(
                _biometricAvailable
                    ? 'Ontgrendel met je vingerafdruk of gezicht'
                    : 'Dit toestel heeft geen ingestelde biometrie',
              ),
              value: status.biometricEnabled,
              onChanged: _biometricAvailable ? _toggleBiometrics : null,
            ),
            const SectionHeader('Auto-vergrendelen'),
            for (final option in const [
              (0, 'Meteen'),
              (60, 'Na 1 minuut'),
              (300, 'Na 5 minuten'),
              (900, 'Na 15 minuten'),
              (-1, 'Nooit'),
            ])
              RadioListTile<int>(
                value: option.$1,
                // ignore: deprecated_member_use
                groupValue: settings.autoLockSeconds,
                title: Text(option.$2),
                // ignore: deprecated_member_use
                onChanged: hasPin
                    ? (value) async {
                        if (value == null) return;
                        await ref
                            .read(databaseProvider)
                            .settingsDao
                            .updateSettings(
                              AppSettingsTableCompanion(
                                autoLockSeconds: Value(value),
                              ),
                            );
                        ref
                            .read(appControllerProvider.notifier)
                            .setAutoLockSeconds(value);
                      }
                    : null,
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: InfoBanner(
                icon: Icons.timer_outlined,
                message: hasPin
                    ? 'Tijdens een lopende workout vergrendelt FitLog nooit.'
                    : 'Auto-vergrendelen werkt alleen met een pincode.',
              ),
            ),
            const SectionHeader('Herstel'),
            ListTile(
              title: const Text('Herstelzin tonen'),
              subtitle: const Text('Achter een pincodecontrole'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showRecoveryPhrase,
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: InfoBanner(
                icon: Icons.shield_outlined,
                message:
                    'Je database is versleuteld met SQLCipher. De sleutel '
                    'staat in de Keystore van je toestel, verpakt met '
                    'Argon2id. Er is geen server en geen kopie elders.',
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// A full-screen PIN prompt that returns the six digits.
class _PinEntryPage extends StatefulWidget {
  const _PinEntryPage({required this.title});

  final String title;

  @override
  State<_PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<_PinEntryPage> {
  String _entered = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: PinPad(
              entered: _entered,
              onDigit: (digit) {
                if (_entered.length >= kPinLength) return;
                setState(() => _entered += digit);
                if (_entered.length == kPinLength) {
                  Navigator.of(context).pop(_entered);
                }
              },
              onBackspace: () => setState(
                () => _entered = _entered.isEmpty
                    ? _entered
                    : _entered.substring(0, _entered.length - 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
