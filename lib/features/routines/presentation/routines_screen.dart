import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc/routine_time.dart';
import '../../../core/calc/schedule.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../dashboard/domain/today_plan.dart';
import '../../dashboard/presentation/today_providers.dart';
import '../../share/presentation/import_routine_screen.dart';
import '../../share/presentation/scan_routine_screen.dart';
import '../../workout/presentation/workout_providers.dart';
import 'coach_folder.dart';
import 'favourite_star.dart';
import 'routine_providers.dart';
import 'routine_start.dart';

/// Whether [summary] is what someone typing [query] is after: by its name,
/// the folder it is in, or a muscle it trains.
bool routineMatches(
  RoutineSummary summary,
  String query, {
  String? folderName,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return summary.routine.name.toLowerCase().contains(q) ||
      (folderName?.toLowerCase().contains(q) ?? false) ||
      summary.muscles.any((m) => m.toLowerCase().contains(q));
}

/// The Trainen tab: what is planned today, the two ways in, and every
/// routine, in folders.
class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({super.key});

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  final _search = TextEditingController();
  var _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final folders = visibleFolders(
      ref.watch(routineFoldersProvider).value ?? const [],
      coach: ref.watch(coachEnabledProvider),
    );
    final routines = ref.watch(routineSummariesProvider);
    final query = _searching ? _search.text.trim() : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainen'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Zoeken sluiten' : 'Routine zoeken',
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.search_off : Icons.search),
          ),
          PopupMenuButton<_Menu>(
            tooltip: 'Meer',
            onSelected: (item) => switch (item) {
              _Menu.folder => _newFolder(),
              _Menu.scan => scanAndImportRoutine(context, ref),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _Menu.folder,
                child: ListTile(
                  leading: Icon(Icons.create_new_folder_outlined),
                  title: Text('Nieuwe map'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _Menu.scan,
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner),
                  title: Text('Routine scannen'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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

          // A folder whose name you typed shows all of it; any other only
          // what matches. Folders with nothing to show are left out while
          // searching, and kept otherwise: an empty folder is still yours.
          final sections = [
            for (final folder in folders)
              (
                folder: folder,
                routines: [
                  for (final r in list)
                    if (r.routine.folderId == folder.id &&
                        routineMatches(r, query, folderName: folder.name))
                      r,
                ],
              ),
          ];
          final loose = [
            for (final r in list)
              if (r.routine.folderId == null && routineMatches(r, query)) r,
          ];
          final shown = query.isEmpty
              ? sections
              : sections.where((s) => s.routines.isNotEmpty).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Zoek op naam, map of spiergroep',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                )
              else
                _StartActions(summaries: list),
              for (final section in shown)
                _FolderSection(
                  folder: section.folder,
                  routines: section.routines,
                ),
              if (loose.isNotEmpty) ...[
                if (shown.isNotEmpty) const SectionHeader('Losse routines'),
                for (final routine in loose) _RoutineTile(summary: routine),
              ],
              if (query.isNotEmpty && shown.isEmpty && loose.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Geen routine gevonden voor "$query".',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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

  Future<void> _newFolder() async {
    final name = await promptForText(
      context,
      title: 'Nieuwe map',
      hintText: 'bijvoorbeeld Push Pull Legs',
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(routineActionsProvider).createFolder(name);
  }
}

enum _Menu { folder, scan }

/// The top of the tab: what is going on or planned, and the two ways in that
/// are not a routine.
class _StartActions extends ConsumerWidget {
  const _StartActions({required this.summaries});

  final List<RoutineSummary> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).value;
    final plan = ref.watch(todayPlanProvider);
    final open = plan.kind == TodayPlanKind.scheduled
        ? [
            for (final planned in plan.routines)
              if (!planned.doneToday) planned.routine,
          ]
        : const <RoutineRow>[];
    final lead = open.isEmpty
        ? null
        : summaries.firstWhereOrNull((s) => s.routine.id == open.first.id);
    final minutes = lead == null
        ? 0
        : estimatedRoutineMinutes(
            lead.timing,
            defaultRestSeconds:
                ref.watch(settingsProvider).value?.defaultRestSeconds ?? 90,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A session that is running comes before any plan: there can only
          // be one, and it is the one you were in the middle of.
          if (active != null)
            _TopCard(
              label: 'Workout loopt',
              title: active.workout.name,
              action: 'Ga verder',
              icon: Icons.play_arrow,
              onPressed: () => context.push(Routes.workout),
            )
          else if (lead != null)
            _TopCard(
              label: 'Vandaag gepland',
              title: lead.routine.name,
              detail: [
                if (lead.muscles.isNotEmpty) routineMuscles(lead.muscles),
                if (minutes > 0) '±$minutes min',
              ].join(' · '),
              after: open.length > 1
                  ? 'Ook gepland: ${open.skip(1).map((r) => r.name).join(', ')}'
                  : null,
              color: AppColors.routineColor(lead.routine.colorIndex),
              action: 'Start',
              icon: Icons.play_arrow,
              onTap: () => context.push(Routes.routineDetail(lead.routine.id)),
              onPressed: lead.exerciseCount == 0
                  ? null
                  : () =>
                        startSession(context, ref, routineId: lead.routine.id),
            ),
          if (active != null || lead != null)
            const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => startSession(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Lege training'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.exercises),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Oefeningen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one card above the routines: a session to go back to, or the routine
/// your schedule has on today.
class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.label,
    required this.title,
    required this.action,
    required this.icon,
    required this.onPressed,
    this.detail = '',
    this.after,
    this.color,
    this.onTap,
  });

  final String label;
  final String title;
  final String detail;
  final String? after;
  final Color? color;
  final String action;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AppCard(
      onTap: onTap,
      borderColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: theme.textTheme.titleMedium),
          if (detail.isNotEmpty) Text(detail, style: muted),
          if (after != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(after!, style: muted),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(action),
          ),
        ],
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
        if (folder.isCoach || routines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              switch ((folder.isCoach, routines.isEmpty)) {
                (true, true) =>
                  'De coach mag routines in deze map aanpassen. Vraag hem om '
                      'een routine, of zet er een van jou in.',
                (true, false) => 'De coach mag deze routines aanpassen.',
                _ => 'Deze map is nog leeg.',
              },
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
            subtitle: Text(
              folder.isCoach
                  ? 'De routines erin blijven bestaan en komen op het '
                        'hoofdniveau, waar de coach er niet meer aan kan.'
                  : 'De routines erin blijven bestaan en komen op het '
                        'hoofdniveau.',
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

/// `Borst · Schouders · Triceps`: what a routine trains, at most three.
String routineMuscles(List<String> muscles) => [
  for (final m in muscles.take(3))
    m.isEmpty ? m : m[0].toUpperCase() + m.substring(1),
].join(' · ');

/// One routine: its colour down the side, what it trains, how long it
/// takes, and a button that starts it without opening it first.
class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.summary});

  final RoutineSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routine = summary.routine;
    final last = routine.lastPerformedAt;
    final days = WeekdaySet(routine.scheduledDays);
    final rest = ref.watch(settingsProvider).value?.defaultRestSeconds ?? 90;
    final minutes = estimatedRoutineMinutes(
      summary.timing,
      defaultRestSeconds: rest,
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.routineDetail(routine.id)),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The colour you gave it, as a stripe rather than a dot:
                  // the one thing that tells two routines apart at a glance.
                  Container(
                    width: 5,
                    color:
                        AppColors.routineColor(routine.colorIndex) ??
                        theme.colorScheme.outline,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(routine.name, style: theme.textTheme.titleSmall),
                          if (summary.muscles.isNotEmpty)
                            Text(
                              routineMuscles(summary.muscles),
                              style: muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            [
                              // First, because the days are what tells two
                              // routines of the same muscles apart.
                              if (days.isNotEmpty)
                                [
                                  for (final day in days.weekdays)
                                    Formatters.weekdayShort(day),
                                ].join(' '),
                              Formatters.amount(
                                summary.exerciseCount,
                                'oefening',
                                'oefeningen',
                              ),
                              if (minutes > 0) '±$minutes min',
                              if (last != null)
                                Formatters.relativeDay(
                                  DateTime.fromMillisecondsSinceEpoch(last),
                                ).toLowerCase()
                              else
                                'nog niet gedaan',
                            ].join(' · '),
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  FavouriteStar(routine: routine),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Center(
                      child: IconButton.filledTonal(
                        tooltip: '${routine.name} starten',
                        onPressed: summary.exerciseCount == 0
                            ? null
                            : () => startSession(
                                context,
                                ref,
                                routineId: routine.id,
                              ),
                        icon: const Icon(Icons.play_arrow),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
