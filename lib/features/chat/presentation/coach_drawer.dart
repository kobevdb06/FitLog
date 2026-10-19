/// The conversations with the coach, in a panel from the left - the way
/// ChatGPT and Claude keep theirs.
///
/// It comes over the whole screen, the tab bar too, and is opened with the
/// button only: swiping in from the edge would fight the swipe between the
/// tabs. Swiping it back, or tapping beside it, closes it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/dao/chat_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../routing/routes.dart';
import '../../workout/presentation/workout_providers.dart';
import 'chat_providers.dart';
import 'coach_session.dart';

Future<void> showCoachDrawer(BuildContext context) => showGeneralDialog<void>(
  context: context,
  useRootNavigator: true,
  barrierDismissible: true,
  barrierLabel: 'Sluiten',
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (context, _, _) => const _CoachDrawer(),
  transitionBuilder: (context, animation, _, child) => SlideTransition(
    position: Tween(begin: const Offset(-1, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    ),
    child: child,
  ),
);

/// Where a conversation goes in the list, by the day it was last added to.
enum ThreadGroup {
  today('Vandaag'),
  yesterday('Gisteren'),
  week('Afgelopen week'),
  earlier('Eerder');

  const ThreadGroup(this.label);

  final String label;

  /// Counted on the calendar, in UTC, where every day has 24 hours.
  static ThreadGroup of(DateTime at, DateTime now) {
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(at.year, at.month, at.day)).inDays;
    return switch (days) {
      <= 0 => today,
      1 => yesterday,
      < 7 => week,
      _ => earlier,
    };
  }
}

class _CoachDrawer extends ConsumerStatefulWidget {
  const _CoachDrawer();

  @override
  ConsumerState<_CoachDrawer> createState() => _CoachDrawerState();
}

class _CoachDrawerState extends ConsumerState<_CoachDrawer> {
  final _search = TextEditingController();
  Future<List<ChatThreadRow>>? _found;

  /// How far it was pulled back towards the edge.
  double _drag = 0;

  CoachSessionController get _session =>
      ref.read(coachSessionControllerProvider.notifier);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _find(String query) => setState(() {
    _found = query.trim().isEmpty
        ? null
        : ref.read(databaseProvider).chatDao.searchThreads(query);
  });

  void _open(ChatThreadRow thread, {required String? running}) {
    _session.show(
      thread.id,
      workoutId: thread.workoutId != null && thread.workoutId == running
          ? running
          : null,
    );
    Navigator.of(context).pop();
  }

  void _startNew() {
    _session.startNew();
    Navigator.of(context).pop();
  }

  void _settings() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(Routes.settingsCoach);
  }

  /// Hernoemen and Verwijderen, from ⋮ or a long press.
  Future<void> _actions(ChatThreadRow thread) async {
    final picked = await showAppSheet<String>(
      context: context,
      title: thread.title,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Laatst: ${Formatters.relativeDayTime(DateTime.fromMillisecondsSinceEpoch(thread.updatedAt))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Hernoemen'),
            onTap: () => Navigator.of(context).pop('rename'),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Verwijderen',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    final chats = ref.read(databaseProvider).chatDao;

    if (picked == 'rename') {
      final name = await promptForText(
        context,
        title: 'Gesprek hernoemen',
        initialValue: thread.title,
        maxLength: ChatDao.titleLength,
      );
      if (name == null) return;
      await chats.renameThread(thread.id, name);
      if (_found != null) _find(_search.text);
      return;
    }

    final ok = await confirm(
      context,
      title: 'Gesprek verwijderen?',
      message: 'De vragen en antwoorden in "${thread.title}" verdwijnen.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok) return;
    await chats.deleteThread(thread.id);
    if (ref.read(coachSessionControllerProvider).threadId == thread.id) {
      _session.startNew();
    }
    if (_found != null) _find(_search.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threads = ref.watch(chatThreadsProvider).value ?? const [];
    final shown = ref.watch(coachSessionControllerProvider).threadId;
    final running = ref.watch(activeWorkoutProvider).value?.workout.id;
    final width = math.min(320.0, MediaQuery.sizeOf(context).width * 0.85);

    Widget tile(ChatThreadRow thread) => ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.only(left: AppSpacing.sm),
      selected: thread.id == shown,
      selectedTileColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(
        thread.workoutId != null
            ? Icons.fitness_center
            : Icons.chat_bubble_outline,
        size: 18,
      ),
      minLeadingWidth: 20,
      title: Text(
        thread.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      trailing: IconButton(
        tooltip: 'Meer',
        icon: const Icon(Icons.more_vert, size: 18),
        onPressed: () => _actions(thread),
      ),
      onTap: () => _open(thread, running: running),
      onLongPress: () => _actions(thread),
    );

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final now = DateTime.now();
    final ofWorkout = running == null
        ? null
        : threads.where((t) => t.workoutId == running).firstOrNull;
    final grouped = <ThreadGroup, List<ChatThreadRow>>{};
    for (final thread in threads) {
      if (thread.id == ofWorkout?.id) continue;
      final group = ThreadGroup.of(
        DateTime.fromMillisecondsSinceEpoch(thread.updatedAt),
        now,
      );
      grouped.putIfAbsent(group, () => []).add(thread);
    }

    final list = _found == null
        ? <Widget>[
            if (ofWorkout != null) ...[heading('Nu'), tile(ofWorkout)],
            for (final group in ThreadGroup.values)
              if (grouped[group] case final threads?) ...[
                heading(group.label),
                for (final thread in threads) tile(thread),
              ],
            if (threads.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'Nog geen gesprekken. Wat je vraagt, komt hier.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ]
        : [
            FutureBuilder<List<ChatThreadRow>>(
              future: _found,
              builder: (context, found) {
                final rows = found.data;
                if (rows == null) return const SizedBox.shrink();
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      'Niets gevonden.',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                return Column(children: [for (final row in rows) tile(row)]);
              },
            ),
          ];

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) =>
            setState(() => _drag = math.min(0, _drag + details.delta.dx)),
        onHorizontalDragEnd: (details) {
          if (_drag < -width / 3 || (details.primaryVelocity ?? 0) < -500) {
            Navigator.of(context).pop();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(_drag, 0),
          child: Semantics(
            label: 'Gesprekken',
            explicitChildNodes: true,
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: SizedBox(
                width: width,
                height: double.infinity,
                child: SafeArea(
                  right: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _startNew,
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Nieuw gesprek'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _search,
                          onChanged: _find,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Zoek in gesprekken',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Zoeken wissen',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _search.clear();
                                      _find('');
                                    },
                                  ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            children: list,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                          ),
                          leading: const Icon(Icons.tune, size: 20),
                          minLeadingWidth: 20,
                          title: const Text('Instellingen'),
                          onTap: _settings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
