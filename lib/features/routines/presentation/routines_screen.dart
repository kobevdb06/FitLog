import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/colour_picker.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../share/presentation/import_routine_screen.dart';
import '../../share/presentation/scan_routine_screen.dart';
import '../../workout/presentation/workout_providers.dart';
import 'routine_providers.dart';

/// The Trainen tab: folders, routines, and the two ways to start a session.
class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(routineFoldersProvider).value ?? const [];
    final routines = ref.watch(routineSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainen'),
        actions: [
          IconButton(
            tooltip: 'Nieuwe map',
            onPressed: () async {
              final name = await promptForText(
                context,
                title: 'Nieuwe map',
                hintText: 'bijvoorbeeld Push Pull Legs',
              );
              if (name == null || name.trim().isEmpty) return;
              await ref.read(routineActionsProvider).createFolder(name);
            },
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: 'Routine scannen',
            onPressed: () => scanAndImportRoutine(context, ref),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Oefeningen',
            onPressed: () => context.push(Routes.exercises),
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      body: routines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (list) {
          if (list.isEmpty && folders.isEmpty) {
            return EmptyState(
              icon: Icons.fitness_center,
              title: 'Nog geen routines',
              message:
                  'Maak een routine met je vaste oefeningen, of begin meteen '
                  'met een lege workout.',
              actionLabel: 'Routine maken',
              onAction: () => context.push(Routes.routineNew),
            );
          }

          final loose = list
              .where((r) => r.routine.folderId == null)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const _StartActions(),
              for (final folder in folders)
                _FolderSection(
                  folder: folder,
                  routines: list
                      .where((r) => r.routine.folderId == folder.id)
                      .toList(),
                ),
              if (loose.isNotEmpty) ...[
                if (folders.isNotEmpty) const SectionHeader('Losse routines'),
                for (final routine in loose) _RoutineTile(summary: routine),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.routineNew),
        icon: const Icon(Icons.add),
        label: const Text('Routine'),
      ),
    );
  }
}

class _StartActions extends ConsumerWidget {
  const _StartActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).value;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: active != null
          ? AppCard(
              onTap: () => context.push(Routes.workout),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workout loopt',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          active.workout.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            )
          : OutlinedButton.icon(
              onPressed: () async {
                final id = await ref
                    .read(workoutControllerProvider)
                    .startEmpty();
                if (context.mounted && id.isNotEmpty) {
                  context.push(Routes.workout);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lege workout starten'),
            ),
    );
  }
}

class _FolderSection extends ConsumerWidget {
  const _FolderSection({required this.folder, required this.routines});

  final RoutineFolderRow folder;
  final List<RoutineSummary> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          folder.name,
          action: IconButton(
            tooltip: 'Map bewerken',
            visualDensity: VisualDensity.compact,
            onPressed: () => _editFolder(context, ref),
            icon: const Icon(Icons.more_horiz, size: 20),
          ),
        ),
        if (routines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'Deze map is nog leeg.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final routine in routines) _RoutineTile(summary: routine),
      ],
    );
  }

  Future<void> _editFolder(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(routineActionsProvider);
    await showAppSheet<void>(
      context: context,
      title: folder.name,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Naam wijzigen'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final name = await promptForText(
                context,
                title: 'Map hernoemen',
                initialValue: folder.name,
              );
              if (name != null && name.trim().isNotEmpty) {
                await actions.renameFolder(folder.id, name);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Map verwijderen'),
            subtitle: const Text(
              'De routines erin blijven bestaan en komen op het hoofdniveau.',
            ),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final ok = await confirm(
                context,
                title: 'Map verwijderen?',
                message:
                    'De routines in deze map verdwijnen niet; ze komen op het '
                    'hoofdniveau te staan.',
                confirmLabel: 'Verwijderen',
                destructive: true,
              );
              if (ok) await actions.deleteFolder(folder.id);
            },
          ),
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.summary});

  final RoutineSummary summary;

  @override
  Widget build(BuildContext context) {
    final routine = summary.routine;
    final last = routine.lastPerformedAt;

    return ListTile(
      onTap: () => context.push(Routes.routineDetail(routine.id)),
      leading: ColourDot(colorIndex: routine.colorIndex),
      title: Text(routine.name),
      subtitle: Text(
        [
          '${summary.exerciseCount} oefeningen',
          '${summary.setCount} sets',
          if (last != null)
            Formatters.relativeDay(
              DateTime.fromMillisecondsSinceEpoch(last),
            ).toLowerCase()
          else
            'nog niet gedaan',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Scans a friend's code and, if it is a routine, offers to add it.
///
/// Two screens rather than one: the camera closes the moment it has read
/// something, and what happens next is a decision, not a scan.
Future<void> scanAndImportRoutine(BuildContext context, WidgetRef ref) async {
  final routine = await ScanRoutineScreen.open(context);
  if (routine == null || !context.mounted) return;

  final added = await ImportRoutineScreen.open(context, routine);
  if (added == null || !context.mounted) return;

  showSnack(context, 'Routine "${routine.name}" toegevoegd');
  context.push(Routes.routineDetail(added));
}
