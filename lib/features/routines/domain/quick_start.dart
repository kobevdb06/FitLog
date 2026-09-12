/// The home-screen shortcuts: hold the app icon, start your usual session.
///
/// Which routines get a place is worked out here, away from the platform call,
/// so the rule can be read and tested without a launcher.
library;

import '../../../core/db/database.dart';

/// Android gives an app three shortcuts it can rely on. More are allowed on
/// paper and dropped in practice, so three is what is offered.
const int kQuickStartSlots = 3;

/// Marks a shortcut as "start this routine", and carries which one.
///
/// Prefixed rather than the bare id so a shortcut left behind by an older
/// version, or one that ever means something else, is recognisably not this.
const String kQuickStartPrefix = 'routine:';

String quickStartType(String routineId) => '$kQuickStartPrefix$routineId';

/// The routine a shortcut names, or null if it is not one of ours.
String? routineIdFromQuickStart(String type) {
  if (!type.startsWith(kQuickStartPrefix)) return null;
  final id = type.substring(kQuickStartPrefix.length);
  return id.isEmpty ? null : id;
}

/// What the launcher should show, in order.
///
/// [favourites] comes ranked by use; this only trims it to what fits and
/// gives each entry its label. A routine whose name is long is left as it is:
/// Android shortens it to what the launcher has room for, and guessing where
/// to cut would be worse than letting it.
List<({String type, String title})> quickStartItems(
  List<RoutineRow> favourites, {
  int slots = kQuickStartSlots,
}) => [
  for (final routine in favourites.take(slots))
    (type: quickStartType(routine.id), title: routine.name),
];
