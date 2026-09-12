/// What the Start tab offers, and the pieces it is assembled from.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../routines/presentation/routine_providers.dart';
import '../domain/home_layout.dart';
import '../domain/today_plan.dart';

part 'today_providers.g.dart';

/// Which blocks the Start tab shows, and in what order.
@riverpod
HomeLayout homeLayout(Ref ref) =>
    parseHomeLayout(ref.watch(settingsProvider).value?.homeLayout);

/// How many starred routines the card has room for.
const int kHomeFavourites = 3;

/// Every routine that is planned on at least one weekday.
@riverpod
Stream<List<RoutineRow>> scheduledRoutines(Ref ref) =>
    ref.watch(databaseProvider).routinesDao.watchScheduledRoutines();

/// The starred routines, the ones you actually do most often first.
@riverpod
Stream<List<RoutineRow>> favouriteRoutines(Ref ref) => ref
    .watch(databaseProvider)
    .routinesDao
    .watchFavouritesByUse(limit: kHomeFavourites);

/// The three of them read as one answer.
///
/// Each part arrives on its own and the card should not blink through three
/// states while they do, so a part that is still loading counts as empty and
/// the ladder simply falls through to the rung below until it lands.
@riverpod
TodayPlan todayPlan(Ref ref) => buildTodayPlan(
  scheduled: ref.watch(scheduledRoutinesProvider).value ?? const [],
  favourites: ref.watch(favouriteRoutinesProvider).value ?? const [],
  suggested: ref.watch(suggestedRoutineProvider).value,
  now: DateTime.now(),
);
