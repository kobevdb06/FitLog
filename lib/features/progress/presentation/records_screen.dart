import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/exercise_avatar.dart';
import '../../../routing/routes.dart';
import 'progress_providers.dart';

enum _Sort {
  recent('Nieuwste eerst'),
  exercise('Op oefening'),
  value('Hoogste waarde');

  const _Sort(this.label);

  final String label;
}

/// Every personal record, grouped per exercise.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  PrType? _type;
  _Sort _sort = _Sort.recent;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(allRecordsProvider(type: _type));
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Persoonlijke records'),
        actions: [
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final sort in _Sort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                FilterChip(
                  label: const Text('Alle'),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final type in PrType.values) ...[
                  FilterChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Nog geen records',
              message:
                  'Elke afgevinkte set telt mee. Je eerste workout levert '
                  'meteen records op.',
              actionLabel: 'Naar routines',
              onAction: () => context.go(Routes.train),
            );
          }

          final sorted = [...list];
          switch (_sort) {
            case _Sort.recent:
              sorted.sort(
                (a, b) =>
                    b.record.achievedAt.compareTo(a.record.achievedAt),
              );
            case _Sort.exercise:
              sorted.sort(
                (a, b) => a.exercise.name.toLowerCase().compareTo(
                  b.exercise.name.toLowerCase(),
                ),
              );
            case _Sort.value:
              sorted.sort((a, b) => b.record.value.compareTo(a.record.value));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final record = sorted[index];
              return ListTile(
                onTap: () =>
                    context.push(Routes.exerciseDetail(record.exercise.id)),
                leading: ExerciseAvatar(
                  exercise: record.exercise,
                  size: 36,
                ),
                title: Text(record.exercise.name),
                subtitle: Text(
                  '${record.type.label} · '
                  '${Formatters.date(DateTime.fromMillisecondsSinceEpoch(record.record.achievedAt))}',
                ),
                trailing: Text(
                  _value(record, formatters),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.record,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _value(RecordWithExercise record, Formatters formatters) {
    switch (record.type) {
      case PrType.maxReps:
        return '${record.record.value.round()}';
      case PrType.maxSetVolume:
        return formatters.volume(record.record.value);
      case PrType.maxWeight:
      case PrType.est1rm:
        return formatters.weight(record.record.value);
    }
  }
}
