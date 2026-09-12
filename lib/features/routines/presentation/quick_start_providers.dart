/// Keeping the home-screen shortcuts in step with your favourites.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/database.dart';
import '../../../core/app/app_controller.dart';
import '../data/quick_start_service.dart';
import '../domain/quick_start.dart';

part 'quick_start_providers.g.dart';

@Riverpod(keepAlive: true)
QuickStartService quickStartService(Ref ref) => QuickStartService();

/// The starred routines that have a place on the home screen, most used first.
@Riverpod(keepAlive: true)
Stream<List<RoutineRow>> quickStartRoutines(Ref ref) => ref
    .watch(databaseProvider)
    .routinesDao
    .watchFavouritesByUse(limit: kQuickStartSlots);

/// The routine a home-screen shortcut asked for, waiting to be started.
///
/// Set the moment Android hands the tap over, which can be while the app is
/// still on the lock screen. It stays here until something is in a position to
/// act on it, and is cleared as soon as it has been.
@Riverpod(keepAlive: true)
class PendingQuickStart extends _$PendingQuickStart {
  @override
  String? build() => null;

  void request(String routineId) => state = routineId;

  /// Hands the waiting routine over exactly once.
  String? take() {
    final id = state;
    state = null;
    return id;
  }
}
