import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app/app_controller.dart';
import 'core/app/app_state.dart';
import 'core/db/enums.dart';
import 'core/providers/core_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/util/notification_service.dart';
import 'features/routines/domain/quick_start.dart';
import 'features/routines/presentation/quick_start_providers.dart';
import 'features/workout/domain/workout_notice.dart';
import 'features/workout/presentation/workout_providers.dart';
import 'routing/router.dart';
import 'routing/routes.dart';

/// The root widget. Also owns the lifecycle observer that drives auto-lock.
class FitLogApp extends ConsumerStatefulWidget {
  const FitLogApp({super.key});

  @override
  ConsumerState<FitLogApp> createState() => _FitLogAppState();
}

class _FitLogAppState extends ConsumerState<FitLogApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Android may have launched us straight from a home-screen shortcut. The
    // tap arrives before the database is open, sometimes before the lock
    // screen is answered, so it is only noted here and acted on later.
    unawaited(
      ref
          .read(quickStartServiceProvider)
          .listen(
            (routineId) =>
                ref.read(pendingQuickStartProvider.notifier).request(routineId),
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
        controller.onPaused();
      case AppLifecycleState.resumed:
        controller.onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// What the standing notification last said, so an unchanged workout does
  /// not repost it on every rebuild.
  WorkoutNotice? _shown;

  /// Keeps the standing notification in step with the running workout.
  ///
  /// One listener at the root rather than a call at every place a set is
  /// ticked off: the notification then cannot drift out of step with the
  /// session, and it is right again after the app is killed and reopened.
  void _syncWorkoutNotification() {
    final workout = ref.watch(activeWorkoutProvider).value;
    final rest = ref.watch(restTimerProvider);

    final notice = workoutNoticeFor(
      workout,
      restEndsAt: rest.isActive ? rest.endsAt : null,
    );
    if (notice == _shown) return;
    _shown = notice;

    if (notice == null) {
      unawaited(NotificationService.instance.cancelWorkout());
      return;
    }
    unawaited(
      NotificationService.instance.showWorkout(
        title: notice.title,
        body: notice.body,
        startedAt: notice.startedAt,
        restEndsAt: notice.restEndsAt,
      ),
    );
  }

  /// True while a shortcut is being acted on, so a rebuild in the middle does
  /// not start the same routine twice.
  bool _startingFromShortcut = false;

  /// Publishes the home-screen shortcuts whenever the favourites change.
  void _syncQuickStart() {
    final routines = ref.watch(quickStartRoutinesProvider).value;
    if (routines == null) return;
    unawaited(
      ref.read(quickStartServiceProvider).publish(quickStartItems(routines)),
    );
  }

  /// Acts on a shortcut once there is something to act with.
  ///
  /// Waits for the database to be open and the app unlocked; until then the
  /// request simply sits there. A session that is already running is never
  /// thrown away for it - you are taken to that one instead, which is almost
  /// certainly what you meant by tapping a workout shortcut.
  void _handleQuickStart() {
    final pending = ref.watch(pendingQuickStartProvider);
    if (pending == null || _startingFromShortcut) return;
    if (ref.watch(appControllerProvider) is! AppReady) return;

    _startingFromShortcut = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final routineId = ref.read(pendingQuickStartProvider.notifier).take();
        if (routineId == null) return;

        final db = ref.read(databaseProvider);
        // Starred, then deleted, then tapped: nothing to start, and silently
        // doing nothing is better than an error about a shortcut.
        if (await db.routinesDao.getRoutine(routineId) == null) return;

        if (await db.workoutsDao.getActiveWorkoutRow() == null) {
          await ref.read(workoutControllerProvider).startFromRoutine(routineId);
        }
        ref.read(routerProvider).go(Routes.workout);
      } finally {
        _startingFromShortcut = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    _syncWorkoutNotification();
    _syncQuickStart();
    _handleQuickStart();

    // Dark is the default; the setting can override it once the database is
    // open, and before that we simply stay dark.
    final settings = ref.watch(settingsProvider).value;
    final themeMode = switch (settings?.themeMode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'FitLog',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('nl'),
      supportedLocales: const [Locale('nl'), Locale('nl', 'BE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep the app readable when the system font is scaled up a lot.
        final scale = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.4);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}

/// Exposed so the settings screen can label the theme options.
String themeModeLabel(String wire) => switch (wire) {
  'light' => 'Licht',
  'system' => 'Systeem',
  _ => 'Donker',
};

/// Kept next to the theme helper: both are pure label lookups the settings
/// screens use.
String weightUnitLabel(WeightUnit unit) => unit.label;
