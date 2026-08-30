import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../data/routine_import.dart';
import '../domain/exercise_matcher.dart';
import '../domain/routine_code.dart';

/// What the scanned routine will do to your catalogue, before it does it.
///
/// Every exercise says which of the three things is about to happen -
/// recognised, linked to one of yours, or added - and a link can be refused.
/// The app proposes; eight questions before you may press a button is not a
/// gift from a friend.
class ImportRoutineScreen extends ConsumerStatefulWidget {
  const ImportRoutineScreen({super.key, required this.routine});

  final SharedRoutine routine;

  /// Returns the id of the routine that was added, or null on a cancel.
  static Future<String?> open(BuildContext context, SharedRoutine routine) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => ImportRoutineScreen(routine: routine),
      ),
    );
  }

  @override
  ConsumerState<ImportRoutineScreen> createState() =>
      _ImportRoutineScreenState();
}

class _ImportRoutineScreenState extends ConsumerState<ImportRoutineScreen> {
  RoutineImportPlan? _plan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await planRoutineImport(
      ref.read(databaseProvider),
      widget.routine,
    );
    if (mounted) setState(() => _plan = plan);
  }

  Future<void> _add() async {
    final plan = _plan;
    if (plan == null || _saving) return;

    setState(() => _saving = true);
    try {
      final id = await applyRoutineImport(ref.read(databaseProvider), plan);
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Toevoegen mislukte: $error', isError: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Routine toevoegen')),
      body: plan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(plan.routine.name, style: theme.textTheme.headlineSmall),
                Text(
                  '${plan.exercises.length} oefeningen · '
                  '${plan.newExerciseCount} nieuw voor jou',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final planned in plan.exercises)
                  _PlannedTile(
                    planned: planned,
                    onChanged: (link) => setState(() => planned.link = link),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Zijn streefgewichten komen niet mee. De VORIGE-kolom vult '
                  'zich vanzelf zodra je de oefening een keer gedaan hebt.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : _add,
                  child: const Text('Toevoegen'),
                ),
              ],
            ),
    );
  }
}

class _PlannedTile extends StatelessWidget {
  const _PlannedTile({required this.planned, required this.onChanged});

  final PlannedExercise planned;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = planned.existing;

    final (String state, IconData icon) = switch (planned.match.kind) {
      ExerciseMatchKind.sameId => ('Ken je al', Icons.check),
      ExerciseMatchKind.sameName when planned.link => (
        'Gekoppeld aan jouw "${existing!.name}"',
        Icons.link,
      ),
      ExerciseMatchKind.similar when planned.link => (
        'Lijkt op jouw "${existing!.name}"',
        Icons.link,
      ),
      _ => ('Nieuw, wordt toegevoegd', Icons.add),
    };

    // The same id is not a judgement call - there is nothing to refuse.
    final canRefuse =
        planned.match.kind != ExerciseMatchKind.sameId && existing != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planned.incoming.name,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    state,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (canRefuse)
              TextButton(
                onPressed: () => onChanged(!planned.link),
                child: Text(planned.link ? 'Toch apart' : 'Toch koppelen'),
              ),
          ],
        ),
      ),
    );
  }
}
