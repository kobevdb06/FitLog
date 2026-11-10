import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Opens the running session from outside the app - the home-screen
/// shortcut, the notification, the panel - with Start underneath it.
///
/// `go` straight to the session replaced everything: there was no page
/// under it, "Verbergen" threw, and "Workout weggooien" stopped on that
/// throw before the session was thrown away (DECISIONS 246).
Future<void> openWorkoutFromOutside(GoRouter router) async {
  // A push builds on what the router shows, and a go lands a few frames
  // later: a push before it landed was overwritten by it. So a go only when
  // Start is not showing yet, and the push once it is. Locked, Start never
  // comes, and the lock screen takes the push anyway.
  if (_at(router) != Routes.dashboard) {
    router.go(Routes.dashboard);
    for (
      var frame = 0;
      frame < 10 && _at(router) != Routes.dashboard;
      frame++
    ) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }
  router.push(Routes.workout);
}

String _at(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;
