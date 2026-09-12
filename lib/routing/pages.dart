/// The pages the router hands to the navigator, and how they move.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The page every ordinary route uses.
///
/// Spelled out rather than left to go_router, which works out whether this is
/// a Material or a Cupertino app by looking for one up the widget tree - and
/// caches whatever it decides the first time it is asked. Here that lands on
/// "neither", and the fallback is a page with no transition at all, for the
/// life of the app. Every screen in FitLog therefore appeared and disappeared
/// instantly, which is what made the chevron-down on the session look like it
/// did nothing.
///
/// The fields are the ones go_router fills in itself, so nothing about page
/// identity or state restoration changes; only the guess is gone.
MaterialPage<void> appPage(GoRouterState state, Widget child) {
  return MaterialPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    restorationId: state.pageKey.value,
    child: child,
  );
}

/// A page that rises from the bottom and sinks back down.
///
/// For the screens you close with the chevron in the corner rather than a back
/// arrow: the running session and the rest timer. They behave like something
/// pulled up over the app, so they should move like it - the default zoom is
/// for pages you navigate *into*, and against a chevron it reads as no
/// animation at all.
/// How long such a page takes to come up. Shared, because the shell has to
/// know it: the running-session bar waits this long before showing itself, so
/// it is never seen arriving in the gap the rising page has not covered yet.
const Duration kSheetRise = Duration(milliseconds: 260);

CustomTransitionPage<void> risingPage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: kSheetRise,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: child,
      );
    },
  );
}
