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
import 'pages.dart';
import 'tab_pager.dart';
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
        pageBuilder: (context, state) =>
            appPage(state, const AppLoadingScreen()),
      ),
      GoRoute(
        path: Routes.failure,
        pageBuilder: (context, state) =>
            appPage(state, const StartupFailureScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (context, state) => appPage(state, const OnboardingFlow()),
      ),
      GoRoute(
        path: Routes.lock,
        pageBuilder: (context, state) => appPage(state, const LockScreen()),
        routes: [
          GoRoute(
            path: 'herstel',
            parentNavigatorKey: _rootKey,
            pageBuilder: (context, state) =>
                appPage(state, const RecoveryUnlockScreen()),
          ),
        ],
      ),

      // --- Full screen, outside the tab shell ---------------------------
      GoRoute(
        path: Routes.workout,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            risingPage(const ActiveWorkoutScreen()),
        routes: [
          GoRoute(
            path: 'rust',
            parentNavigatorKey: _rootKey,
            pageBuilder: (context, state) =>
                risingPage(const RestTimerScreen()),
          ),
          GoRoute(
            path: ':id/samenvatting',
            parentNavigatorKey: _rootKey,
            // The session it replaces came up from the bottom; the summary
            // taking its place with Android's zoom instead would be two
            // different motions in one step.
            pageBuilder: (context, state) => risingPage(
              WorkoutSummaryScreen(workoutId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.exercises,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            appPage(state, const ExerciseLibraryScreen()),
        routes: [
          GoRoute(
            path: 'nieuw',
            parentNavigatorKey: _rootKey,
            pageBuilder: (context, state) =>
                appPage(state, const CustomExerciseScreen()),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            pageBuilder: (context, state) => appPage(
              state,
              ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),

      // --- The four tabs -------------------------------------------------
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        // The tabs lie side by side instead of stacked, so a swipe drags the
        // next one into view rather than cutting to it.
        navigatorContainerBuilder: (context, shell, children) =>
            TabPager(shell: shell, branches: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                pageBuilder: (context, state) =>
                    appPage(state, const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.train,
                pageBuilder: (context, state) =>
                    appPage(state, const RoutinesScreen()),
                routes: [
                  GoRoute(
                    path: 'routine/nieuw',
                    parentNavigatorKey: _rootKey,
                    pageBuilder: (context, state) => appPage(
                      state,
                      RoutineEditorScreen(
                        folderId: state.uri.queryParameters['map'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'routine/:id',
                    pageBuilder: (context, state) => appPage(
                      state,
                      RoutineDetailScreen(
                        routineId: state.pathParameters['id']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'bewerken',
                        parentNavigatorKey: _rootKey,
                        pageBuilder: (context, state) => appPage(
                          state,
                          RoutineEditorScreen(
                            routineId: state.pathParameters['id'],
                          ),
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
                pageBuilder: (context, state) =>
                    appPage(state, const ProgressScreen()),
                routes: [
                  GoRoute(
                    path: 'geschiedenis',
                    pageBuilder: (context, state) =>
                        appPage(state, const HistoryScreen()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => appPage(
                          state,
                          WorkoutDetailScreen(
                            workoutId: state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'grafiek',
                    pageBuilder: (context, state) => appPage(
                      state,
                      ExerciseChartScreen(
                        exerciseId: state.uri.queryParameters['oefening'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'metingen',
                    pageBuilder: (context, state) =>
                        appPage(state, const MeasurementsScreen()),
                  ),
                  GoRoute(
                    path: 'fotos',
                    pageBuilder: (context, state) =>
                        appPage(state, const PhotosScreen()),
                    routes: [
                      GoRoute(
                        path: 'vergelijken',
                        pageBuilder: (context, state) =>
                            appPage(state, const PhotoCompareScreen()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'records',
                    pageBuilder: (context, state) =>
                        appPage(state, const RecordsScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                pageBuilder: (context, state) =>
                    appPage(state, const ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'instellingen',
                    pageBuilder: (context, state) =>
                        appPage(state, const SettingsScreen()),
                    routes: [
                      GoRoute(
                        path: 'workout',
                        pageBuilder: (context, state) =>
                            appPage(state, const WorkoutPreferencesScreen()),
                      ),
                      GoRoute(
                        path: 'beveiliging',
                        pageBuilder: (context, state) =>
                            appPage(state, const SecuritySettingsScreen()),
                      ),
                      GoRoute(
                        path: 'backup',
                        pageBuilder: (context, state) =>
                            appPage(state, const BackupScreen()),
                      ),
                      GoRoute(
                        path: 'over',
                        pageBuilder: (context, state) =>
                            appPage(state, const AboutScreen()),
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
