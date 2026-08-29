import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/util/feedback_service.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/keypad_value.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../../routing/routes.dart';
import '../../exercises/presentation/exercise_library_screen.dart';
import 'plate_calculator_sheet.dart';
import 'rest_timer_bar.dart';
import 'warmup_sheet.dart';
import 'workout_providers.dart';

/// Which cell the keypad is editing.
class _KeypadTarget {
  const _KeypadTarget(this.setId, this.kind);

  final String setId;
  final KeypadFieldKind kind;

  @override
  bool operator ==(Object other) =>
      other is _KeypadTarget && other.setId == setId && other.kind == kind;

  @override
  int get hashCode => Object.hash(setId, kind);
}

/// The screen the whole app is built around: logging a session set by set.
///
/// Every edit is written straight to the database, so a crash or a forced
/// close loses nothing and the session simply resumes on the next start.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _ticker;
  _KeypadTarget? _target;
  KeypadValue _keypadValue = const KeypadValue.empty();

  /// Held onto because `ref` may no longer be read from in [dispose].
  late final AppController _appController;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // The screen stays on for the whole session. A device without the plugin
    // (or a test environment) must not take the screen down with it.
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    _appController = ref.read(appControllerProvider.notifier)
      ..workoutInProgress = true;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    _appController.workoutInProgress = false;
    super.dispose();
  }

  FeedbackService _feedback(AppSettingsRow? settings) => FeedbackService(
    setCheckSoundEnabled: settings?.setCheckSoundEnabled ?? true,
  );

  // --- Keypad ---------------------------------------------------------------

  void _focus(WorkoutSetRow row, KeypadFieldKind kind, Formatters formatters) {
    setState(() {
      _target = _KeypadTarget(row.id, kind);
      _keypadValue = switch (kind) {
        KeypadFieldKind.weight => KeypadValue.fromNumber(
          row.weightKg == null
              ? null
              : formatters.toDisplayWeight(row.weightKg!),
        ),
        KeypadFieldKind.reps => KeypadValue.fromNumber(row.reps, decimals: 0),
        KeypadFieldKind.duration => KeypadValue.fromNumber(
          row.durationSeconds,
          decimals: 0,
        ),
        KeypadFieldKind.distance => KeypadValue.fromNumber(row.distanceM),
        KeypadFieldKind.rpe => KeypadValue.fromNumber(row.rpe, decimals: 1),
      };
    });
  }

  Future<void> _writeKeypadValue(
    KeypadValue value,
    Formatters formatters,
  ) async {
    final target = _target;
    if (target == null) return;
    final controller = ref.read(workoutControllerProvider);

    switch (target.kind) {
      case KeypadFieldKind.weight:
        final number = value.number;
        await controller.updateSetValues(
          target.setId,
          weightKg: Value(
            number == null ? null : formatters.fromDisplayWeight(number),
          ),
        );
      case KeypadFieldKind.reps:
        await controller.updateSetValues(
          target.setId,
          reps: Value(value.intValue),
        );
      case KeypadFieldKind.duration:
        await controller.updateSetValues(
          target.setId,
          durationSeconds: Value(value.intValue),
        );
      case KeypadFieldKind.distance:
        await controller.updateSetValues(
          target.setId,
          distanceM: Value(value.number),
        );
      case KeypadFieldKind.rpe:
        await controller.updateSetValues(
          target.setId,
          rpe: Value(value.number),
        );
    }
  }

  /// Weight to reps, then on to the next set. This is what makes logging
  /// possible without ever leaving the keypad.
  void _moveToNextField(WorkoutDetail workout, Formatters formatters) {
    final target = _target;
    if (target == null) return;

    if (target.kind == KeypadFieldKind.weight) {
      final row = _findSet(workout, target.setId);
      if (row != null) {
        _focus(row, KeypadFieldKind.reps, formatters);
        return;
      }
    }

    final flat = <WorkoutSetRow>[
      for (final exercise in workout.exercises) ...exercise.sets,
    ];
    final index = flat.indexWhere((s) => s.id == target.setId);
    if (index >= 0 && index + 1 < flat.length) {
      _focus(flat[index + 1], KeypadFieldKind.weight, formatters);
      return;
    }
    setState(() => _target = null);
  }

  WorkoutSetRow? _findSet(WorkoutDetail workout, String setId) {
    for (final exercise in workout.exercises) {
      for (final s in exercise.sets) {
        if (s.id == setId) return s;
      }
    }
    return null;
  }

  // --- Set completion -------------------------------------------------------

  Future<void> _toggleSet(WorkoutSetRow row, AppSettingsRow? settings) async {
    final controller = ref.read(workoutControllerProvider);
    final feedback = _feedback(settings);

    if (row.isCompleted) {
      unawaited(feedback.setUncompleted());
      await controller.uncompleteSet(row.id);
      return;
    }

    final result = await controller.completeSet(setId: row.id);
    if (result == null) return;

    // Feedback runs alongside: a slow or missing vibrator must never delay the
    // rest timer.
    unawaited(
      result.hasRecord ? feedback.personalRecord() : feedback.setCompleted(),
    );

    if (result.restSeconds > 0) {
      await ref
          .read(restTimerProvider.notifier)
          .start(
            seconds: result.restSeconds,
            exerciseName: result.exerciseName,
            withSound: settings?.restSoundEnabled ?? true,
          );
    }

    if (!mounted) return;
    setState(() => _target = null);

    if (result.hasRecord && (settings?.prAlertEnabled ?? true)) {
      showSnack(
        context,
        'Nieuw record: '
        '${result.records.map((r) => r.type.label).join(', ')}',
      );
    }
  }

  // --- Finishing ------------------------------------------------------------

  Future<void> _finish(WorkoutDetail workout) async {
    final pending = workout.pendingSets;
    var discard = false;

    if (pending > 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Workout afronden?'),
          content: Text(
            '$pending ${pending == 1 ? 'set is' : 'sets zijn'} niet '
            'ingevuld. Wil je die verwijderen of bewaren?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Terug'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('keep'),
              child: const Text('Bewaren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text('Verwijderen'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      discard = choice == 'discard';
    } else {
      final ok = await confirm(
        context,
        title: 'Workout afronden?',
        message: 'Je sessie wordt bewaard in je geschiedenis.',
        confirmLabel: 'Afronden',
      );
      if (!ok) return;
    }

    final id = workout.workout.id;
    await ref
        .read(workoutControllerProvider)
        .finish(id, discardPending: discard);
    if (mounted) context.pushReplacement(Routes.workoutSummary(id));
  }

  Future<void> _cancel(WorkoutDetail workout) async {
    final ok = await confirm(
      context,
      title: 'Workout weggooien?',
      message:
          'Alles wat je in deze sessie hebt gelogd verdwijnt. Dit kan niet '
          'ongedaan gemaakt worden.',
      confirmLabel: 'Weggooien',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(workoutControllerProvider).cancel(workout.workout.id);
    if (mounted) context.pop();
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(activeWorkoutProvider);
    final formatters = ref.watch(formattersProvider);
    final settings = ref.watch(settingsProvider).value;

    return workoutAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (workout) {
        if (workout == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Workout')),
            body: EmptyState(
              icon: Icons.fitness_center,
              title: 'Geen lopende workout',
              message: 'Start een routine of een lege workout om te loggen.',
              actionLabel: 'Naar routines',
              onAction: () => context.go(Routes.train),
            ),
          );
        }

        final elapsed = DateTime.now()
            .difference(
              DateTime.fromMillisecondsSinceEpoch(workout.workout.startedAt),
            )
            .inSeconds;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Verbergen',
              onPressed: () => context.pop(),
            ),
            title: InkWell(
              onTap: () async {
                final name = await promptForText(
                  context,
                  title: 'Naam van de workout',
                  initialValue: workout.workout.name,
                );
                if (name == null || name.trim().isEmpty) return;
                await ref
                    .read(workoutControllerProvider)
                    .rename(workout.workout.id, name.trim());
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    workout.workout.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    Formatters.duration(elapsed),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _finish(workout),
                child: const Text('Klaar'),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'cancel') _cancel(workout);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text('Workout weggooien'),
                  ),
                ],
              ),
            ],
          ),
          body: workout.exercises.isEmpty
              ? EmptyState(
                  icon: Icons.add_circle_outline,
                  title: 'Nog geen oefeningen',
                  message: 'Voeg de eerste oefening toe en begin te loggen.',
                  actionLabel: 'Oefening toevoegen',
                  onAction: () => _addExercises(workout),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final exercise in workout.exercises)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: _ExerciseCard(
                          workout: workout,
                          detail: exercise,
                          formatters: formatters,
                          settings: settings,
                          activeTarget: _target,
                          onFocus: (row, kind) => _focus(row, kind, formatters),
                          onToggle: (row) => _toggleSet(row, settings),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: OutlinedButton.icon(
                        onPressed: () => _addExercises(workout),
                        icon: const Icon(Icons.add),
                        label: const Text('Oefening toevoegen'),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: _target != null
              ? NumericKeypad(
                  value: _keypadValue,
                  kind: _target!.kind,
                  unitLabel: _target!.kind == KeypadFieldKind.weight
                      ? formatters.weightUnitLabel
                      : null,
                  steps:
                      _target!.kind == KeypadFieldKind.weight &&
                          formatters.weightUnit == WeightUnit.lb
                      ? const [2.5, 5, 10]
                      : null,
                  feedback: _feedback(settings),
                  onChanged: (value) {
                    setState(() => _keypadValue = value);
                    _writeKeypadValue(value, formatters);
                  },
                  onNext: () => _moveToNextField(workout, formatters),
                  onDone: () => setState(() => _target = null),
                )
              : const RestTimerBar(),
        );
      },
    );
  }

  Future<void> _addExercises(WorkoutDetail workout) async {
    final picked = await ExerciseLibraryScreen.pick(
      context,
      excludeIds: workout.exercises.map((e) => e.exercise.id).toSet(),
      title: 'Oefening toevoegen',
    );
    if (picked == null || picked.isEmpty) return;
    await ref
        .read(workoutControllerProvider)
        .addExercises(workout.workout.id, picked);
  }
}

// --- Exercise card ----------------------------------------------------------

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.workout,
    required this.detail,
    required this.formatters,
    required this.settings,
    required this.activeTarget,
    required this.onFocus,
    required this.onToggle,
  });

  final WorkoutDetail workout;
  final WorkoutExerciseDetail detail;
  final Formatters formatters;
  final AppSettingsRow? settings;
  final _KeypadTarget? activeTarget;
  final void Function(WorkoutSetRow, KeypadFieldKind) onFocus;
  final void Function(WorkoutSetRow) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = detail.workoutExercise.supersetGroup;
    final groupColor = group == null
        ? null
        : AppColors.supersets[group % AppColors.supersets.length];

    final previous = ref.watch(previousSetsProvider(detail.exercise.id)).value;
    final previousNote = ref
        .watch(previousNoteProvider(detail.exercise.id))
        .value;
    final recordSetIds =
        ref.watch(workoutRecordSetIdsProvider(workout.workout.id)).value ??
        const <String>{};

    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: groupColor,
      // IntrinsicHeight gives the superset stripe a height to stretch to; a
      // stretching Row inside a scroll view has none of its own.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (groupColor != null)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(
                    detail: detail,
                    groupColor: groupColor,
                    group: group,
                    onMenu: (value) => _onMenu(context, ref, value),
                  ),
                  _NoteField(
                    detail: detail,
                    previousNote: previousNote,
                    onChanged: (note) => ref
                        .read(workoutControllerProvider)
                        .setExerciseNote(detail.workoutExercise.id, note),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        _ColumnHeaders(formatters: formatters),
                        for (var i = 0; i < detail.sets.length; i++)
                          SetRow(
                            key: ValueKey(detail.sets[i].id),
                            row: detail.sets[i],
                            index: i,
                            previous: _previousFor(previous, detail.sets, i),
                            formatters: formatters,
                            isRecord: recordSetIds.contains(detail.sets[i].id),
                            activeKind: activeTarget?.setId == detail.sets[i].id
                                ? activeTarget!.kind
                                : null,
                            onFocus: (kind) => onFocus(detail.sets[i], kind),
                            onToggle: () => onToggle(detail.sets[i]),
                            onDelete: () => ref
                                .read(workoutControllerProvider)
                                .deleteSet(detail.sets[i].id),
                            onSetType: (type) => ref
                                .read(workoutControllerProvider)
                                .setSetType(detail.sets[i].id, type),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => ref
                                .read(workoutControllerProvider)
                                .addSet(detail.workoutExercise.id),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Set toevoegen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The same set index from the previous session, or null.
  WorkoutSetRow? _previousFor(
    List<WorkoutSetRow>? previous,
    List<WorkoutSetRow> current,
    int index,
  ) {
    if (previous == null || previous.isEmpty) return null;
    if (index >= previous.length) return null;
    return previous[index];
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final controller = ref.read(workoutControllerProvider);

    switch (value) {
      case 'rest':
        final seconds = await showAppSheet<int>(
          context: context,
          title: 'Rust tussen sets',
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in const [0, 30, 60, 90, 120, 150, 180, 240])
                ListTile(
                  title: Text(option == 0 ? 'Geen rust' : '$option seconden'),
                  selected: detail.workoutExercise.restSeconds == option,
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        );
        if (seconds != null) {
          await controller.setExerciseRest(detail.workoutExercise.id, seconds);
        }

      case 'note':
        final note = await promptForText(
          context,
          title: 'Notitie',
          initialValue: detail.workoutExercise.notes,
          maxLines: 3,
        );
        if (note != null) {
          await controller.setExerciseNote(detail.workoutExercise.id, note);
        }

      case 'replace':
        final picked = await ExerciseLibraryScreen.pick(
          context,
          single: true,
          title: 'Vervangen door',
        );
        if (picked != null && picked.isNotEmpty) {
          await controller.replaceExercise(
            detail.workoutExercise.id,
            picked.first,
          );
        }

      case 'superset':
        await _toggleSuperset(ref);

      case 'plates':
        final heaviest = detail.sets
            .map((s) => s.weightKg ?? 0)
            .fold<double>(0, (a, b) => a > b ? a : b);
        if (context.mounted) {
          await PlateCalculatorSheet.show(
            context,
            targetKg: heaviest > 0 ? heaviest : null,
          );
        }

      case 'warmup':
        final working = detail.sets
            .where((s) => SetType.fromWire(s.setType) != SetType.warmup)
            .map((s) => s.weightKg ?? 0)
            .fold<double>(0, (a, b) => a > b ? a : b);
        if (!context.mounted) return;
        final sets = await WarmupSheet.show(context, workWeightKg: working);
        if (sets != null && sets.isNotEmpty) {
          await controller.insertWarmupSets(detail.workoutExercise.id, sets);
        }

      case 'remove':
        if (!context.mounted) return;
        final ok = await confirm(
          context,
          title: 'Oefening verwijderen?',
          message: 'De sets van deze oefening verdwijnen uit deze workout.',
          confirmLabel: 'Verwijderen',
          destructive: true,
        );
        if (ok) await controller.removeExercise(detail.workoutExercise.id);
    }
  }

  /// Pairs the exercise with the one after it, or breaks an existing group.
  Future<void> _toggleSuperset(WidgetRef ref) async {
    final controller = ref.read(workoutControllerProvider);
    final group = detail.workoutExercise.supersetGroup;

    if (group != null) {
      for (final member in workout.supersetMembers(group)) {
        await controller.setSupersetGroup(member.workoutExercise.id, null);
      }
      return;
    }

    final index = workout.exercises.indexWhere(
      (e) => e.workoutExercise.id == detail.workoutExercise.id,
    );
    if (index < 0 || index + 1 >= workout.exercises.length) return;

    final next = workout.exercises[index + 1];
    final used = workout.exercises
        .map((e) => e.workoutExercise.supersetGroup)
        .whereType<int>()
        .toSet();
    var candidate = next.workoutExercise.supersetGroup ?? 0;
    while (next.workoutExercise.supersetGroup == null &&
        used.contains(candidate)) {
      candidate++;
    }

    await controller.setSupersetGroup(detail.workoutExercise.id, candidate);
    await controller.setSupersetGroup(next.workoutExercise.id, candidate);
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.detail,
    required this.groupColor,
    required this.group,
    required this.onMenu,
  });

  final WorkoutExerciseDetail detail;
  final Color? groupColor;
  final int? group;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () =>
                  context.push(Routes.exerciseDetail(detail.exercise.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    if (group != null) ...[
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: groupColor?.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          String.fromCharCode(65 + group!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: groupColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        detail.exercise.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.accent,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: onMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rest',
                child: Text('Rusttimer instellen'),
              ),
              const PopupMenuItem(value: 'note', child: Text('Notitie')),
              const PopupMenuItem(
                value: 'plates',
                child: Text('Schijvenberekening'),
              ),
              const PopupMenuItem(
                value: 'warmup',
                child: Text('Warming-up berekenen'),
              ),
              const PopupMenuItem(
                value: 'replace',
                child: Text('Oefening vervangen'),
              ),
              PopupMenuItem(
                value: 'superset',
                child: Text(
                  group == null ? 'Superset maken' : 'Superset opheffen',
                ),
              ),
              const PopupMenuItem(value: 'remove', child: Text('Verwijderen')),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({
    required this.detail,
    required this.previousNote,
    required this.onChanged,
  });

  final WorkoutExerciseDetail detail;
  final String? previousNote;
  final ValueChanged<String> onChanged;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.detail.workoutExercise.notes ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _controller,
        maxLines: 2,
        minLines: 1,
        style: theme.textTheme.bodySmall,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          // Last time's note is offered as a hint, not as a value.
          hintText: widget.previousNote ?? 'Notitie toevoegen',
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.formatters});

  final Formatters formatters;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('SET', style: style)),
          Expanded(
            flex: 3,
            child: Text('VORIGE', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatters.weightUnitLabel.toUpperCase(),
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('REPS', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: AppSpacing.setCheckbox,
            child: Icon(
              Icons.check,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the set table. Exported so the widget test can drive it.
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.row,
    required this.index,
    required this.previous,
    required this.formatters,
    required this.isRecord,
    required this.activeKind,
    required this.onFocus,
    required this.onToggle,
    required this.onDelete,
    required this.onSetType,
  });

  final WorkoutSetRow row;
  final int index;
  final WorkoutSetRow? previous;
  final Formatters formatters;
  final bool isRecord;
  final KeypadFieldKind? activeKind;
  final ValueChanged<KeypadFieldKind> onFocus;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<SetType> onSetType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setType = SetType.fromWire(row.setType);

    return Dismissible(
      key: ValueKey('dismiss-${row.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: row.isCompleted
              ? AppColors.success.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: InkWell(
                onLongPress: () async {
                  final type = await showAppSheet<SetType>(
                    context: context,
                    title: 'Type set',
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final t in SetType.values)
                          ListTile(
                            title: Text(t.label),
                            selected: t == setType,
                            onTap: () => Navigator.of(context).pop(t),
                          ),
                      ],
                    ),
                  );
                  if (type != null) onSetType(type);
                },
                child: SizedBox(
                  height: AppSpacing.setCheckbox,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          setType.marker ?? '${index + 1}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: setType == SetType.warmup
                                ? AppColors.record
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isRecord) ...[
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.emoji_events,
                            size: 11,
                            color: AppColors.record,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                previous == null
                    ? '-'
                    : formatters.setSummary(
                        weightKg: previous!.weightKg,
                        reps: previous!.reps,
                        durationSeconds: previous!.durationSeconds,
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: _Cell(
                text: row.weightKg == null
                    ? null
                    : formatters.weightValue(row.weightKg),
                placeholder: previous?.weightKg == null
                    ? '-'
                    : formatters.weightValue(previous!.weightKg),
                active: activeKind == KeypadFieldKind.weight,
                onTap: () => onFocus(KeypadFieldKind.weight),
              ),
            ),
            Expanded(
              flex: 2,
              child: _Cell(
                text: row.reps?.toString(),
                placeholder: previous?.reps?.toString() ?? '-',
                active: activeKind == KeypadFieldKind.reps,
                onTap: () => onFocus(KeypadFieldKind.reps),
              ),
            ),
            _CheckBox(completed: row.isCompleted, onTap: onToggle),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    required this.placeholder,
    required this.active,
    required this.onTap,
  });

  /// The stored value, or null when the set has not been filled in yet.
  final String? text;

  /// Last session's value, shown grey until the set is actually filled in.
  final String placeholder;

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Material(
        color: active
            ? AppColors.accent.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            height: AppSpacing.minTouch,
            child: Center(
              child: Text(
                text ?? placeholder,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: text == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontWeight: text == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.completed, required this.onTap});

  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: completed ? 'Set voltooid' : 'Set afvinken',
      button: true,
      child: SizedBox(
        width: AppSpacing.setCheckbox,
        height: AppSpacing.setCheckbox,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: completed
                    ? AppColors.success
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: completed
                      ? AppColors.success
                      : theme.colorScheme.outline,
                ),
              ),
              child: Icon(
                Icons.check,
                size: 20,
                color: completed
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
