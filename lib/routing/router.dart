import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/app/app_controller.dart';
import '../core/app/app_state.dart';
import '../core/widgets/common.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/exercises/presentation/custom_exercise_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/exercises/presentation/exercise_library_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/history/presentation/workout_detail_screen.dart';
import '../features/lock/presentation/lock_screen.dart';
import '../features/lock/presentation/recovery_unlock_screen.dart';
import '../features/measurements/presentation/measurements_screen.dart';
import '../features/onboarding/presentation/onboarding_flow.dart';
import '../features/photos/presentation/photo_compare_screen.dart';
import '../features/photos/presentation/photos_screen.dart';
import '../features/progress/presentation/exercise_chart_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/progress/presentation/records_screen.dart';
import '../features/routines/presentation/routine_detail_screen.dart';
import '../features/routines/presentation/routine_editor_screen.dart';
import '../features/routines/presentation/routines_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/security_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/workout_preferences_screen.dart';
import '../features/workout/presentation/active_workout_screen.dart';
import '../features/workout/presentation/rest_timer_screen.dart';
import '../features/workout/presentation/workout_summary_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

part 'router.g.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier<AppState>(const AppLoading());
  ref.listen<AppState>(
    appControllerProvider,
    (_, next) => refresh.value = next,
    fireImmediately: true,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.gate,
    refreshListenable: refresh,
    redirect: (context, state) {
      final app = ref.read(appControllerProvider);
      final location = state.matchedLocation;

      switch (app) {
        case AppLoading():
          return location == Routes.gate ? null : Routes.gate;
        case AppFailed():
          return location == Routes.failure ? null : Routes.failure;
        case AppNeedsOnboarding():
          return location.startsWith(Routes.onboarding)
              ? null
              : Routes.onboarding;
        case AppLocked():
          return location.startsWith(Routes.lock) ? null : Routes.lock;
        case AppReady():
          if (location == Routes.gate ||
              location == Routes.failure ||
              location.startsWith(Routes.lock) ||
              location.startsWith(Routes.onboarding)) {
            return Routes.dashboard;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: Routes.gate,
        builder: (context, state) => const AppLoadingScreen(),
      ),
      GoRoute(
        path: Routes.failure,
        builder: (context, state) => const StartupFailureScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingFlow(),
      ),
      GoRoute(
        path: Routes.lock,
        builder: (context, state) => const LockScreen(),
        routes: [
          GoRoute(
            path: 'herstel',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => const RecoveryUnlockScreen(),
          ),
        ],
      ),

      // --- Full screen, outside the tab shell ---------------------------
      GoRoute(
        path: Routes.workout,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ActiveWorkoutScreen(),
        routes: [
          GoRoute(
            path: 'rust',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => const RestTimerScreen(),
          ),
          GoRoute(
            path: ':id/samenvatting',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => WorkoutSummaryScreen(
              workoutId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.exercises,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ExerciseLibraryScreen(),
        routes: [
          GoRoute(
            path: 'nieuw',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => const CustomExerciseScreen(),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            builder: (context, state) =>
                ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
          ),
        ],
      ),

      // --- The four tabs -------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.train,
                builder: (context, state) => const RoutinesScreen(),
                routes: [
                  GoRoute(
                    path: 'routine/nieuw',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => RoutineEditorScreen(
                      folderId: state.uri.queryParameters['map'],
                    ),
                  ),
                  GoRoute(
                    path: 'routine/:id',
                    builder: (context, state) => RoutineDetailScreen(
                      routineId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'bewerken',
                        parentNavigatorKey: _rootKey,
                        builder: (context, state) => RoutineEditorScreen(
                          routineId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.progress,
                builder: (context, state) => const ProgressScreen(),
                routes: [
                  GoRoute(
                    path: 'geschiedenis',
                    builder: (context, state) => const HistoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => WorkoutDetailScreen(
                          workoutId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'grafiek',
                    builder: (context, state) => ExerciseChartScreen(
                      exerciseId: state.uri.queryParameters['oefening'],
                    ),
                  ),
                  GoRoute(
                    path: 'metingen',
                    builder: (context, state) => const MeasurementsScreen(),
                  ),
                  GoRoute(
                    path: 'fotos',
                    builder: (context, state) => const PhotosScreen(),
                    routes: [
                      GoRoute(
                        path: 'vergelijken',
                        builder: (context, state) =>
                            const PhotoCompareScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'records',
                    builder: (context, state) => const RecordsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'instellingen',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'workout',
                        builder: (context, state) =>
                            const WorkoutPreferencesScreen(),
                      ),
                      GoRoute(
                        path: 'beveiliging',
                        builder: (context, state) =>
                            const SecuritySettingsScreen(),
                      ),
                      GoRoute(
                        path: 'backup',
                        builder: (context, state) => const BackupScreen(),
                      ),
                      GoRoute(
                        path: 'over',
                        builder: (context, state) => const AboutScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Shown when the app cannot open the database at all.
class StartupFailureScreen extends ConsumerWidget {
  const StartupFailureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final message = state is AppFailed
        ? state.message
        : 'Er ging iets mis bij het opstarten.';
    final canRetry = state is AppFailed ? state.canRetry : true;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                'FitLog kan niet starten',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (canRetry) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      ref.read(appControllerProvider.notifier).initialise(),
                  child: const Text('Opnieuw proberen'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
