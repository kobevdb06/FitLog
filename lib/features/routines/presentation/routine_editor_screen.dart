import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/keypad_sheet.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../exercises/presentation/exercise_library_screen.dart';
import 'routine_providers.dart';

/// One exercise while the routine is being edited.
class _DraftExercise {
  _DraftExercise({
    required this.exercise,
    this.restSeconds,
    this.supersetGroup,
    this.notes,
    List<_DraftSet>? sets,
  }) : sets = sets ?? [_DraftSet()];

  final ExerciseRow exercise;
  int? restSeconds;
  int? supersetGroup;
  String? notes;
  List<_DraftSet> sets;
}

class _DraftSet {
  _DraftSet({
    this.setType = SetType.normal,
    this.reps,
    this.weightKg,
    this.durationSeconds,
  });

  SetType setType;
  int? reps;
  double? weightKg;
  int? durationSeconds;
}

/// Building and changing a routine: order, sets, targets, rest and supersets.
class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.routineId, this.folderId});

  final String? routineId;
  final String? folderId;

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_DraftExercise> _exercises = [];

  String? _folderId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _folderId = widget.folderId;
    if (widget.routineId == null) {
      _loaded = true;
      _nameController.text = 'Nieuwe routine';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefill(RoutineDetail detail) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = detail.routine.name;
    _notesController.text = detail.routine.notes ?? '';
    _folderId = detail.routine.folderId;
    _exercises.addAll(
      detail.exercises.map(
        (e) => _DraftExercise(
          exercise: e.exercise,
          restSeconds: e.routineExercise.restSeconds,
          supersetGroup: e.routineExercise.supersetGroup,
          notes: e.routineExercise.notes,
          sets: e.sets
              .map(
                (s) => _DraftSet(
                  setType: SetType.fromWire(s.setType),
                  reps: s.targetReps,
                  weightKg: s.targetWeightKg,
                  durationSeconds: s.targetDurationSeconds,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // --- Editing --------------------------------------------------------------

  Future<void> _addExercises() async {
    final picked = await ExerciseLibraryScreen.pick(
      context,
      excludeIds: _exercises.map((e) => e.exercise.id).toSet(),
      title: 'Oefeningen toevoegen',
    );
    if (picked == null || picked.isEmpty) return;

    final rows = await ref
        .read(databaseProvider)
        .exercisesDao
        .getByIds(picked);
    final byId = {for (final r in rows) r.id: r};
    setState(() {
      for (final id in picked) {
        final row = byId[id];
        if (row != null) _exercises.add(_DraftExercise(exercise: row));
      }
    });
  }

  Future<void> _replaceExercise(int index) async {
    final picked = await ExerciseLibraryScreen.pick(
      context,
      single: true,
      title: 'Vervangen door',
    );
    if (picked == null || picked.isEmpty) return;
    final rows = await ref
        .read(databaseProvider)
        .exercisesDao
        .getByIds(picked);
    if (rows.isEmpty) return;
    setState(() {
      final old = _exercises[index];
      _exercises[index] = _DraftExercise(
        exercise: rows.first,
        restSeconds: old.restSeconds,
        supersetGroup: old.supersetGroup,
        notes: old.notes,
        sets: old.sets,
      );
    });
  }

  /// Groups this exercise with the one below it. Reusing the lowest free group
  /// number keeps the letters stable as A, B, C.
  void _toggleSuperset(int index) {
    setState(() {
      final current = _exercises[index];
      if (current.supersetGroup != null) {
        current.supersetGroup = null;
        return;
      }
      if (index + 1 >= _exercises.length) return;

      final next = _exercises[index + 1];
      final group =
          next.supersetGroup ??
          () {
            final used = _exercises
                .map((e) => e.supersetGroup)
                .whereType<int>()
                .toSet();
            var candidate = 0;
            while (used.contains(candidate)) {
              candidate++;
            }
            return candidate;
          }();
      current.supersetGroup = group;
      next.supersetGroup = group;
    });
  }

  Future<void> _editSetValue(
    _DraftSet set,
    KeypadFieldKind kind,
    Formatters formatters,
  ) async {
    final isWeight = kind == KeypadFieldKind.weight;
    final initial = isWeight
        ? KeypadValue.fromNumber(
            set.weightKg == null
                ? null
                : formatters.toDisplayWeight(set.weightKg!),
          )
        : KeypadValue.fromNumber(set.reps, decimals: 0);

    final result = await showKeypadSheet(
      context: context,
      kind: kind,
      initialValue: initial,
      unitLabel: isWeight ? formatters.weightUnitLabel : null,
      title: isWeight ? 'Doelgewicht' : 'Doelreps',
      steps: isWeight && formatters.weightUnit == WeightUnit.lb
          ? const [2.5, 5, 10]
          : null,
    );
    if (result == null) return;

    setState(() {
      if (isWeight) {
        final value = result.number;
        set.weightKg = value == null
            ? null
            : formatters.fromDisplayWeight(value);
      } else {
        set.reps = result.intValue;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Geef de routine een naam.', isError: true);
      return;
    }
    if (_exercises.isEmpty) {
      showSnack(context, 'Voeg minstens een oefening toe.', isError: true);
      return;
    }

    setState(() => _saving = true);
    final draft = RoutineDraft(
      name: name,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      folderId: _folderId,
      exercises: _exercises
          .map(
            (e) => RoutineExerciseDraft(
              exerciseId: e.exercise.id,
              restSeconds: e.restSeconds,
              supersetGroup: e.supersetGroup,
              notes: e.notes,
              sets: e.sets
                  .map(
                    (s) => RoutineSetDraft(
                      setType: s.setType,
                      targetReps: s.reps,
                      targetWeightKg: s.weightKg,
                      targetDurationSeconds: s.durationSeconds,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );

    final actions = ref.read(routineActionsProvider);
    if (widget.routineId == null) {
      await actions.create(draft);
    } else {
      await actions.update(widget.routineId!, draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final formatters = ref.watch(formattersProvider);
    final folders = ref.watch(routineFoldersProvider).value ?? const [];

    if (widget.routineId != null) {
      final detail = ref.watch(routineDetailProvider(widget.routineId!)).value;
      if (detail != null) _prefill(detail);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routineId == null ? 'Nieuwe routine' : 'Routine bewerken',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Opslaan'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        header: _Header(
          nameController: _nameController,
          notesController: _notesController,
          folders: folders,
          folderId: _folderId,
          onFolder: (value) => setState(() => _folderId = value),
        ),
        itemCount: _exercises.length,
        // onReorderItem hands over an index that is already corrected for
        // the removed item, so no off-by-one adjustment is needed here.
        onReorderItem: (oldIndex, newIndex) => setState(() {
          final item = _exercises.removeAt(oldIndex);
          _exercises.insert(newIndex, item);
        }),
        itemBuilder: (context, index) {
          final draft = _exercises[index];
          return Padding(
            key: ValueKey('${draft.exercise.id}-$index'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _ExerciseEditorCard(
              index: index,
              draft: draft,
              formatters: formatters,
              canSuperset: index + 1 < _exercises.length,
              onRemove: () => setState(() => _exercises.removeAt(index)),
              onReplace: () => _replaceExercise(index),
              onToggleSuperset: () => _toggleSuperset(index),
              onAddSet: () => setState(() {
                final last = draft.sets.isEmpty ? null : draft.sets.last;
                draft.sets.add(
                  _DraftSet(
                    reps: last?.reps,
                    weightKg: last?.weightKg,
                    durationSeconds: last?.durationSeconds,
                  ),
                );
              }),
              onRemoveSet: (setIndex) => setState(() {
                draft.sets.removeAt(setIndex);
                if (draft.sets.isEmpty) draft.sets.add(_DraftSet());
              }),
              onEditWeight: (set) =>
                  _editSetValue(set, KeypadFieldKind.weight, formatters),
              onEditReps: (set) =>
                  _editSetValue(set, KeypadFieldKind.reps, formatters),
              onSetType: (set, type) => setState(() => set.setType = type),
              onRest: () async {
                final result = await showKeypadSheet(
                  context: context,
                  kind: KeypadFieldKind.duration,
                  initialValue: KeypadValue.fromNumber(
                    draft.restSeconds,
                    decimals: 0,
                  ),
                  unitLabel: 'sec',
                  title: 'Rust tussen sets',
                );
                if (result == null) return;
                setState(() => draft.restSeconds = result.intValue);
              },
              onNote: () async {
                final note = await promptForText(
                  context,
                  title: 'Notitie',
                  initialValue: draft.notes,
                  maxLines: 3,
                );
                if (note == null) return;
                setState(
                  () => draft.notes = note.trim().isEmpty ? null : note.trim(),
                );
              },
            ),
          );
        },
        footer: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: OutlinedButton.icon(
            onPressed: _addExercises,
            icon: const Icon(Icons.add),
            label: const Text('Oefening toevoegen'),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.nameController,
    required this.notesController,
    required this.folders,
    required this.folderId,
    required this.onFolder,
  });

  final TextEditingController nameController;
  final TextEditingController notesController;
  final List<RoutineFolderRow> folders;
  final String? folderId;
  final ValueChanged<String?> onFolder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Naam'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notesController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notitie'),
          ),
          if (folders.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: folderId,
              decoration: const InputDecoration(labelText: 'Map'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Geen map')),
                for (final f in folders)
                  DropdownMenuItem(value: f.id, child: Text(f.name)),
              ],
              onChanged: onFolder,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseEditorCard extends StatelessWidget {
  const _ExerciseEditorCard({
    required this.index,
    required this.draft,
    required this.formatters,
    required this.canSuperset,
    required this.onRemove,
    required this.onReplace,
    required this.onToggleSuperset,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onEditWeight,
    required this.onEditReps,
    required this.onSetType,
    required this.onRest,
    required this.onNote,
  });

  final int index;
  final _DraftExercise draft;
  final Formatters formatters;
  final bool canSuperset;
  final VoidCallback onRemove;
  final VoidCallback onReplace;
  final VoidCallback onToggleSuperset;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;
  final ValueChanged<_DraftSet> onEditWeight;
  final ValueChanged<_DraftSet> onEditReps;
  final void Function(_DraftSet, SetType) onSetType;
  final VoidCallback onRest;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = draft.supersetGroup;
    final groupColor = group == null
        ? null
        : AppColors.supersets[group % AppColors.supersets.length];

    return AppCard(
      borderColor: groupColor,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                MuscleAvatar(muscle: draft.exercise.primaryMuscle, size: 32),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.exercise.name,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (group != null)
                        Text(
                          'Superset ${String.fromCharCode(65 + group)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: groupColor,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'rest' => onRest(),
                    'note' => onNote(),
                    'replace' => onReplace(),
                    'superset' => onToggleSuperset(),
                    'remove' => onRemove(),
                    _ => null,
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rest',
                      child: Text('Rusttimer instellen'),
                    ),
                    const PopupMenuItem(value: 'note', child: Text('Notitie')),
                    const PopupMenuItem(
                      value: 'replace',
                      child: Text('Oefening vervangen'),
                    ),
                    if (canSuperset || group != null)
                      PopupMenuItem(
                        value: 'superset',
                        child: Text(
                          group == null
                              ? 'Superset met volgende'
                              : 'Superset opheffen',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Verwijderen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (draft.notes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                draft.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('SET', style: theme.textTheme.labelSmall),
                    ),
                    Expanded(
                      child: Text(
                        formatters.weightUnitLabel.toUpperCase(),
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'REPS',
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                for (var i = 0; i < draft.sets.length; i++)
                  _SetRow(
                    number: i + 1,
                    set: draft.sets[i],
                    formatters: formatters,
                    onWeight: () => onEditWeight(draft.sets[i]),
                    onReps: () => onEditReps(draft.sets[i]),
                    onRemove: () => onRemoveSet(i),
                    onSetType: (type) => onSetType(draft.sets[i], type),
                  ),
                TextButton.icon(
                  onPressed: onAddSet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Set toevoegen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.set,
    required this.formatters,
    required this.onWeight,
    required this.onReps,
    required this.onRemove,
    required this.onSetType,
  });

  final int number;
  final _DraftSet set;
  final Formatters formatters;
  final VoidCallback onWeight;
  final VoidCallback onReps;
  final VoidCallback onRemove;
  final ValueChanged<SetType> onSetType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: InkWell(
              onTap: () async {
                final type = await showAppSheet<SetType>(
                  context: context,
                  title: 'Type set',
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in SetType.values)
                        ListTile(
                          title: Text(t.label),
                          selected: t == set.setType,
                          onTap: () => Navigator.of(context).pop(t),
                        ),
                    ],
                  ),
                );
                if (type != null) onSetType(type);
              },
              child: SizedBox(
                height: AppSpacing.minTouch,
                child: Center(
                  child: Text(
                    set.setType.marker ?? '$number',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: set.setType == SetType.warmup
                          ? AppColors.record
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _ValueCell(
              text: set.weightKg == null
                  ? '-'
                  : formatters.weightValue(set.weightKg),
              onTap: onWeight,
            ),
          ),
          Expanded(
            child: _ValueCell(
              text: set.reps?.toString() ?? '-',
              onTap: onReps,
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: 'Set verwijderen',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ),
      ),
    );
  }
}
