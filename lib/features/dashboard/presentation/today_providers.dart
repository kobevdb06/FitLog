/// What the Start tab offers, and the pieces it is assembled from.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/providers/core_providers.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../progress/presentation/recovery_providers.dart';
import '../../routines/presentation/routine_providers.dart';
import '../domain/home_layout.dart';
import '../domain/today_plan.dart';

part 'today_providers.g.dart';

/// Which blocks the Start tab shows, and in what order.
@riverpod
HomeLayout homeLayout(Ref ref) =>
    parseHomeLayout(ref.watch(settingsProvider).value?.homeLayout);

/// Someone asked, from somewhere else in the app, to arrange the Start tab.
///
/// Arranging happens on the Start tab itself now, so Instellingen cannot show
/// it - it can only send you there. The tab is already built and sitting in
/// the pager, so it hears this and switches itself on.
@Riverpod(keepAlive: true)
class HomeArrangeRequest extends _$HomeArrangeRequest {
  @override
  bool build() => false;

  void ask() => state = true;

  void taken() => state = false;
}

/// Whether a block has anything to say right now.
///
/// A block with nothing in it draws nothing, and a slot on the grid for
/// nothing is a hole between two cards. The grid asks this before it makes
/// room and the block asks it before it draws, so the rule stays in one place.
@riverpod
bool homeBlockFilled(Ref ref, HomeBlock block) => switch (block) {
  HomeBlock.favourites =>
    (ref.watch(favouriteRoutinesProvider).value ?? const []).isNotEmpty &&
        // With no schedule, "Vandaag" already falls through to your
        // favourites, and the same three routines twice is not a layout
        // anybody chose.
        !(ref.watch(homeLayoutProvider).shows(HomeBlock.today) &&
            ref.watch(todayPlanProvider).kind == TodayPlanKind.favourites),
  HomeBlock.records =>
    (ref.watch(latestRecordsProvider()).value ?? const []).isNotEmpty,
  HomeBlock.recovery =>
    (ref.watch(recoveryEstimatesProvider).value ?? const []).isNotEmpty,
  // No key, no coach: the block is not a place to advertise one.
  HomeBlock.coach => ref.watch(coachEnabledProvider),
  HomeBlock.today || HomeBlock.week || HomeBlock.volume => true,
};

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
