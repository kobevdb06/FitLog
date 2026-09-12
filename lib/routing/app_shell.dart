import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatting/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/workout/presentation/workout_providers.dart';
import 'router.dart';
import 'routes.dart';
import 'tab_pager.dart';

/// The four-tab shell. A running workout gets a permanent bar above the
/// navigation bar so it is never more than one tap away.
/// How many tabs the bar has, so a half-finished swipe cannot round past the
/// last one.
const int _tabCount = 4;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // The shell is the pager: swiping between the tabs lives in TabPager.
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ActiveWorkoutBar(),
          // The bar follows the pager rather than the router, so dragging a
          // tab into view moves the highlight with you instead of leaving it
          // behind until the page lands. Halfway across is where it goes over,
          // and pull back before that and it never moved. Tapping is unchanged:
          // the position jumps, and the bar plays its own short animation.
          ValueListenableBuilder<double>(
            valueListenable: ref.watch(tabPositionProvider),
            builder: (context, position, _) => NavigationBar(
              selectedIndex: position.round().clamp(0, _tabCount - 1),
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Start',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: 'Trainen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Voortgang',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profiel',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBar extends ConsumerStatefulWidget {
  const _ActiveWorkoutBar();

  @override
  ConsumerState<_ActiveWorkoutBar> createState() => _ActiveWorkoutBarState();
}

class _ActiveWorkoutBarState extends ConsumerState<_ActiveWorkoutBar> {
  Timer? _ticker;

  /// Whether the bar is on screen, which is not the same as whether a session
  /// is running.
  ///
  /// Starting one pushes its own screen up over the shell, and the bar used to
  /// appear underneath at that very moment - you saw it flash into the strip
  /// the rising page had not covered yet. It now waits for that page to be up,
  /// by which time nobody can see it arrive.
  ///
  /// Ending one is the other way round: the bar goes at once, before the page
  /// sinks away, so the strip it uncovers never shows a bar for a session that
  /// is over.
  bool _showing = false;

  /// The last state we reacted to, so a session cancelled during the wait
  /// cancels the arrival with it.
  bool _running = false;

  /// Whether the stream has produced anything yet. The first value it gives is
  /// simply what was already true - a session you opened the app on - and
  /// there is no arrival to wait for.
  bool _known = false;

  Timer? _reveal;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _reveal?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeWorkoutProvider);
    final workout = async.value;

    // Opening the app on a session already in progress shows the bar straight
    // away: there is no arrival to hide behind.
    if (!_known && async.hasValue) {
      _known = true;
      _running = workout != null;
      _showing = workout != null;
    }

    ref.listen(activeWorkoutProvider, (previous, next) {
      if (!next.hasValue) return;
      final running = next.value != null;
      if (_known && running == _running) return;

      _reveal?.cancel();
      _reveal = null;
      final wasKnown = _known;
      _known = true;
      _running = running;

      // Only a session that starts while you are watching has a screen rising
      // over the shell to hide the arrival behind.
      if (!running || !wasKnown) {
        setState(() => _showing = running);
        return;
      }
      _reveal = Timer(kSheetRise, () {
        if (mounted) setState(() => _showing = true);
      });
    });

    if (workout == null || !_showing) return const SizedBox.shrink();

    final elapsed = DateTime.now()
        .difference(
          DateTime.fromMillisecondsSinceEpoch(workout.workout.startedAt),
        )
        .inSeconds;

    return Material(
      color: AppColors.accent,
      child: InkWell(
        onTap: () => context.push(Routes.workout),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    workout.workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  Formatters.duration(elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
