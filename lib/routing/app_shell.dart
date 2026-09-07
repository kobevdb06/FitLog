import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatting/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/workout/presentation/workout_providers.dart';
import 'routes.dart';
import 'tab_swipe.dart';

/// The four-tab shell. A running workout gets a permanent bar above the
/// navigation bar so it is never more than one tap away.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// How far sideways the current drag has come, left-to-right.
  double _dragged = 0;

  static const int _tabCount = 4;

  void _onDragEnd(DragEndDetails details, double width) {
    final target = swipeTarget(
      current: widget.shell.currentIndex,
      count: _tabCount,
      velocity: details.primaryVelocity ?? 0,
      dragged: _dragged,
      width: width,
    );
    _dragged = 0;
    if (target == null) return;
    widget.shell.goBranch(target);
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    return Scaffold(
      // Sideways takes you to the next tab. Anything inside that scrolls
      // sideways itself - a chart, a row of chips, a row you swipe away -
      // claims the gesture first, so those keep working as they did.
      body: GestureDetector(
        onHorizontalDragStart: (_) => _dragged = 0,
        onHorizontalDragUpdate: (details) => _dragged += details.delta.dx,
        onHorizontalDragEnd: (details) =>
            _onDragEnd(details, MediaQuery.sizeOf(context).width),
        child: shell,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ActiveWorkoutBar(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(activeWorkoutProvider).value;
    if (workout == null) return const SizedBox.shrink();

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
