import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/app/app_state.dart';
import '../../../core/security/key_manager.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import 'pin_pad.dart';

/// Unlocking the local database. There is no server and no account: the PIN
/// only ever unwraps the key that is already on this device.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;
  bool _busy = false;

  Duration _remainingLockout = Duration.zero;
  Timer? _lockoutTicker;
  bool _triedBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLockout();
      _maybePromptBiometrics();
    });
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  SecurityStatus? get _security {
    final state = ref.read(appControllerProvider);
    return state is AppLocked ? state.security : null;
  }

  void _syncLockout() {
    final security = _security;
    if (security == null) return;
    final remaining = security.remainingLockoutAt();
    if (remaining == Duration.zero) {
      setState(() => _remainingLockout = Duration.zero);
      return;
    }
    setState(() => _remainingLockout = remaining);
    _lockoutTicker?.cancel();
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = security.remainingLockoutAt();
      if (!mounted) return timer.cancel();
      setState(() => _remainingLockout = left);
      if (left == Duration.zero) timer.cancel();
    });
  }

  Future<void> _maybePromptBiometrics() async {
    if (_triedBiometrics) return;
    final security = _security;
    if (security == null || !security.biometricEnabled) return;
    _triedBiometrics = true;
    await _unlockWithBiometrics(silent: true);
  }

  Future<void> _unlockWithBiometrics({bool silent = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await ref
        .read(appControllerProvider.notifier)
        .unlockWithBiometrics();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!silent) _error = error;
    });
  }

  void _onDigit(String digit) {
    if (_busy || _remainingLockout > Duration.zero) return;
    if (_entered.length >= kPinLength) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == kPinLength) {
      unawaited(_submit());
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final error = await ref
        .read(appControllerProvider.notifier)
        .unlockWithPin(_entered);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error != null) _entered = '';
    });
    if (error != null) _syncLockout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final security = ref.watch(appControllerProvider) is AppLocked
        ? (ref.watch(appControllerProvider) as AppLocked).security
        : null;
    final locked = _remainingLockout > Duration.zero;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                const FitLogLogo(),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Voer je pincode in',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                PinPad(
                  entered: _entered,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  enabled: !_busy && !locked,
                  errorText: locked
                      ? 'Nog ${_remainingLockout.inSeconds} seconden wachten'
                      : _error,
                  biometricEnabled: security?.biometricEnabled ?? false,
                  onBiometric: _unlockWithBiometrics,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (security?.hasRecoveryPhrase ?? false)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.push(Routes.recovery),
                    child: const Text('Pincode vergeten'),
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
