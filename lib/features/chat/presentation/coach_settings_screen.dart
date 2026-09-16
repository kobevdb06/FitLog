/// Where the coach is switched on, and where it is switched off again.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../data/ai_client.dart';
import '../domain/coach_budget.dart';
import 'chat_providers.dart';

/// What today has cost, as a bar plus the numbers behind it.
///
/// The bar counts calls, not questions: a question where the coach looks
/// something up in your logbook first is two calls or more, and a daily free
/// tier counts calls. It also says, in so many words, that this is the app's
/// own count - no service will tell a client what is left of your quota, and a
/// bar that looked like it knew would be worse than no bar.
class _DailyBar extends ConsumerWidget {
  const _DailyBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final limit = ref.watch(coachDailyLimitProvider);
    final usage =
        ref.watch(coachUsageTodayProvider).value ?? CoachDayUsage.none;
    final over = usage.isOver(limit);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${usage.requests} van $limit',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: over ? AppColors.danger : null,
                  ),
                ),
              ),
              Text(
                '${usage.answers} '
                '${usage.answers == 1 ? 'antwoord' : 'antwoorden'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: usage.fractionOf(limit),
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: over ? AppColors.danger : AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _tokens(usage),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _window(ref.watch(coachProviderProvider)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _tokens(CoachDayUsage usage) =>
      '${_thousands(usage.inputTokens)} tokens in, '
      '${_thousands(usage.outputTokens)} uit';

  /// A count of calls, and where the day starts, in one line.
  String _window(CoachProvider provider) => provider == CoachProvider.gemini
      ? 'Elke opzoeking in je logboek is een eigen vraag aan Google. De teller '
            'begint bij middernacht in Californië, want daar springt de '
            "gratis laag terug — hier is dat rond negen uur 's ochtends. "
            'Dit is wat de app zelf verstuurde; je echte tegoed kan niemand '
            'opvragen.'
      : 'Elke opzoeking in je logboek is een eigen vraag aan Anthropic. De '
            'teller begint bij middernacht. Dit is wat de app zelf '
            'verstuurde; je echte tegoed kan niemand opvragen.';

  static String _thousands(int value) {
    final text = '$value';
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

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
      hintText: 'AIza... of AQ....',
      confirmLabel: 'Bewaren',
    );
    if (key == null || !mounted) return;

    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await ref.read(databaseProvider).settingsDao.setApiKey(null);
      if (mounted) setState(() => _result = null);
      return;
    }

    // A key that unmistakably belongs to a service this version does not
    // offer is refused here rather than on the first question - the failure
    // would otherwise arrive as a rejected request that says nothing useful.
    final belongsTo = CoachProvider.forKey(trimmed);
    if (!kOfferedProviders.contains(belongsTo)) {
      showSnack(
        context,
        'Dat lijkt een sleutel van ${belongsTo.label}. FitLog werkt op dit '
        'moment alleen met een sleutel van Google AI Studio.',
      );
      return;
    }

    await ref.read(databaseProvider).settingsDao.setApiKey(trimmed);
    if (mounted) setState(() => _result = null);
  }

  Future<void> _enterImageKey() async {
    final token = await promptForText(
      context,
      title: 'Hugging Face-token',
      hintText: 'hf_...',
      confirmLabel: 'Bewaren',
    );
    if (token == null || !mounted) return;

    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          AppSettingsTableCompanion(
            imageApiKey: Value(token.trim().isEmpty ? null : token.trim()),
          ),
        );
  }

  Future<void> _removeImageKey() async {
    final ok = await confirm(
      context,
      title: 'Token verwijderen?',
      message:
          'Er wordt daarna nooit meer iets getekend. Wat al getekend is '
          'blijft staan.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok || !mounted) return;

    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          const AppSettingsTableCompanion(imageApiKey: Value(null)),
        );
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

  /// The models this key may use, asked of the service.
  ///
  /// Not a list this app ships: names change faster than releases do, and
  /// somebody with a key that can reach a model released last week should be
  /// able to pick it. When the list cannot be fetched - no connection, a key
  /// that is refused - the handful of names the app does know is offered
  /// instead, with the reason on screen.
  Future<void> _pickModel() async {
    final current = ref.read(coachModelProvider);
    final provider = ref.read(coachProviderProvider);
    final fallback = [
      for (final model in CoachModel.forProvider(provider))
        CoachModelInfo(
          wire: model.wire,
          label: model.label,
          description: model.description,
        ),
    ];

    final picked = await showAppSheet<String>(
      context: context,
      title: 'Welk model van ${provider.label}?',
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final models = ref.watch(coachModelsProvider);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (models.isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text('De lijst ophalen bij de dienst…'),
                    ],
                  ),
                ),
              if (models.hasError)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'De lijst kon niet opgehaald worden: '
                    '${models.error}. Hieronder staat wat de app zelf kent.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              // The light Gemini 3 models first, under a heading: those are
              // the ones with room to spare in the free tier.
              for (final (heading, group) in _grouped(
                models.value?.isEmpty ?? true ? fallback : models.value!,
              )) ...[
                if (heading != null) SectionHeader(heading),
                for (final model in group)
                  ListTile(
                    leading: Icon(
                      isRecommendedModel(model.wire, model.label)
                          ? Icons.star_outline
                          : Icons.smart_toy_outlined,
                    ),
                    title: Text(model.label),
                    subtitle: Text(
                      model.wire == model.label
                          ? (model.description ?? '')
                          : model.wire,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: model.wire == current,
                    onTap: () => Navigator.of(context).pop(model.wire),
                  ),
              ],
            ],
          );
        },
      ),
    );
    if (picked == null || !mounted) return;

    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(AppSettingsTableCompanion(chatModel: Value(picked)));
  }

  /// The recommended ones first, then the rest, each under its own heading -
  /// unless there is nothing to recommend, in which case one unlabelled list
  /// reads better than a heading over everything.
  List<(String?, List<CoachModelInfo>)> _grouped(List<CoachModelInfo> models) {
    final recommended = [
      for (final model in models)
        if (isRecommendedModel(model.wire, model.label)) model,
    ];
    if (recommended.isEmpty) return [(null, models)];

    return [
      ('Aanbevolen', recommended),
      (
        'Alles wat je sleutel kan',
        [
          for (final model in models)
            if (!isRecommendedModel(model.wire, model.label)) model,
        ],
      ),
    ];
  }

  /// The limit is the user's own number, so it is typed rather than chosen
  /// from a list the app made up.
  Future<void> _pickLimit() async {
    final current = ref.read(coachDailyLimitProvider);
    final answer = await promptForText(
      context,
      title: 'Daglimiet',
      initialValue: '$current',
      hintText: 'aantal vragen per dag',
      confirmLabel: 'Bewaren',
    );
    if (answer == null || !mounted) return;

    final value = int.tryParse(answer.trim());
    if (value == null || value <= 0) {
      showSnack(context, 'Geef een getal groter dan nul.');
      return;
    }

    await ref
        .read(databaseProvider)
        .settingsDao
        .updateSettings(
          AppSettingsTableCompanion(coachDailyLimit: Value(value)),
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
    final limit = ref.watch(coachDailyLimitProvider);
    final imageKey = ref.watch(coachImageKeyProvider);
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
                  'naar Google, samen met wat de coach in je logboek opvraagt '
                  'om te antwoorden; onder elk antwoord staat wat dat was. '
                  'Zonder sleutel maakt de app geen verbinding.',
            ),
          ),
          const SectionHeader('Sleutel'),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(key == null ? 'Nog geen sleutel' : _masked(key)),
            subtitle: Text(
              key == null
                  ? 'Een sleutel van Google AI Studio. Die heeft een gratis '
                        'laag; maak er een aan op aistudio.google.com/apikey.'
                  : 'Bewaard in je versleutelde database, achter je pincode.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _enterKey,
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
            const SectionHeader('Verbruik vandaag'),
            const _DailyBar(),
            ListTile(
              leading: const Icon(Icons.speed),
              title: Text('Daglimiet: $limit vragen'),
              subtitle: const Text(
                'Je eigen plafond. Tik om het aan te passen.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickLimit,
            ),
            const SectionHeader('Afbeeldingen'),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: InfoBanner(
                icon: Icons.auto_awesome,
                message:
                    'Met een token van Hugging Face kan je bij een eigen '
                    'oefening een illustratie laten tekenen. Alleen daar, en '
                    'nergens anders: elke tekening kost tegoed. Zonder token '
                    'wordt er nooit iets getekend.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: Text(
                imageKey == null ? 'Nog geen token' : _masked(imageKey),
              ),
              subtitle: Text(
                imageKey == null
                    ? 'Maak er een in je Hugging Face-account, bij Access '
                          'Tokens'
                    : 'Bewaard naast je andere sleutel, achter je pincode.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _enterImageKey,
            ),
            if (imageKey != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextButton.icon(
                  onPressed: _removeImageKey,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Token verwijderen'),
                ),
              ),
            const SectionHeader('Model'),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(ref.watch(coachModelLabelProvider)),
              subtitle: Text(model),
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
              onTap: () => context.go(Routes.chat),
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
