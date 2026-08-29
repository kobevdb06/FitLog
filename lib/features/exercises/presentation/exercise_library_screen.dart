import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/routes.dart';
import 'custom_exercise_screen.dart';
import 'exercise_providers.dart';

/// The exercise catalogue.
///
/// The same screen browses the library and picks exercises for a routine or a
/// running workout; [selectionMode] only changes what a tap does.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.excludeIds = const {},
    this.singleSelection = false,
    this.title,
  });

  /// Opens the catalogue as a picker and returns the chosen ids.
  static Future<List<String>?> pick(
    BuildContext context, {
    Set<String> excludeIds = const {},
    bool single = false,
    String? title,
  }) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => ExerciseLibraryScreen(
          selectionMode: true,
          excludeIds: excludeIds,
          singleSelection: single,
          title: title,
        ),
      ),
    );
  }

  final bool selectionMode;
  final Set<String> excludeIds;
  final bool singleSelection;
  final String? title;

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  final _selected = <String>{};
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // The filter is shared state; entering the screen always starts clean.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exerciseFilterControllerProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onTapExercise(ExerciseRow exercise) {
    if (!widget.selectionMode) {
      context.push(Routes.exerciseDetail(exercise.id));
      return;
    }
    if (widget.singleSelection) {
      Navigator.of(context).pop([exercise.id]);
      return;
    }
    setState(() {
      _selected.contains(exercise.id)
          ? _selected.remove(exercise.id)
          : _selected.add(exercise.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exerciseFilterControllerProvider);
    final exercises = ref.watch(filteredExercisesProvider);
    final recent = ref.watch(recentExercisesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Oefeningen'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Badge(
              isLabelVisible:
                  filter.muscles.isNotEmpty ||
                  filter.equipment.isNotEmpty ||
                  filter.categories.isNotEmpty ||
                  filter.customOnly,
              child: const Icon(Icons.tune),
            ),
          ),
          IconButton(
            tooltip: 'Eigen oefening',
            onPressed: () async {
              final created = await CustomExerciseScreen.open(context);
              if (created != null && widget.selectionMode && mounted) {
                if (widget.singleSelection) {
                  if (context.mounted) Navigator.of(context).pop([created]);
                } else {
                  setState(() => _selected.add(created));
                }
              }
            },
            icon: const Icon(Icons.add),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 168 : 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Zoek een oefening',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: filter.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(
                                    exerciseFilterControllerProvider.notifier,
                                  )
                                  .setQuery('');
                            },
                          ),
                  ),
                  onChanged: ref
                      .read(exerciseFilterControllerProvider.notifier)
                      .setQuery,
                ),
                if (_showFilters) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const _FilterChips(),
                ],
              ],
            ),
          ),
        ),
      ),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (list) {
          final visible = list
              .where((e) => !widget.excludeIds.contains(e.id))
              .toList();
          final showRecent = filter.isEmpty && recent.isNotEmpty;

          if (visible.isEmpty && !showRecent) {
            return EmptyState(
              icon: Icons.search_off,
              title: 'Niets gevonden',
              message:
                  'Geen oefening past bij deze zoekopdracht of filters.',
              actionLabel: 'Filters wissen',
              onAction: () {
                _searchController.clear();
                ref.read(exerciseFilterControllerProvider.notifier).clear();
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (showRecent) ...[
                const SectionHeader('Recent gebruikt'),
                for (final exercise in recent.where(
                  (e) => !widget.excludeIds.contains(e.id),
                ))
                  _ExerciseTile(
                    exercise: exercise,
                    selected: _selected.contains(exercise.id),
                    selectable: widget.selectionMode,
                    onTap: () => _onTapExercise(exercise),
                  ),
                const SectionHeader('Alle oefeningen'),
              ],
              for (final exercise in visible)
                _ExerciseTile(
                  exercise: exercise,
                  selected: _selected.contains(exercise.id),
                  selectable: widget.selectionMode,
                  onTap: () => _onTapExercise(exercise),
                ),
            ],
          );
        },
      ),
      floatingActionButton: widget.selectionMode && _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pop(_selected.toList()),
              icon: const Icon(Icons.check),
              label: Text('${_selected.length} toevoegen'),
            )
          : null,
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(exerciseFilterControllerProvider);
    final notifier = ref.read(exerciseFilterControllerProvider.notifier);
    final muscles = ref.watch(muscleOptionsProvider).value ?? const [];
    final equipment =
        ref.watch(equipmentOptionsProvider).value ?? const [];

    return SizedBox(
      height: 104,
      child: ListView(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('Eigen'),
                  selected: filter.customOnly,
                  onSelected: notifier.setCustomOnly,
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final category in ExerciseCategory.values) ...[
                  FilterChip(
                    label: Text(category.label),
                    selected: filter.categories.contains(category.wire),
                    onSelected: (_) => notifier.toggleCategory(category.wire),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final muscle in muscles) ...[
                  FilterChip(
                    label: Text(muscle),
                    selected: filter.muscles.contains(muscle),
                    onSelected: (_) => notifier.toggleMuscle(muscle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                for (final item in equipment) ...[
                  FilterChip(
                    label: Text(item),
                    selected: filter.equipment.contains(item),
                    onSelected: (_) => notifier.toggleEquipment(item),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.selected,
    required this.selectable,
    required this.onTap,
  });

  final ExerciseRow exercise;
  final bool selected;
  final bool selectable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = ExerciseCategory.fromWire(exercise.category);
    return ListTile(
      onTap: onTap,
      leading: MuscleAvatar(muscle: exercise.primaryMuscle),
      title: Text(exercise.name),
      subtitle: Text(
        [
          exercise.primaryMuscle,
          exercise.equipment ?? category.label,
        ].join(' · '),
      ),
      trailing: selectable
          ? Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            )
          : (exercise.isCustom
                ? const Chip(
                    label: Text('Eigen'),
                    visualDensity: VisualDensity.compact,
                  )
                : const Icon(Icons.chevron_right)),
    );
  }
}
