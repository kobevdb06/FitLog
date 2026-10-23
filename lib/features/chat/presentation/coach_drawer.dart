/// The conversations with the coach, in a panel from the left - the way
/// ChatGPT and Claude keep theirs.
///
/// It comes over the whole screen, the tab bar too, and is opened with the
/// button only: swiping in from the edge would fight the swipe between the
/// tabs. Swiping it back, or tapping beside it, closes it.
///
/// Two lists, switched at the top the way Claude switches between Chat and
/// Code: the conversations, and the schema's - each with the conversation it
/// was made in.
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
import '../../plans/data/plan_actions.dart';
import '../../plans/presentation/plan_providers.dart';
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

/// Which list the panel shows.
enum _Shelf { chats, plans }

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

  /// Opened on the schema's when a schema's conversation is on screen.
  late _Shelf _shelf = _onPlan ? _Shelf.plans : _Shelf.chats;

  bool get _onPlan {
    final shown = ref.read(coachSessionControllerProvider).threadId;
    final threads = ref.read(planThreadsProvider).value ?? const [];
    return shown != null && threads.any((t) => t.id == shown);
  }

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

  void _go(String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }

  /// Stoppen, for the one being followed, and Verwijderen - the schema with
  /// its conversation. What was done in its sessions stays in the history.
  Future<void> _planActions(TrainingPlanRow plan, ChatThreadRow? thread) async {
    final theme = Theme.of(context);
    final running = plan.state == PlanStatus.running;
    final picked = await showAppSheet<String>(
      context: context,
      title: plan.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running)
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('Stoppen'),
              onTap: () => Navigator.of(context).pop('stop'),
            ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Verwijderen',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    final db = ref.read(databaseProvider);

    if (picked == 'stop') {
      final ok = await confirm(
        context,
        title: 'Schema stoppen?',
        message:
            '"${plan.name}" komt bij je eerdere schema\'s, met wat je erin '
            'deed. Opnieuw starten kan niet.',
        confirmLabel: 'Stoppen',
      );
      if (ok) await PlanActions.stop(db, plan.id);
      return;
    }

    final ok = await confirm(
      context,
      title: 'Schema verwijderen?',
      message:
          '"${plan.name}", zijn sessies en het gesprek erover verdwijnen. '
          'Wat je al trainde, blijft in je geschiedenis.',
      confirmLabel: 'Verwijderen',
      destructive: true,
    );
    if (!ok) return;
    await PlanActions.delete(db, plan.id);
    if (thread != null) {
      await db.chatDao.deleteThread(thread.id);
      if (ref.read(coachSessionControllerProvider).threadId == thread.id) {
        _session.startNew();
      }
    }
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
    final threads = [
      for (final thread in ref.watch(chatThreadsProvider).value ?? const [])
        if (thread.planId == null) thread,
    ];
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

    final plans = ref.watch(plansProvider).value ?? const [];
    final planThreads = ref.watch(planThreadsProvider).value ?? const [];

    Widget planTile(TrainingPlanRow plan) {
      final thread = planThreads.where((t) => t.planId == plan.id).firstOrNull;
      final week = plan.weekAt(now);
      final where = switch (plan.state) {
        PlanStatus.draft => 'In voorbereiding',
        PlanStatus.running when plan.isOverAt(now) => 'Alle weken voorbij',
        PlanStatus.running when week == 0 => 'Begint maandag',
        PlanStatus.running =>
          'Week $week${plan.weeks == null ? '' : ' van ${plan.weeks}'}',
        PlanStatus.done => switch (plan.endedAt) {
          final at? =>
            'Afgerond ${Formatters.dayMonth(DateTime.fromMillisecondsSinceEpoch(at))}',
          null => 'Afgerond',
        },
      };
      return ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.only(left: AppSpacing.sm),
        selected: thread != null && thread.id == shown,
        selectedTileColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          plan.state == PlanStatus.running
              ? Icons.event_available
              : Icons.calendar_month_outlined,
          size: 18,
        ),
        minLeadingWidth: 20,
        title: Text(
          plan.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          switch (ref.watch(planOpenChangesProvider(plan.id)).value ?? 0) {
            0 => where,
            1 => '$where · 1 voorstel wacht',
            final n => '$where · $n voorstellen wachten',
          },
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          tooltip: 'Meer',
          icon: const Icon(Icons.more_vert, size: 18),
          onPressed: () => _planActions(plan, thread),
        ),
        onTap: thread == null ? null : () => _open(thread, running: running),
        onLongPress: () => _planActions(plan, thread),
      );
    }

    final planList = <Widget>[
      for (final (label, state) in const [
        ('Lopend', PlanStatus.running),
        ('In voorbereiding', PlanStatus.draft),
        ('Afgerond', PlanStatus.done),
      ])
        if (plans.where((p) => p.state == state).toList() case final some
            when some.isNotEmpty) ...[
          heading(label),
          for (final plan in some) planTile(plan),
        ],
      if (plans.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            'Nog geen schema\'s. Met Nieuw schema maakt de coach er een, op '
            'jouw doel.',
            style: theme.textTheme.bodySmall,
          ),
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
                        SegmentedButton<_Shelf>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _Shelf.chats,
                              icon: Icon(Icons.chat_bubble_outline, size: 18),
                              label: Text('Chats'),
                            ),
                            ButtonSegment(
                              value: _Shelf.plans,
                              icon: Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              label: Text("Schema's"),
                            ),
                          ],
                          selected: {_shelf},
                          onSelectionChanged: (picked) =>
                              setState(() => _shelf = picked.first),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_shelf == _Shelf.plans) ...[
                          OutlinedButton.icon(
                            onPressed: () => _go(Routes.planNew),
                            icon: const Icon(Icons.add),
                            label: const Text('Nieuw schema'),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              children: planList,
                            ),
                          ),
                        ] else ...[
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
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              children: list,
                            ),
                          ),
                        ],
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                          ),
                          leading: const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 20,
                          ),
                          minLeadingWidth: 20,
                          title: const Text('Wat de coach onthoudt'),
                          trailing: Text(
                            '${ref.watch(coachNotesProvider).value?.length ?? 0}',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => _go(Routes.coachMemory),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                          ),
                          leading: const Icon(Icons.tune, size: 20),
                          minLeadingWidth: 20,
                          title: const Text('Instellingen'),
                          onTap: () => _go(Routes.settingsCoach),
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
