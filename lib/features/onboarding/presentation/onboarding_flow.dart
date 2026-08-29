import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/calc/units.dart';
import '../../../core/db/database.dart';
import '../../../core/security/recovery_phrase.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../lock/presentation/pin_pad.dart';

enum _Step {
  welcome,
  securityChoice,
  pinEnter,
  pinConfirm,
  recoveryShow,
  recoveryVerify,
  biometric,
  profile,
  finishing,
}

/// First start: explain, protect the database, hand over the recovery phrase,
/// then collect the little bit of profile the app actually uses.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Step _step = _Step.welcome;

  late final Uint8List _dek;
  late final String _recoveryPhrase;
  late final List<int> _verifyIndices;

  bool _usePin = true;
  String _pin = '';
  String _pinConfirm = '';
  String? _pinError;

  final Map<int, TextEditingController> _verifyControllers = {};
  String? _verifyError;

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  // Profile
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime? _birthDate;
  Sex? _sex;
  WeightUnit _weightUnit = WeightUnit.kg;
  LengthUnit _lengthUnit = LengthUnit.cm;

  String? _fatalError;

  @override
  void initState() {
    super.initState();
    _dek = ref.read(keyManagerProvider).createDek();
    _recoveryPhrase = generateRecoveryPhrase();
    _verifyIndices = verificationIndices(kRecoveryWordCount);
    for (final i in _verifyIndices) {
      _verifyControllers[i] = TextEditingController();
    }
    _checkBiometrics();
  }

  @override
  void dispose() {
    for (final c in _verifyControllers.values) {
      c.dispose();
    }
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await ref.read(biometricServiceProvider).isAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  // --- Navigation -----------------------------------------------------------

  void _go(_Step step) => setState(() => _step = step);

  void _back() {
    switch (_step) {
      case _Step.securityChoice:
        _go(_Step.welcome);
      case _Step.pinEnter:
        _go(_Step.securityChoice);
      case _Step.pinConfirm:
        setState(() {
          _pinConfirm = '';
          _pinError = null;
          _step = _Step.pinEnter;
        });
      case _Step.recoveryShow:
        _go(_Step.securityChoice);
      case _Step.recoveryVerify:
        _go(_Step.recoveryShow);
      case _Step.biometric:
        _go(_Step.recoveryVerify);
      case _Step.profile:
        _go(_biometricAvailable ? _Step.biometric : _Step.recoveryVerify);
      case _Step.welcome:
      case _Step.finishing:
        break;
    }
  }

  void _afterRecovery() {
    _go(_biometricAvailable ? _Step.biometric : _Step.profile);
  }

  // --- Finishing ------------------------------------------------------------

  Future<void> _finish() async {
    _go(_Step.finishing);
    try {
      final manager = ref.read(keyManagerProvider);

      // The recovery phrase always exists: it is also the key for encrypted
      // backups, which have to be restorable on another device.
      await manager.setRecoveryPhrase(dek: _dek, phrase: _recoveryPhrase);

      if (_usePin) {
        await manager.setPin(
          dek: _dek,
          pin: _pin,
          keepDirectKey: _biometricEnabled,
        );
        if (_biometricEnabled) await manager.enableBiometrics(_dek);
      } else {
        await manager.setDirectKey(_dek);
        if (_biometricEnabled) await manager.enableBiometrics(_dek);
      }

      await ref.read(appControllerProvider.notifier).completeSetupWith(_dek);
      await _persistProfile();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _fatalError = '$error';
          _step = _Step.profile;
        });
      }
    }
  }

  Future<void> _persistProfile() async {
    final controller = ref.read(appControllerProvider.notifier);
    final db = controller.databaseOrNull;
    if (db == null) return;

    await db.settingsDao.updateSettings(
      AppSettingsTableCompanion(
        unitWeight: Value(_weightUnit.wire),
        unitLength: Value(_lengthUnit.wire),
        onboardingDone: const Value(true),
      ),
    );

    final height = _parseNumber(_heightController.text);
    await db.settingsDao.upsertProfile(
      displayName: Value(
        _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      ),
      birthDate: Value(_birthDate?.millisecondsSinceEpoch),
      sex: Value(_sex?.wire),
      heightCm: Value(
        height == null
            ? null
            : (_lengthUnit == LengthUnit.cm ? height : inchToCm(height)),
      ),
    );

    final weight = _parseNumber(_weightController.text);
    if (weight != null) {
      await db.recordsDao.addMeasurement(
        type: MeasurementType.weight,
        value: _weightUnit == WeightUnit.kg ? weight : lbToKg(weight),
        measuredAt: DateTime.now(),
      );
    }
  }

  static double? _parseNumber(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return value;
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: _step == _Step.welcome || _step == _Step.finishing
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _back,
                ),
                title: Text(_titleFor(_step)),
              ),
        body: SafeArea(child: _bodyFor(_step)),
      ),
    );
  }

  String _titleFor(_Step step) => switch (step) {
    _Step.securityChoice => 'Beveiliging',
    _Step.pinEnter => 'Pincode instellen',
    _Step.pinConfirm => 'Pincode herhalen',
    _Step.recoveryShow => 'Herstelcode',
    _Step.recoveryVerify => 'Controle',
    _Step.biometric => 'Biometrie',
    _Step.profile => 'Jouw profiel',
    _ => '',
  };

  Widget _bodyFor(_Step step) => switch (step) {
    _Step.welcome => _WelcomeStep(onNext: () => _go(_Step.securityChoice)),
    _Step.securityChoice => _SecurityChoiceStep(
      usePin: _usePin,
      onChanged: (value) => setState(() => _usePin = value),
      onNext: () => _go(_usePin ? _Step.pinEnter : _Step.recoveryShow),
    ),
    _Step.pinEnter => _PinStep(
      key: const ValueKey('pin-enter'),
      title: 'Kies een pincode van zes cijfers',
      subtitle:
          'Je hebt hem nodig telkens als je FitLog opent. Hij staat alleen op '
          'dit toestel.',
      entered: _pin,
      errorText: _pinError,
      onDigit: (d) => setState(() {
        if (_pin.length < kPinLength) _pin += d;
        _pinError = null;
        if (_pin.length == kPinLength) _step = _Step.pinConfirm;
      }),
      onBackspace: () => setState(
        () => _pin = _pin.isEmpty ? _pin : _pin.substring(0, _pin.length - 1),
      ),
    ),
    _Step.pinConfirm => _PinStep(
      key: const ValueKey('pin-confirm'),
      title: 'Typ dezelfde pincode nog eens',
      subtitle: 'Zo weten we zeker dat je hem juist hebt onthouden.',
      entered: _pinConfirm,
      errorText: _pinError,
      onDigit: (d) => setState(() {
        if (_pinConfirm.length < kPinLength) _pinConfirm += d;
        _pinError = null;
        if (_pinConfirm.length == kPinLength) {
          if (_pinConfirm == _pin) {
            _step = _Step.recoveryShow;
          } else {
            _pinError = 'De pincodes zijn niet gelijk. Probeer opnieuw.';
            _pin = '';
            _pinConfirm = '';
            _step = _Step.pinEnter;
          }
        }
      }),
      onBackspace: () => setState(
        () => _pinConfirm = _pinConfirm.isEmpty
            ? _pinConfirm
            : _pinConfirm.substring(0, _pinConfirm.length - 1),
      ),
    ),
    _Step.recoveryShow => _RecoveryShowStep(
      phrase: _recoveryPhrase,
      onNext: () => _go(_Step.recoveryVerify),
    ),
    _Step.recoveryVerify => _RecoveryVerifyStep(
      indices: _verifyIndices,
      controllers: _verifyControllers,
      errorText: _verifyError,
      onVerify: () {
        final answers = {
          for (final entry in _verifyControllers.entries)
            entry.key: entry.value.text,
        };
        final ok = verifyRecoveryWords(
          phrase: _recoveryPhrase,
          answers: answers,
        );
        if (ok) {
          setState(() => _verifyError = null);
          _afterRecovery();
        } else {
          setState(
            () => _verifyError =
                'Dat klopt nog niet. Kijk je briefje er even bij.',
          );
        }
      },
    ),
    _Step.biometric => _BiometricStep(
      enabled: _biometricEnabled,
      onChanged: (value) => setState(() => _biometricEnabled = value),
      onNext: () => _go(_Step.profile),
    ),
    _Step.profile => _ProfileStep(
      nameController: _nameController,
      heightController: _heightController,
      weightController: _weightController,
      birthDate: _birthDate,
      sex: _sex,
      weightUnit: _weightUnit,
      lengthUnit: _lengthUnit,
      errorText: _fatalError,
      onBirthDate: (value) => setState(() => _birthDate = value),
      onSex: (value) => setState(() => _sex = value),
      onWeightUnit: (value) => setState(() => _weightUnit = value),
      onLengthUnit: (value) => setState(() => _lengthUnit = value),
      onFinish: _finish,
    ),
    _Step.finishing => const AppLoadingScreen(message: 'Even klaarzetten...'),
  };
}

// --- Steps ------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(child: FitLogLogo(size: 80)),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Log je krachttraining.',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Maak routines, vink je sets af tijdens het trainen en zie je '
            'vooruitgang terug.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          const InfoBanner(
            icon: Icons.shield_outlined,
            message:
                'Je gegevens blijven op dit toestel en worden nergens naartoe '
                'gestuurd. FitLog heeft geen account, geen server en geen '
                'internettoegang.',
          ),
          const Spacer(),
          FilledButton(onPressed: onNext, child: const Text('Beginnen')),
        ],
      ),
    );
  }
}

class _SecurityChoiceStep extends StatelessWidget {
  const _SecurityChoiceStep({
    required this.usePin,
    required this.onChanged,
    required this.onNext,
  });

  final bool usePin;
  final ValueChanged<bool> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hoe wil je FitLog afschermen?',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Je gegevens staan altijd versleuteld op dit toestel. De pincode '
            'bepaalt of iemand die je telefoon openpakt er ook bij kan.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ChoiceCard(
            selected: usePin,
            onTap: () => onChanged(true),
            icon: Icons.lock_outline,
            title: 'Pincode instellen',
            subtitle:
                'Aanbevolen. Zes cijfers bij elke start, met biometrie als '
                'snelkoppeling.',
          ),
          const SizedBox(height: AppSpacing.md),
          _ChoiceCard(
            selected: !usePin,
            onTap: () => onChanged(false),
            icon: Icons.lock_open_outlined,
            title: 'Overslaan',
            subtitle:
                'FitLog opent meteen. De sleutel blijft beschermd door de '
                'Keystore van je toestel, maar wie je ontgrendelde telefoon '
                'vasthoudt, ziet je trainingen. Je kunt dit later aanzetten.',
          ),
          const Spacer(),
          FilledButton(onPressed: onNext, child: const Text('Doorgaan')),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.accent : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: selected
                ? AppColors.accent
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: selected
                ? AppColors.accent
                : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _PinStep extends StatelessWidget {
  const _PinStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entered,
    required this.onDigit,
    required this.onBackspace,
    this.errorText,
  });

  final String title;
  final String subtitle;
  final String entered;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PinPad(
            entered: entered,
            onDigit: onDigit,
            onBackspace: onBackspace,
            errorText: errorText,
          ),
        ],
      ),
    );
  }
}

class _RecoveryShowStep extends StatelessWidget {
  const _RecoveryShowStep({required this.phrase, required this.onNext});

  final String phrase;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = recoveryWords(phrase);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Schrijf deze twaalf woorden op papier.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Deze 12 woorden zijn de enige manier om je gegevens terug te '
                'krijgen als je je pincode vergeet. Ze staan nergens anders. '
                'Wij kunnen ze niet voor je opzoeken. Schrijf ze op papier.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: words.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 4.2,
                    ),
                itemBuilder: (context, index) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          words[index],
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: phrase));
                  if (context.mounted) {
                    showSnack(context, 'Herstelzin gekopieerd');
                  }
                },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Kopieer naar klembord'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: const Text('Ik heb ze opgeschreven'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecoveryVerifyStep extends StatelessWidget {
  const _RecoveryVerifyStep({
    required this.indices,
    required this.controllers,
    required this.onVerify,
    this.errorText,
  });

  final List<int> indices;
  final Map<int, TextEditingController> controllers;
  final VoidCallback onVerify;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Even controleren',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Typ deze drie woorden over van je briefje.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final index in indices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: TextField(
                    controller: controllers[index],
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: 'Woord ${index + 1}',
                    ),
                  ),
                ),
              if (errorText != null)
                InfoBanner(
                  message: errorText!,
                  icon: Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onVerify,
              child: const Text('Controleren'),
            ),
          ),
        ),
      ],
    );
  }
}

class _BiometricStep extends StatelessWidget {
  const _BiometricStep({
    required this.enabled,
    required this.onChanged,
    required this.onNext,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sneller ontgrendelen',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Dit toestel ondersteunt biometrie. Zet je dat aan, dan volstaat '
            'je vingerafdruk of gezicht om FitLog te openen.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: onChanged,
              title: const Text('Biometrie gebruiken'),
              subtitle: const Text('Je pincode blijft altijd werken.'),
              secondary: const Icon(Icons.fingerprint),
            ),
          ),
          const Spacer(),
          FilledButton(onPressed: onNext, child: const Text('Doorgaan')),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.nameController,
    required this.heightController,
    required this.weightController,
    required this.birthDate,
    required this.sex,
    required this.weightUnit,
    required this.lengthUnit,
    required this.onBirthDate,
    required this.onSex,
    required this.onWeightUnit,
    required this.onLengthUnit,
    required this.onFinish,
    this.errorText,
  });

  final TextEditingController nameController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final DateTime? birthDate;
  final Sex? sex;
  final WeightUnit weightUnit;
  final LengthUnit lengthUnit;
  final ValueChanged<DateTime?> onBirthDate;
  final ValueChanged<Sex?> onSex;
  final ValueChanged<WeightUnit> onWeightUnit;
  final ValueChanged<LengthUnit> onLengthUnit;
  final VoidCallback onFinish;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Alleen de eenheden zijn verplicht. De rest mag je overslaan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader('Eenheden', padding: EdgeInsets.zero),
              SegmentedButton<WeightUnit>(
                segments: const [
                  ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                  ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                ],
                selected: {weightUnit},
                onSelectionChanged: (s) => onWeightUnit(s.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<LengthUnit>(
                segments: const [
                  ButtonSegment(value: LengthUnit.cm, label: Text('cm')),
                  ButtonSegment(value: LengthUnit.inch, label: Text('inch')),
                ],
                selected: {lengthUnit},
                onSelectionChanged: (s) => onLengthUnit(s.first),
              ),
              const SectionHeader('Over jou', padding: EdgeInsets.zero),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Naam'),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: birthDate ?? DateTime(now.year - 30),
                    firstDate: DateTime(now.year - 100),
                    lastDate: now,
                    helpText: 'Geboortedatum',
                  );
                  if (picked != null) onBirthDate(picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Geboortedatum',
                  ),
                  child: Text(
                    birthDate == null
                        ? 'Niet ingevuld'
                        : '${birthDate!.day}-${birthDate!.month}-'
                              '${birthDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<Sex>(
                initialValue: sex,
                decoration: const InputDecoration(labelText: 'Geslacht'),
                items: [
                  for (final s in Sex.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: onSex,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Lengte',
                        suffixText: lengthUnit.label,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Startgewicht',
                        suffixText: weightUnit.label,
                      ),
                    ),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InfoBanner(
                  message: errorText!,
                  icon: Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onFinish,
              child: const Text('Klaar'),
            ),
          ),
        ),
      ],
    );
  }
}
