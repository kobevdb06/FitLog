import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/calc/plateau.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/plateau_loader.dart';
import 'progress_providers.dart';
import 'sleep_section.dart';

/// `1`, `1,5`, `10,3`: a rate, as precise as it means anything.
String _rate(double value) => NumberFormat('#,##0.#', 'nl').format(value);

/// `4 weken`.
String _weeks(int weeks) => weeks == 1 ? '1 week' : '$weeks weken';

/// The number a plateau is about, in its own unit.
String plateauValue(Plateau plateau, double value, Formatters formatters) =>
    switch (plateau.measure) {
      ProgressMeasure.oneRm => formatters.weight(value),
      ProgressMeasure.reps => Formatters.amount(
        value.round(),
        'herhaling',
        'herhalingen',
      ),
      ProgressMeasure.hold => Formatters.duration(value.round()),
    };

/// `4 weken geen vooruitgang · beste 110 kg`, for a list.
String plateauLine(Plateau plateau, Formatters formatters, {DateTime? now}) =>
    '${_weeks(plateau.weeksAt(now ?? DateTime.now()))} geen vooruitgang · '
    'beste ${plateauValue(plateau, plateau.best, formatters)}';

/// What the coach is asked about a stalled exercise. Put in the field, never
/// sent by the app.
String plateauQuestion(ExercisePlateau found, {DateTime? now}) =>
    'Mijn ${found.exercise.name} staat al '
    '${_weeks(found.plateau.weeksAt(now ?? DateTime.now()))} stil. '
    'Wat zou je anders doen?';

/// One stalled exercise: since when, what it stopped at, and what went on in
/// the meantime - set against the stretch before it, where there was one.
class PlateauCard extends ConsumerWidget {
  const PlateauCard({super.key, required this.found, this.now});

  final ExercisePlateau found;

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatters = ref.watch(formattersProvider);
    final coach = ref.watch(coachEnabledProvider);
    final plateau = found.plateau;
    final facts = found.context;
    final at = now ?? DateTime.now();
    final weeks = _weeks(plateau.weeksAt(at));
    final best = plateauValue(plateau, plateau.best, formatters);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final what = switch (plateau.measure) {
      ProgressMeasure.oneRm =>
        'Je geschatte 1RM kwam in $weeks niet boven $best',
      ProgressMeasure.reps =>
        'Je meeste herhalingen in één set kwamen in $weeks niet boven '
            '${plateau.best.round()}',
      ProgressMeasure.hold => 'Je langste tijd kwam in $weeks niet boven $best',
    };
    final last = plateau.latest < plateau.best
        ? ' De laatste keer: '
              '${plateauValue(plateau, plateau.latest, formatters)}.'
        : '';

    String? before(String? value) => value == null ? null : 'daarvoor $value';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_flat, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Staat stil sinds '
                  '${DateFormat('d MMMM', 'nl').format(plateau.since)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('$what.$last', style: muted),
          const SizedBox(height: AppSpacing.md),
          Text('Sindsdien', style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          _Fact('Keer per week', _rate(facts.sessionsPerWeek)),
          _Fact('Werksets per keer', _rate(facts.setsPerSession)),
          if (facts.typicalReps case final reps?)
            _Fact('Herhalingen', 'meestal $reps'),
          _Fact(
            'Sets voor ${found.exercise.primaryMuscle} per week',
            _rate(facts.muscleSetsPerWeek),
            before: before(switch (facts.muscleSetsPerWeekBefore) {
              final rate? => _rate(rate),
              null => null,
            }),
          ),
          if (facts.averageSleep case final sleep?)
            _Fact(
              'Slaap per nacht',
              nightLength(sleep),
              before: before(switch (facts.averageSleepBefore) {
                final earlier? => nightLength(earlier),
                null => null,
              }),
            ),
          // A hold puts no load on the estimate, so there is nothing to say.
          if (plateau.measure != ProgressMeasure.hold && facts.sessions > 0)
            _Fact(
              'Nog niet hersteld',
              '${facts.unrecovered} van ${facts.sessions} keer',
            ),
          if (coach) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  ref
                      .read(coachDraftProvider.notifier)
                      .put(plateauQuestion(found, now: now));
                  context.go(Routes.chat);
                },
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text('Vraag de coach'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the card: what, how much, and how much before.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.before});

  final String label;
  final String value;
  final String? before;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.md),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (before case final earlier?)
                  TextSpan(text: '  ($earlier)', style: muted),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stalled exercises on Voortgang, each opening its chart. Nothing at all
/// while everything is still going forward.
class PlateauSection extends ConsumerWidget {
  const PlateauSection({super.key, this.now});

  /// Fixed in tests; the real clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(plateausProvider).value ?? const [];
    if (found.isEmpty) return const SizedBox.shrink();
    final formatters = ref.watch(formattersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Staat stil'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final item in found)
                  ListTile(
                    leading: const Icon(Icons.trending_flat),
                    title: Text(item.exercise.name),
                    subtitle: Text(
                      plateauLine(item.plateau, formatters, now: now),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(Routes.exerciseCharts(item.exercise.id)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
