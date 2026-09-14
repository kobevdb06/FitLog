/// Where the coach is switched on, and where it is switched off again.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../data/ai_client.dart';
import 'chat_providers.dart';

class CoachSettingsScreen extends ConsumerStatefulWidget {
  const CoachSettingsScreen({super.key});

  @override
  ConsumerState<CoachSettingsScreen> createState() =>
      _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends ConsumerState<CoachSettingsScreen> {
  bool _testing = false;
  String? _result;

  /// A key is shown by its ends only: enough to recognise which one it is,
  /// never enough to use over someone's shoulder.
  String _masked(String key) => key.length <= 12
      ? '••••'
      : '${key.substring(0, 8)}…${key.substring(key.length - 4)}';

  Future<void> _enterKey() async {
    final key = await promptForText(
      context,
      title: 'API-sleutel',
      hintText: 'sk-ant-...',
      confirmLabel: 'Bewaren',
    );
    if (key == null || !mounted) return;

    await ref.read(databaseProvider).settingsDao.setApiKey(key);
    if (mounted) setState(() => _result = null);
  }

  Future<void> _removeKey() async {
    final ok = await confirm(
      context,
      title: 'Sleutel verwijderen?',
      message:
          'De coach gaat uit en FitLog maakt daarna geen enkele verbinding '
          'meer. Je gesprekken blijven staan.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok || !mounted) return;

    await ref.read(databaseProvider).settingsDao.setApiKey(null);
    if (mounted) setState(() => _result = null);
  }

  Future<void> _test() async {
    final key = ref.read(coachApiKeyProvider);
    if (key == null) return;

    setState(() {
      _testing = true;
      _result = null;
    });
    final failure = await ref
        .read(coachControllerProvider.notifier)
        .testKey(key);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = failure ?? 'De sleutel werkt.';
    });
  }

  /// Sets the service straight when the guess is wrong, or hands it back to
  /// the guess.
  Future<void> _pickProvider() async {
    final guessed = ref.read(coachProviderIsGuessedProvider);
    final current = ref.read(coachProviderProvider);

    final picked = await showAppSheet<String>(
      context: context,
      title: 'Van welke dienst is je sleutel?',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Automatisch'),
            subtitle: const Text('Afgeleid uit de sleutel zelf'),
            selected: guessed,
            onTap: () => Navigator.of(context).pop('auto'),
          ),
          const Divider(height: 1),
          for (final provider in CoachProvider.values)
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(provider.label),
              selected: !guessed && provider == current,
              onTap: () => Navigator.of(context).pop(provider.wire),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          AppSettingsTableCompanion(
            chatProvider: Value(picked == 'auto' ? null : picked),
          ),
        );
    if (mounted) setState(() => _result = null);
  }

  Future<void> _pickModel() async {
    final current = ref.read(coachModelProvider);
    final provider = ref.read(coachProviderProvider);
    final picked = await showAppSheet<CoachModel>(
      context: context,
      title: 'Welk model van ${provider.label}?',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final model in CoachModel.forProvider(provider))
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(model.label),
              subtitle: Text(model.description),
              selected: model == current,
              onTap: () => Navigator.of(context).pop(model),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          AppSettingsTableCompanion(chatModel: Value(picked.wire)),
        );
  }

  Future<void> _clearThreads() async {
    final ok = await confirm(
      context,
      title: 'Alle gesprekken wissen?',
      message: 'Elke vraag en elk antwoord verdwijnt van dit toestel.',
      confirmLabel: 'Wissen',
      destructive: true,
    );
    if (!ok || !mounted) return;

    await ref.read(databaseProvider).chatDao.deleteAllThreads();
    if (mounted) showSnack(context, 'Gesprekken gewist.');
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(coachApiKeyProvider);
    final model = ref.watch(coachModelProvider);
    final provider = ref.watch(coachProviderProvider);
    final guessed = ref.watch(coachProviderIsGuessedProvider);
    final threads = ref.watch(chatThreadsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('AI-coach')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: InfoBanner(
              icon: Icons.lock_outline,
              message:
                  'Dit is het enige deel van FitLog dat internet gebruikt, en '
                  'het werkt alleen met een sleutel van jezelf. Je vraag gaat '
                  'naar de dienst van die sleutel, samen met wat de coach in '
                  'je logboek opvraagt om te antwoorden; onder elk antwoord '
                  'staat wat dat was. Zonder sleutel maakt de app geen '
                  'verbinding.',
            ),
          ),
          const SectionHeader('Sleutel'),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(key == null ? 'Nog geen sleutel' : _masked(key)),
            subtitle: Text(
              key == null
                  ? 'Een sleutel van Google AI Studio (gratis laag) of van '
                        'Anthropic. Plak hem hier; de app raadt welke van de '
                        'twee het is.'
                  : 'Bewaard in je versleutelde database, achter je pincode.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _enterKey,
          ),
          if (key != null)
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(provider.label),
              subtitle: Text(
                guessed
                    ? 'Afgeleid uit je sleutel. Klopt dat niet, tik hier.'
                    : 'Door jou gekozen.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickProvider,
            ),
          if (key != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Sleutel testen'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _removeKey,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Verwijderen'),
                  ),
                ],
              ),
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Text(
                  _result!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SectionHeader('Model'),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(model.label),
              subtitle: Text(model.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickModel,
            ),
            const SectionHeader('Gesprekken'),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(
                threads.isEmpty
                    ? 'Nog geen gesprekken'
                    : '${threads.length} '
                          '${threads.length == 1 ? 'gesprek' : 'gesprekken'}',
              ),
              subtitle: const Text(
                'Bewaard op dit toestel, in dezelfde versleutelde database.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.coach),
            ),
            if (threads.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextButton.icon(
                  onPressed: _clearThreads,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Alle gesprekken wissen'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
